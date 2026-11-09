const double kOunceGrams = 31.1034768;

double _d(Object? v, [double def = 0]) => v is num ? v.toDouble() : def;
int _i(Object? v, [int def = 0]) => v is num ? v.toInt() : def;

class Deal {
  final String id;
  final String type; // buy | sell
  final int karat; // 24 | 21
  final double low;
  final double high;
  final int createdAt;
  String status; // active | done
  double? hitPrice;
  int? hitAt;

  Deal({
    required this.id,
    required this.type,
    required this.karat,
    required this.low,
    required this.high,
    required this.createdAt,
    this.status = 'active',
    this.hitPrice,
    this.hitAt,
  });

  bool get isBuy => type == 'buy';
  bool get active => status == 'active';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'karat': karat,
        'low': low,
        'high': high,
        'createdAt': createdAt,
        'status': status,
        'hitPrice': hitPrice,
        'hitAt': hitAt,
      };

  factory Deal.fromJson(Map<String, dynamic> j) => Deal(
        id: '${j['id']}',
        type: j['type'] == 'sell' ? 'sell' : 'buy',
        karat: _i(j['karat'], 24),
        low: _d(j['low']),
        high: _d(j['high']),
        createdAt: _i(j['createdAt']),
        status: j['status'] == 'done' ? 'done' : 'active',
        hitPrice: j['hitPrice'] is num ? (j['hitPrice'] as num).toDouble() : null,
        hitAt: j['hitAt'] is num ? (j['hitAt'] as num).toInt() : null,
      );
}

class AlertEvent {
  final String dealId;
  final String type;
  final int karat;
  final double low;
  final double high;
  final double price;
  final int time;
  final bool test;

  AlertEvent({
    required this.dealId,
    required this.type,
    required this.karat,
    required this.low,
    required this.high,
    required this.price,
    required this.time,
    this.test = false,
  });

  Map<String, dynamic> toJson() => {
        'dealId': dealId,
        'type': type,
        'karat': karat,
        'low': low,
        'high': high,
        'price': price,
        'time': time,
        'test': test,
      };

  factory AlertEvent.fromJson(Map<String, dynamic> j) => AlertEvent(
        dealId: '${j['dealId']}',
        type: j['type'] == 'sell' ? 'sell' : 'buy',
        karat: _i(j['karat'], 24),
        low: _d(j['low']),
        high: _d(j['high']),
        price: _d(j['price']),
        time: _i(j['time']),
        test: j['test'] == true,
      );
}

class AppSettings {
  String email;
  String lang;
  bool pinEnabled;
  String pin;
  double margin;
  double premium;
  String mailUrl;
  bool push;
  bool sound;

  AppSettings({
    this.email = '',
    this.lang = 'ar',
    this.pinEnabled = false,
    this.pin = '',
    this.margin = 15,
    this.premium = 1.0,
    this.mailUrl = '',
    this.push = true,
    this.sound = true,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'lang': lang,
        'pinEnabled': pinEnabled,
        'pin': pin,
        'margin': margin,
        'premium': premium,
        'mailUrl': mailUrl,
        'push': push,
        'sound': sound,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        email: '${j['email'] ?? ''}',
        lang: j['lang'] == 'en' ? 'en' : 'ar',
        pinEnabled: j['pinEnabled'] == true,
        pin: '${j['pin'] ?? ''}',
        margin: _d(j['margin'], 15),
        premium: _d(j['premium'], 1.0).clamp(1.0, 5.0).toDouble(),
        mailUrl: '${j['mailUrl'] ?? ''}',
        push: j['push'] != false,
        sound: j['sound'] != false,
      );
}

class Quote {
  final double xau;
  final double prevClose;
  final double dayHigh;
  final double dayLow;
  final double usdEgp; // bank dollar
  double premium; // goldsmith dollar premium (added to bank dollar)
  final DateTime updated;

  Quote({
    required this.xau,
    required this.prevClose,
    required this.dayHigh,
    required this.dayLow,
    required this.usdEgp,
    required this.updated,
    this.premium = 0,
  });

  /// Egyptian goldsmith dollar = bank dollar + premium
  double get goldEgp => usdEgp + premium;

  double get change => prevClose > 0 ? xau - prevClose : 0;
  double get changePct => prevClose > 0 ? change / prevClose * 100 : 0;
  double get base24 => xau * goldEgp / kOunceGrams;

  /// karat 0 = global ounce (XAU/USD)
  double sell(int karat) => karat == 0 ? xau : base24 * karat / 24;
  double buy(int karat, double margin) => karat == 0 ? xau : sell(karat) - margin;
}

class ChartPoint {
  final DateTime t;
  final double v;
  ChartPoint(this.t, this.v);
}

String karatLabel(int k) => k == 0 ? 'XAU' : '${k}K';
String unitOf(int k) => k == 0 ? 'USD' : 'EGP';

String f2(double v) => v.toStringAsFixed(2);
String f3(double v) => v.toStringAsFixed(3);
String two(int v) => v.toString().padLeft(2, '0');
String fmtDateTime(DateTime d) =>
    '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
String fmtShort(DateTime d) => '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
