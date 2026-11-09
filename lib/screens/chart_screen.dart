import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../price_service.dart';
import '../store.dart';
import '../ui.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});
  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  int _mode = 0; // 0 ounce, 1 gram24
  int _period = 0; // 0 1d, 1 7d, 2 30d
  final Map<int, List<ChartPoint>> _cache = {};
  final Map<int, DateTime> _cacheAt = {};
  bool _loading = false;
  bool _error = false;
  int? _touch;

  static const _days = [1, 7, 30];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final at = _cacheAt[_period];
    if (!force && at != null && DateTime.now().difference(at).inMinutes < 3) {
      setState(() {});
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    final p = _period;
    final y = await PriceService.goldHistory(_days[p]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (y == null || y.points.length < 2) {
        _error = _cache[p] == null;
      } else {
        _cache[p] = y.points;
        _cacheAt[p] = DateTime.now();
      }
    });
  }

  List<ChartPoint> _series() {
    final raw = _cache[_period] ?? const <ChartPoint>[];
    final off = app.offset;
    final egp = app.quote?.usdEgp ?? 0;
    return raw.map((e) {
      final usd = e.v + off;
      return ChartPoint(e.t, _mode == 0 ? usd : usd * egp / kOunceGrams);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final pts = _series();
    final unit = _mode == 0 ? 'USD' : 'EGP';
    double? first, last, hi, lo;
    if (pts.isNotEmpty) {
      first = pts.first.v;
      last = pts.last.v;
      hi = pts.map((e) => e.v).reduce(math.max);
      lo = pts.map((e) => e.v).reduce(math.min);
    }
    final shown = _touch != null && _touch! < pts.length ? pts[_touch!] : (pts.isNotEmpty ? pts.last : null);
    final ch = (last != null && first != null) ? last - first : 0.0;
    final chPct = (first != null && first > 0) ? ch / first * 100 : 0.0;
    final col = ch >= 0 ? C.green : C.red;

    return RefreshIndicator(
      color: C.gold,
      backgroundColor: C.card,
      onRefresh: () => _load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 24 * s),
        children: [
          Text(T.t('chart_title'), style: ts(context, 20, color: C.goldText, w: FontWeight.w700)),
          SizedBox(height: 14 * s),
          Segmented(
            labels: [T.t('ounce_usd'), T.t('gram24_egp')],
            index: _mode,
            onChanged: (i) => setState(() {
              _mode = i;
              _touch = null;
            }),
          ),
          SizedBox(height: 10 * s),
          Segmented(
            labels: [T.t('d1'), T.t('d7'), T.t('d30')],
            index: _period,
            onChanged: (i) {
              _period = i;
              _touch = null;
              _load();
            },
          ),
          SizedBox(height: 14 * s),
          GoldCard(
            borderColor: C.goldBright,
            padding: EdgeInsets.fromLTRB(16 * s, 16 * s, 16 * s, 12 * s),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (shown != null)
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: T.ar ? Alignment.centerRight : Alignment.centerLeft,
                      child: Ltr(Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('$unit ', style: ts(context, 14, color: C.muted)),
                        Text(f2(shown.v), style: ts(context, 26, w: FontWeight.w700)),
                      ])),
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (_touch == null)
                      Ltr(Text('${ch >= 0 ? '+' : '-'}${f2(ch.abs())}  (${f2(chPct.abs())}%)',
                          style: ts(context, 14, color: col, w: FontWeight.w700))),
                    Ltr(Text(fmtShort(shown.t), style: ts(context, 12, color: C.muted))),
                  ]),
                ]),
              SizedBox(height: 10 * s),
              SizedBox(
                height: 240 * s,
                child: _loading && pts.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: C.gold))
                    : (_error || pts.length < 2)
                        ? Center(child: Text(T.t('chart_err'), style: ts(context, 14, color: C.muted)))
                        : Ltr(LayoutBuilder(builder: (ctx, cons) {
                            void hit(Offset o) {
                              final w = cons.maxWidth - _ChartPainter.leftPad;
                              final x = (o.dx - _ChartPainter.leftPad).clamp(0, w).toDouble();
                              final i = (x / w * (pts.length - 1)).round();
                              if (i != _touch) setState(() => _touch = i);
                            }

                            return GestureDetector(
                              onPanDown: (d) => hit(d.localPosition),
                              onPanUpdate: (d) => hit(d.localPosition),
                              onPanEnd: (_) => setState(() => _touch = null),
                              onPanCancel: () => setState(() => _touch = null),
                              child: CustomPaint(
                                size: Size(cons.maxWidth, cons.maxHeight),
                                painter: _ChartPainter(pts, _touch, col, sc(context)),
                              ),
                            );
                          })),
              ),
            ]),
          ),
          if (pts.isNotEmpty) ...[
            SizedBox(height: 14 * s),
            Row(children: [
              Expanded(child: _Mini(label: T.t('open'), value: first!, color: C.text)),
              SizedBox(width: 10 * s),
              Expanded(child: _Mini(label: T.t('high'), value: hi!, color: C.green)),
              SizedBox(width: 10 * s),
              Expanded(child: _Mini(label: T.t('low'), value: lo!, color: C.red)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Mini({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 8 * s),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(children: [
        Text(label, style: ts(context, 13, color: C.muted)),
        FittedBox(child: Ltr(Text(f2(value), style: ts(context, 16, color: color, w: FontWeight.w700)))),
      ]),
    );
  }
}

class _ChartPainter extends CustomPainter {
  static const double leftPad = 52;
  final List<ChartPoint> pts;
  final int? touch;
  final Color color;
  final double scale;
  _ChartPainter(this.pts, this.touch, this.color, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    var mn = pts.map((e) => e.v).reduce(math.min);
    var mx = pts.map((e) => e.v).reduce(math.max);
    if (mx - mn < 1e-6) {
      mx += 1;
      mn -= 1;
    }
    final pad = (mx - mn) * 0.08;
    mn -= pad;
    mx += pad;
    const top = 6.0;
    final bottom = size.height - 22;
    final w = size.width - leftPad;
    double xOf(int i) => leftPad + i / (pts.length - 1) * w;
    double yOf(double v) => top + (mx - v) / (mx - mn) * (bottom - top);

    final grid = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(fontFamily: 'Cairo', fontSize: 10 * scale, color: const Color(0xFF8A8F98));
    for (var g = 0; g <= 4; g++) {
      final v = mn + (mx - mn) * g / 4;
      final y = yOf(v);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid);
      final tp = TextPainter(
        text: TextSpan(text: v >= 1000 ? v.toStringAsFixed(0) : v.toStringAsFixed(1), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    // time labels
    for (final i in [0, (pts.length - 1) ~/ 2, pts.length - 1]) {
      final t = pts[i].t;
      final tp = TextPainter(
        text: TextSpan(text: fmtShort(t), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      var x = xOf(i) - tp.width / 2;
      x = x.clamp(leftPad, size.width - tp.width).toDouble();
      tp.paint(canvas, Offset(x, size.height - tp.height));
    }

    final line = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = Offset(xOf(i), yOf(pts[i].v));
      if (i == 0) {
        line.moveTo(o.dx, o.dy);
      } else {
        line.lineTo(o.dx, o.dy);
      }
    }
    final fill = Path.from(line)
      ..lineTo(xOf(pts.length - 1), bottom)
      ..lineTo(xOf(0), bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFD9B84A).withOpacity(0.35), const Color(0xFFD9B84A).withOpacity(0.0)],
        ).createShader(Rect.fromLTRB(0, top, size.width, bottom)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFFE2C35A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    final ti = touch;
    if (ti != null && ti >= 0 && ti < pts.length) {
      final x = xOf(ti);
      final y = yOf(pts[ti].v);
      canvas.drawLine(Offset(x, top), Offset(x, bottom), Paint()..color = const Color(0x88FFFFFF));
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = const Color(0xFFE2C35A));
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = const Color(0xFF111111));
    } else {
      final x = xOf(pts.length - 1);
      final y = yOf(pts.last.v);
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.pts != pts || old.touch != touch || old.color != color;
}
