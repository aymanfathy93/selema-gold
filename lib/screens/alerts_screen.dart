import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 24 * s),
      children: [
        Text(T.t('alerts_title'), style: ts(context, 20, color: C.goldText, w: FontWeight.w700)),
        SizedBox(height: 14 * s),
        if (app.ringing) ...[
          GoldCard(
            borderColor: C.red,
            width: 1.6,
            child: Row(children: [
              Icon(Icons.notifications_active_rounded, color: C.red, size: 32 * s),
              SizedBox(width: 12 * s),
              Expanded(child: Text(T.t('ringing'), style: ts(context, 16, w: FontWeight.w700))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.red),
                onPressed: app.stopAlarm,
                child: Text(T.t('stop_sound'), style: ts(context, 14, w: FontWeight.w700)),
              ),
            ]),
          ),
          SizedBox(height: 14 * s),
        ],
        GoldCard(
          child: Column(children: [
            Row(children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: app.serviceRunning ? C.green : const Color(0xFF6B7280)),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(app.serviceRunning ? T.t('bg_on') : T.t('bg_off'),
                    style: ts(context, 14, color: app.serviceRunning ? C.text : C.muted)),
              ),
            ]),
            SizedBox(height: 14 * s),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.goldText,
                  side: const BorderSide(color: C.gold),
                  padding: EdgeInsets.symmetric(vertical: 12 * s),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: app.testAlert,
                icon: Icon(Icons.campaign_rounded, size: 22 * s),
                label: Text(T.t('test_alert'), style: ts(context, 15, w: FontWeight.w700, color: C.goldText)),
              ),
            ),
          ]),
        ),
        SizedBox(height: 18 * s),
        Row(children: [
          Expanded(
            child: SectionTitle('${T.t('tab_alerts')} (${app.events.length})',
                leading: Icon(Icons.history_rounded, color: C.goldText, size: 20 * s)),
          ),
          if (app.events.isNotEmpty)
            TextButton(
              onPressed: app.clearEvents,
              child: Text(T.t('clear_log'), style: ts(context, 14, color: const Color(0xFFF07B72))),
            ),
        ]),
        SizedBox(height: 10 * s),
        if (app.events.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24 * s),
            child: Center(child: Text(T.t('no_alerts'), style: ts(context, 15, color: C.muted))),
          )
        else
          for (final e in app.events) _EventTile(e: e),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final AlertEvent e;
  const _EventTile({required this.e});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final col = e.type == 'buy' ? C.green : C.red;
    final what = e.karat == 0 ? 'XAU/USD' : '${e.type == 'buy' ? T.t('buy') : T.t('sell')} (${e.karat}K)';
    return Container(
      margin: EdgeInsets.only(bottom: 10 * s),
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.borderSoft),
      ),
      child: Row(children: [
        Container(
          width: 44 * s,
          height: 44 * s,
          decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(e.test ? Icons.campaign_rounded : Icons.notifications_active_rounded, color: col, size: 24 * s),
        ),
        SizedBox(width: 12 * s),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.test ? T.t('test_alert') : '$what ${T.t('reached')} ${f2(e.price)}',
                style: ts(context, 15, w: FontWeight.w700)),
            if (!e.test)
              Text('${T.t('range')} ${f2(e.low)} - ${f2(e.high)}', style: ts(context, 13, color: C.gold)),
            Ltr(Text(fmtDateTime(DateTime.fromMillisecondsSinceEpoch(e.time)),
                style: ts(context, 12, color: C.muted))),
          ]),
        ),
      ]),
    );
  }
}
