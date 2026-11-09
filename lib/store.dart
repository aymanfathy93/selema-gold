import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';
import 'models.dart';
import 'native.dart';
import 'price_service.dart';

class AppState extends ChangeNotifier {
  SharedPreferences? _p;
  AppSettings settings = AppSettings();
  List<Deal> deals = [];
  List<AlertEvent> events = [];

  Quote? quote;
  bool loading = true;
  bool failed = false;
  bool ringing = false;
  bool serviceRunning = false;
  bool unlocked = false;

  double _offset = 0; // spot - futures
  double? _egp;
  DateTime? _egpAt;
  double? _prevClose;
  double? _sessHigh;
  double? _sessLow;

  Timer? _priceTimer;
  Timer? _fastTimer;
  int tickDir = 0; // 1 up, -1 down (last ounce move)
  bool _fastBusy = false;
  Timer? _eventTimer;
  bool _refreshing = false;

  final StreamController<AlertEvent> _incoming = StreamController<AlertEvent>.broadcast();
  Stream<AlertEvent> get incoming => _incoming.stream;

  double get offset => _offset;
  int get activeCount => deals.where((d) => d.active).length;
  List<Deal> get activeDeals => deals.where((d) => d.active).toList();
  List<Deal> get doneDeals => deals.where((d) => !d.active).toList()
    ..sort((a, b) => (b.hitAt ?? b.createdAt).compareTo(a.hitAt ?? a.createdAt));

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    try {
      final s = _p!.getString('settings');
      if (s != null) settings = AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {}
    try {
      final d = _p!.getString('deals');
      if (d != null) {
        deals = (jsonDecode(d) as List).map((e) => Deal.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    try {
      final e = _p!.getString('events');
      if (e != null) {
        events = (jsonDecode(e) as List).map((x) => AlertEvent.fromJson(x as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    _egp = _p!.getDouble('egp');
    T.lang = settings.lang;
    unlocked = !settings.pinEnabled;
    notifyListeners();

    unawaited(Native.requestNotifications());
    await _pullEvents();
    await _syncNative();
    unawaited(refresh());
    _startTimers();
    _eventTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pullEvents());
  }

  void _startTimers() {
    _priceTimer?.cancel();
    _fastTimer?.cancel();
    // full refresh (day high/low, change, dollar) every minute
    _priceTimer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    // live ounce price every second
    _fastTimer = Timer.periodic(const Duration(seconds: 1), (_) => _fastTick());
  }

  void onPause() {
    _priceTimer?.cancel();
    _fastTimer?.cancel();
    _priceTimer = null;
    _fastTimer = null;
  }

  void onResume() {
    refresh();
    _pullEvents();
    _startTimers();
  }

  Future<void> _fastTick() async {
    final q = quote;
    if (_fastBusy || _refreshing || q == null) return;
    _fastBusy = true;
    try {
      final spot = await PriceService.spot();
      if (spot == null || _refreshing) return;
      if (spot > q.xau) tickDir = 1;
      if (spot < q.xau) tickDir = -1;
      final hi = _sessHigh == null || spot > _sessHigh! ? spot : _sessHigh!;
      final lo = _sessLow == null || spot < _sessLow! ? spot : _sessLow!;
      _sessHigh = hi;
      _sessLow = lo;
      quote = Quote(
        xau: spot,
        prevClose: q.prevClose,
        dayHigh: hi,
        dayLow: lo,
        usdEgp: q.usdEgp,
        updated: DateTime.now(),
        premium: settings.premium,
      );
      notifyListeners();
    } catch (_) {
    } finally {
      _fastBusy = false;
    }
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (_egp == null || _egpAt == null || DateTime.now().difference(_egpAt!).inMinutes >= 10) {
        final e = await PriceService.usdEgp();
        if (e != null) {
          _egp = e;
          _egpAt = DateTime.now();
          await _p?.setDouble('egp', e);
        }
      }
      final spotF = PriceService.spot();
      final dayF = PriceService.goldDay();
      final spot = await spotF;
      final day = await dayF;

      double? xau;
      if (spot != null && day != null) {
        _offset = spot - day.price;
        xau = spot;
      } else if (day != null) {
        xau = day.price + _offset;
      } else if (spot != null) {
        xau = spot;
      }

      if (xau != null && _egp != null) {
        if (day != null) {
          if (day.prevClose > 0) _prevClose = day.prevClose + _offset;
          _sessHigh = day.dayHigh > 0 ? day.dayHigh + _offset : xau;
          _sessLow = day.dayLow > 0 ? day.dayLow + _offset : xau;
        }
        final hi = _sessHigh == null || xau > _sessHigh! ? xau : _sessHigh!;
        final lo = _sessLow == null || xau < _sessLow! ? xau : _sessLow!;
        _sessHigh = hi;
        _sessLow = lo;
        quote = Quote(
          xau: xau,
          prevClose: _prevClose ?? 0,
          dayHigh: hi,
          dayLow: lo,
          usdEgp: _egp!,
          updated: DateTime.now(),
          premium: settings.premium,
        );
        failed = false;
      } else {
        failed = quote == null;
      }
    } catch (_) {
      failed = quote == null;
    } finally {
      loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  double? watchedPrice(Deal d) {
    final q = quote;
    if (q == null) return null;
    return d.isBuy ? q.buy(d.karat, settings.margin) : q.sell(d.karat);
  }

  Future<void> _pullEvents() async {
    final raw = await Native.takeEvents();
    var changed = false;
    if (raw != null && raw.isNotEmpty && raw != '[]') {
      try {
        final list = (jsonDecode(raw) as List).map((e) => AlertEvent.fromJson(e as Map<String, dynamic>)).toList();
        for (final ev in list) {
          if (!ev.test) {
            for (final d in deals) {
              if (d.id == ev.dealId && d.active) {
                d.status = 'done';
                d.hitPrice = ev.price;
                d.hitAt = ev.time;
              }
            }
          }
          events.insert(0, ev);
          _incoming.add(ev);
          changed = true;
        }
        if (events.length > 200) events = events.sublist(0, 200);
      } catch (_) {}
    }
    final r = await Native.isRinging();
    final run = await Native.isRunning();
    if (r != ringing || run != serviceRunning) {
      ringing = r;
      serviceRunning = run;
      changed = true;
    }
    if (changed) {
      await _saveDeals();
      await _saveEvents();
      notifyListeners();
    }
  }

  Future<void> _saveDeals() async {
    await _p?.setString('deals', jsonEncode(deals.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveEvents() async {
    await _p?.setString('events', jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveSettings() async {
    await _p?.setString('settings', jsonEncode(settings.toJson()));
  }

  Future<void> _syncNative() async {
    final s = Map<String, dynamic>.from(settings.toJson())
      ..remove('pin')
      ..['usdEgp'] = _egp ?? 0
      ..['title'] = T.t('alert_hit')
      ..['bodyHint'] = T.t('open_trading')
      ..['watchText'] = T.ar ? 'جاري متابعة سعر الذهب' : 'Watching gold price';
    await Native.sync(jsonEncode(deals.map((e) => e.toJson()).toList()), jsonEncode(s));
    serviceRunning = await Native.isRunning();
  }

  Future<void> addDeal(String type, int karat, double low, double high) async {
    if (low > high) {
      final t = low;
      low = high;
      high = t;
    }
    deals.add(Deal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      karat: karat,
      low: low,
      high: high,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _saveDeals();
    await _syncNative();
    notifyListeners();
  }

  Future<void> deleteDeal(String id) async {
    deals.removeWhere((d) => d.id == id);
    await _saveDeals();
    await _syncNative();
    notifyListeners();
  }

  Future<void> clearDone() async {
    deals.removeWhere((d) => !d.active);
    await _saveDeals();
    await _syncNative();
    notifyListeners();
  }

  Future<void> clearEvents() async {
    events.clear();
    await _saveEvents();
    notifyListeners();
  }

  Future<void> stopAlarm() async {
    await Native.stopAlarm();
    ringing = false;
    notifyListeners();
  }

  Future<void> testAlert() async {
    await Native.testAlert(T.t('alert_hit'), T.t('open_trading'), settings.sound, settings.push);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _pullEvents();
  }

  /// live update while dragging the slider (saved on release)
  void setPremiumLive(double v) {
    settings.premium = v;
    quote?.premium = v;
    notifyListeners();
  }

  Future<bool> testEmail() async {
    return Native.testEmail(settings.mailUrl, settings.email);
  }

  Future<void> updateSettings(void Function(AppSettings s) f) async {
    f(settings);
    quote?.premium = settings.premium;
    T.lang = settings.lang;
    await _saveSettings();
    await _syncNative();
    notifyListeners();
  }

  bool checkPin(String pin) {
    if (pin == settings.pin) {
      unlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _fastTimer?.cancel();
    _eventTimer?.cancel();
    _incoming.close();
    super.dispose();
  }
}

final AppState app = AppState();
