import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

class PricesScreen extends StatelessWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final q = app.quote;
    return RefreshIndicator(
      color: C.gold,
      backgroundColor: C.card,
      onRefresh: app.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 24 * s),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(T.t('live_prices'), style: ts(context, 20, color: C.goldText, w: FontWeight.w700)),
            ),
            if (q != null) ...[
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${T.t('updated')} ${fmtDateTime(q.updated).split(' ').first}',
                    style: ts(context, 13, color: C.muted)),
                Ltr(Text(fmtDateTime(q.updated).split(' ').last, style: ts(context, 13, color: C.muted))),
              ]),
              const SizedBox(width: 6),
              Icon(Icons.access_time_filled_rounded, color: C.gold, size: 18 * s),
            ],
          ]),
          SizedBox(height: 16 * s),
          if (q == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 60 * s),
              child: Column(children: [
                if (app.loading || !app.failed) const CircularProgressIndicator(color: C.gold),
                SizedBox(height: 16 * s),
                Text(app.failed ? T.t('no_data') : T.t('loading'),
                    textAlign: TextAlign.center, style: ts(context, 14, color: C.muted)),
              ]),
            )
          else ...[
            _KaratCard(karat: 24, sell: q.sell(24), buy: q.buy(24, app.settings.margin)),
            SizedBox(height: 14 * s),
            _KaratCard(karat: 21, sell: q.sell(21), buy: q.buy(21, app.settings.margin)),
            SizedBox(height: 14 * s),
            _OunceCard(q: q),
            SizedBox(height: 14 * s),
            _DollarCard(q: q),
          ],
        ],
      ),
    );
  }
}

class _KaratCard extends StatelessWidget {
  final int karat;
  final double sell;
  final double buy;
  const _KaratCard({required this.karat, required this.sell, required this.buy});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    return GoldCard(
      padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 20 * s),
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(child: _PriceCell(label: '${T.t('sell')} (${karat}K)', value: sell, up: true)),
          Container(width: 1, margin: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s), color: C.border),
          Expanded(child: _PriceCell(label: '${T.t('buy')} (${karat}K)', value: buy, up: false)),
        ]),
      ),
    );
  }
}

class _PriceCell extends StatelessWidget {
  final String label;
  final double value;
  final bool up;
  const _PriceCell({required this.label, required this.value, required this.up});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Ltr(Text(label, style: ts(context, 14, color: C.muted))),
      SizedBox(height: 6 * s),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: T.ar ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Ltr(Text(f2(value), style: ts(context, 26, w: FontWeight.w700))),
          const SizedBox(width: 6),
          Text('EGP', style: ts(context, 15, color: C.muted)),
          const SizedBox(width: 8),
          Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
              color: up ? C.green : C.red, size: 30 * s),
        ]),
      ),
    ]);
  }
}

class _OunceCard extends StatelessWidget {
  final Quote q;
  const _OunceCard({required this.q});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final up = q.change >= 0;
    final col = up ? C.green : C.red;
    final sign = up ? '+' : '-';
    return GoldCard(
      borderColor: C.goldBright,
      width: 1.6,
      child: Column(children: [
        Row(children: [
          GoldBarsIcon(size: 60 * s),
          SizedBox(width: 14 * s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Ltr(RichText(
                text: TextSpan(children: [
                  TextSpan(text: 'GOLD ', style: ts(context, 20, w: FontWeight.w700)),
                  TextSpan(text: 'XAU/USD', style: ts(context, 15, color: C.muted)),
                ]),
              )),
              Text(T.t('ounce_global'), style: ts(context, 14, color: C.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Ltr(Row(mainAxisSize: MainAxisSize.min, children: [
                Text('USD ', style: ts(context, 15, color: C.muted)),
                Text(f3(q.xau), style: ts(context, 24, w: FontWeight.w700)),
              ])),
            ),
            if (q.prevClose > 0)
              Ltr(Text('$sign${f3(q.change.abs())}   $sign${f2(q.changePct.abs())}%',
                  style: ts(context, 14, color: col, w: FontWeight.w700))),
          ]),
        ]),
        Container(height: 1, margin: EdgeInsets.symmetric(vertical: 14 * s), color: C.divider),
        Row(children: [
          Expanded(child: _StatBox(label: T.t('day_high'), value: q.dayHigh, color: C.green)),
          SizedBox(width: 12 * s),
          Expanded(child: _StatBox(label: T.t('day_low'), value: q.dayLow, color: C.red)),
        ]),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
      decoration: BoxDecoration(
        color: C.inner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.borderSoft),
      ),
      child: Row(children: [
        Expanded(child: Text(label, style: ts(context, 14, color: C.muted))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Ltr(Text(f2(value), style: ts(context, 16, color: color, w: FontWeight.w700))),
          Text('USD', style: ts(context, 13, color: color, w: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _DollarCard extends StatelessWidget {
  final Quote q;
  const _DollarCard({required this.q});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    return GoldCard(
      padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 16 * s),
      child: Row(children: [
        Container(
          width: 46 * s,
          height: 46 * s,
          decoration: BoxDecoration(
            color: C.inner,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border),
          ),
          child: Icon(Icons.attach_money_rounded, color: C.goldText, size: 28 * s),
        ),
        SizedBox(width: 14 * s),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(T.t('usd_egp'), style: ts(context, 16, w: FontWeight.w700)),
            Ltr(Text(T.t('usd_egp_sub'), style: ts(context, 13, color: C.muted))),
          ]),
        ),
        Ltr(Row(mainAxisSize: MainAxisSize.min, children: [
          Text('EGP ', style: ts(context, 14, color: C.muted)),
          Text(q.usdEgp.toStringAsFixed(4), style: ts(context, 22, w: FontWeight.w700, color: C.goldText)),
        ])),
      ]),
    );
  }
}
