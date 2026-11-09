import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF111111);
  static const panel = Color(0xFF171717);
  static const card = Color(0xFF1C1C1C);
  static const inner = Color(0xFF141414);
  static const field = Color(0xFF0B0B0B);
  static const border = Color(0xFF5A503D);
  static const borderSoft = Color(0xFF2B2B2B);
  static const divider = Color(0xFF263040);
  static const gold = Color(0xFFC9AE84);
  static const goldText = Color(0xFFE3C48A);
  static const goldBright = Color(0xFFD9B84A);
  static const yellow = Color(0xFFF2CC4D);
  static const green = Color(0xFF4CC36B);
  static const red = Color(0xFFE5534B);
  static const text = Colors.white;
  static const muted = Color(0xFF9CA3AF);
  static const chip = Color(0xFF232A33);
}

/// Responsive scale factor based on screen width.
double sc(BuildContext c) => (MediaQuery.sizeOf(c).width / 400).clamp(0.85, 1.35).toDouble();

TextStyle ts(BuildContext c, double size,
        {Color color = C.text, FontWeight w = FontWeight.w400, double? height}) =>
    TextStyle(fontFamily: 'Cairo', fontSize: size * sc(c), color: color, fontWeight: w, height: height);

class GoldCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color borderColor;
  final double width;
  const GoldCard({super.key, required this.child, this.padding, this.borderColor = C.border, this.width = 1.2});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(18 * sc(context)),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: width),
      ),
      child: child,
    );
  }
}

/// Keeps numbers left-to-right inside RTL layouts.
class Ltr extends StatelessWidget {
  final Widget child;
  const Ltr(this.child, {super.key});
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.ltr, child: child);
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? leading;
  final Color color;
  const SectionTitle(this.text, {super.key, this.leading, this.color = C.goldText});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (leading != null) ...[leading!, const SizedBox(width: 8)],
      Flexible(child: Text(text, style: ts(context, 15, color: color, w: FontWeight.w700))),
    ]);
  }
}

class GoldCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const GoldCheck({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final s = 30 * sc(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: value ? C.gold : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: value ? C.gold : const Color(0xFF777777), width: 1.5),
        ),
        child: value ? Icon(Icons.check_rounded, color: const Color(0xFF2A2A2A), size: s * 0.8) : null,
      ),
    );
  }
}

class Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const Segmented({super.key, required this.labels, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(vertical: 12 * sc(context)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == index ? C.gold : C.inner,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: i == index ? C.gold : C.borderSoft),
                ),
                child: Text(labels[i],
                    style: ts(context, 14,
                        color: i == index ? const Color(0xFF1A1A1A) : C.muted, w: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class GoldBarsIcon extends StatelessWidget {
  final double size;
  const GoldBarsIcon({super.key, this.size = 56});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(size * 0.25)),
      child: CustomPaint(painter: _BarsPainter()),
    );
  }
}

class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xFF2B2B2B);
    final w = s.width * 0.2;
    final h = s.height * 0.13;
    void bar(double cx, double cy) {
      final path = Path()
        ..moveTo(cx - w / 2 + w * 0.15, cy - h / 2)
        ..lineTo(cx + w / 2 - w * 0.15, cy - h / 2)
        ..lineTo(cx + w / 2, cy + h / 2)
        ..lineTo(cx - w / 2, cy + h / 2)
        ..close();
      canvas.drawPath(path, p);
    }

    final cx = s.width / 2;
    final cy = s.height / 2;
    bar(cx, cy - h * 1.1);
    bar(cx - w * 0.55, cy);
    bar(cx + w * 0.55, cy);
    bar(cx - w * 1.1, cy + h * 1.1);
    bar(cx, cy + h * 1.1);
    bar(cx + w * 1.1, cy + h * 1.1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HLine extends StatelessWidget {
  const HLine({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, margin: EdgeInsets.symmetric(vertical: 16 * sc(context)), color: C.divider);
}
