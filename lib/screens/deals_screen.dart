import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

class DealsScreen extends StatelessWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final active = app.activeDeals;
    final done = app.doneDeals;
    return ListView(
      padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 24 * s),
      children: [
        Row(children: [
          Expanded(child: Text(T.t('deals_title'), style: ts(context, 19, w: FontWeight.w700))),
          SizedBox(width: 10 * s),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: C.gold,
              foregroundColor: const Color(0xFF1A1A1A),
              padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 12 * s),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => showNewDealSheet(context),
            icon: Icon(Icons.add_rounded, size: 22 * s),
            label: Text(T.t('new_range'), style: ts(context, 15, w: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          ),
        ]),
        SizedBox(height: 22 * s),
        SectionTitle('${T.t('active_deals')} (${active.length})',
            leading: Icon(Icons.blur_circular_rounded, color: C.goldText, size: 20 * s)),
        SizedBox(height: 12 * s),
        if (active.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16 * s),
            child: Center(child: Text(T.t('no_active'), style: ts(context, 15, color: C.muted))),
          )
        else
          for (final d in active) _DealTile(d: d),
        const HLine(),
        Row(children: [
          Expanded(
            child: SectionTitle('${T.t('done_deals')} (${done.length})',
                color: const Color(0xFFD5D8DD),
                leading: Icon(Icons.check_circle_rounded, color: C.green, size: 20 * s)),
          ),
          if (done.isNotEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF2A1414),
                foregroundColor: const Color(0xFFF07B72),
                side: const BorderSide(color: Color(0xFF8A2D27)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
              ),
              onPressed: app.clearDone,
              icon: Icon(Icons.delete_rounded, size: 18 * s),
              label: Text(T.t('clear_done'),
                  style: ts(context, 14, w: FontWeight.w700, color: const Color(0xFFF07B72))),
            ),
        ]),
        SizedBox(height: 12 * s),
        for (final d in done) _DealTile(d: d),
      ],
    );
  }
}

class _DealTile extends StatelessWidget {
  final Deal d;
  const _DealTile({required this.d});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final col = d.isBuy ? C.green : C.red;
    final now = app.watchedPrice(d);
    final label = d.isBuy ? T.t('buy_deal') : T.t('sell_deal');
    final watched = '${d.isBuy ? T.t('buy') : T.t('sell')} (${d.karat}K)';
    return Container(
      margin: EdgeInsets.only(bottom: 12 * s),
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: d.active ? C.border : const Color(0xFF242B35)),
      ),
      child: Row(children: [
        Container(
          width: 52 * s,
          height: 52 * s,
          decoration: BoxDecoration(
            color: col.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: col.withOpacity(0.45)),
          ),
          child: Icon(d.isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: col, size: 28 * s),
        ),
        SizedBox(width: 14 * s),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 14 * s,
                  height: 14 * s,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: d.isBuy ? const Color(0xFF6BA539) : const Color(0xFFC0392B))),
              SizedBox(width: 6 * s),
              Flexible(child: Text(label, style: ts(context, 17, w: FontWeight.w700))),
              SizedBox(width: 10 * s),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 2 * s),
                decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(8)),
                child: Text('${d.karat}K', style: ts(context, 13, color: C.muted)),
              ),
            ]),
            SizedBox(height: 2 * s),
            Row(children: [
              Text('${T.t('range')} ', style: ts(context, 13, color: C.muted)),
              Flexible(
                child: Ltr(Text('${f2(d.low)} -> ${f2(d.high)}',
                    overflow: TextOverflow.ellipsis, style: ts(context, 16, color: C.gold, w: FontWeight.w700))),
              ),
            ]),
            if (d.active && now != null)
              Text('${T.t('watching')} $watched • ${T.t('now')} ${f2(now)}',
                  style: ts(context, 12, color: C.muted)),
            if (!d.active && d.hitPrice != null)
              Text(
                  '${T.t('hit_at')} ${f2(d.hitPrice!)}'
                  '${d.hitAt != null ? ' • ${fmtShort(DateTime.fromMillisecondsSinceEpoch(d.hitAt!))}' : ''}',
                  style: ts(context, 12, color: C.muted)),
          ]),
        ),
        SizedBox(width: 10 * s),
        InkWell(
          onTap: () => app.deleteDeal(d.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 46 * s,
            height: 52 * s,
            decoration: BoxDecoration(
              color: const Color(0xFF2A1414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6E2621)),
            ),
            child: Icon(Icons.delete_rounded, color: const Color(0xFFE0645B), size: 22 * s),
          ),
        ),
      ]),
    );
  }
}

