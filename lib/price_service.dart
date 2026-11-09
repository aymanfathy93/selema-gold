import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class YahooChart {
  final double price;
  final double prevClose;
  final double dayHigh;
  final double dayLow;
  final List<ChartPoint> points;

  YahooChart(this.price, this.prevClose, this.dayHigh, this.dayLow, this.points);

  static double _n(Object? v) => v is num ? v.toDouble() : 0;

  static YahooChart? parse(Map<String, dynamic> r) {
    final meta = (r['meta'] as Map?) ?? {};
    final ts = (r['timestamp'] as List?) ?? const [];
    final ind = (r['indicators'] as Map?) ?? {};
    final quotes = (ind['quote'] as List?) ?? const [];
    final closes = quotes.isNotEmpty ? ((quotes.first as Map)['close'] as List?) ?? const [] : const [];
    final pts = <ChartPoint>[];
    for (var i = 0; i < ts.length && i < closes.length; i++) {
      final c = closes[i];
      final t = ts[i];
      if (c is num && t is num && c > 0) {
        pts.add(ChartPoint(DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000), c.toDouble()));
      }
    }
    var price = _n(meta['regularMarketPrice']);
    if (price <= 0 && pts.isNotEmpty) price = pts.last.v;
    if (price <= 0) return null;
    var prev = _n(meta['chartPreviousClose']);
    if (prev <= 0) prev = _n(meta['previousClose']);
    var hi = _n(meta['regularMarketDayHigh']);
    var lo = _n(meta['regularMarketDayLow']);
    if (hi <= 0 && pts.isNotEmpty) hi = pts.map((e) => e.v).reduce((a, b) => a > b ? a : b);
    if (lo <= 0 && pts.isNotEmpty) lo = pts.map((e) => e.v).reduce((a, b) => a < b ? a : b);
    return YahooChart(price, prev, hi, lo, pts);
  }
}

class PriceService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
    'Accept': 'application/json',
  };

  static final http.Client _client = http.Client();

  static Future<Map<String, dynamic>?> _get(String url, {int timeoutSec = 12}) async {
    try {
      final r = await _client.get(Uri.parse(url), headers: _headers).timeout(Duration(seconds: timeoutSec));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is Map<String, dynamic>) return j;
      }
    } catch (_) {}
    return null;
  }

  /// Spot XAU/USD (gold-api.com, free, no key)
  static Future<double?> spot() async {
    final j = await _get('https://api.gold-api.com/price/XAU', timeoutSec: 5);
    final p = j?['price'];
    return p is num && p > 0 ? p.toDouble() : null;
  }

  static Future<YahooChart?> yahoo(String symbol, String query) async {
    for (final host in const ['query1', 'query2']) {
      final j = await _get('https://$host.finance.yahoo.com/v8/finance/chart/$symbol?$query');
      final chart = j?['chart'];
      if (chart is Map) {
        final res = chart['result'];
        if (res is List && res.isNotEmpty && res.first is Map<String, dynamic>) {
          final y = YahooChart.parse(res.first as Map<String, dynamic>);
          if (y != null) return y;
        }
      }
    }
    return null;
  }

  static Future<double?> usdEgp() async {
    final y = await yahoo('EGP%3DX', 'interval=1d&range=1d');
    if (y != null && y.price > 10) return y.price;
    final j = await _get('https://open.er-api.com/v6/latest/USD');
    final rates = j?['rates'];
    if (rates is Map) {
      final v = rates['EGP'];
      if (v is num && v > 10) return v.toDouble();
    }
    return null;
  }

  /// Gold futures (GC=F) day data, used for day high/low, previous close and charts.
  static Future<YahooChart?> goldDay() => yahoo('GC%3DF', 'interval=5m&range=1d');

  static Future<YahooChart?> goldHistory(int days) {
    if (days <= 1) return goldDay();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final from = now - days * 86400;
    final interval = days <= 7 ? '30m' : '1h';
    return yahoo('GC%3DF', 'period1=$from&period2=$now&interval=$interval');
  }
}