Future<void> showNewDealSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (c) => const _NewDealSheet(),
  );
}

class _NewDealSheet extends StatefulWidget {
  const _NewDealSheet();
  @override
  State<_NewDealSheet> createState() => _NewDealSheetState();
}

class _NewDealSheetState extends State<_NewDealSheet> {
  int _type = 0;
  int _karat = 0;
  final _low = TextEditingController();
  final _high = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _low.dispose();
    _high.dispose();
    super.dispose();
  }

  double? _current() {
    final q = app.quote;
    if (q == null) return null;
    final k = _karat == 0 ? 24 : 21;
    return _type == 0 ? q.buy(k, app.settings.margin) : q.sell(k);
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      textDirection: TextDirection.ltr,
      style: ts(context, 18, w: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: ts(context, 14, color: C.muted),
        filled: true,
        fillColor: C.field,
        suffixText: 'EGP',
        suffixStyle: ts(context, 13, color: C.muted),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.gold, width: 1.6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final cur = _current();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20 * s, 14 * s, 20 * s, 20 * s),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                  width: 44, height: 5, decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(3))),
            ),
            SizedBox(height: 14 * s),
            Text(T.t('new_deal'), style: ts(context, 19, w: FontWeight.w700, color: C.goldText)),
            SizedBox(height: 16 * s),
            Text(T.t('deal_type'), style: ts(context, 14, color: C.muted)),
            SizedBox(height: 8 * s),
            Segmented(
                labels: ['🟢 ${T.t('buy_deal')}', '🔴 ${T.t('sell_deal')}'],
                index: _type,
                onChanged: (i) => setState(() => _type = i)),
            SizedBox(height: 14 * s),
            Text(T.t('karat'), style: ts(context, 14, color: C.muted)),
            SizedBox(height: 8 * s),
            Segmented(labels: const ['24K', '21K'], index: _karat, onChanged: (i) => setState(() => _karat = i)),
            SizedBox(height: 14 * s),
            if (cur != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12 * s),
                decoration: BoxDecoration(
                    color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.borderSoft)),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        '${T.t('current')} ${_type == 0 ? T.t('buy') : T.t('sell')} (${_karat == 0 ? 24 : 21}K)',
                        style: ts(context, 13, color: C.muted)),
                  ),
                  Ltr(Text(f2(cur), style: ts(context, 17, w: FontWeight.w700, color: C.goldText))),
                ]),
              ),
            SizedBox(height: 14 * s),
            Row(children: [
              Expanded(child: _field(_low, T.t('from'))),
              SizedBox(width: 12 * s),
              Expanded(child: _field(_high, T.t('to'))),
            ]),
            if (_err != null) ...[
              SizedBox(height: 8 * s),
              Text(_err!, style: ts(context, 13, color: C.red)),
            ],
            SizedBox(height: 18 * s),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: C.gold,
                  padding: EdgeInsets.symmetric(vertical: 14 * s),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () async {
                  final lo = double.tryParse(_low.text.trim());
                  var hi = double.tryParse(_high.text.trim());
                  hi ??= lo;
                  if (lo == null || hi == null || lo <= 0 || hi <= 0) {
                    setState(() => _err = T.t('invalid'));
                    return;
                  }
                  await app.addDeal(_type == 0 ? 'buy' : 'sell', _karat == 0 ? 24 : 21, lo, hi);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(T.t('save'), style: ts(context, 16, w: FontWeight.w700, color: const Color(0xFF1A1A1A))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
