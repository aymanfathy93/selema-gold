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
    final now = app.quote?.updated ?? DateTime.now();
    return ListView(
      padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 24 * s),
      children: [
        // header card
        GoldCard(
          padding: EdgeInsets.all(16 * s),
          child: Row(children: [
            Container(
              width: 48 * s,
              height: 48 * s,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(14)),
              child: Text('S', style: ts(context, 22, w: FontWeight.w700, color: const Color(0xFF2B2B2B))),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Ltr(Text('Selema Trading', style: ts(context, 18, w: FontWeight.w700))),
                Text(T.t('alerts_sub'), style: ts(context, 13, color: C.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 2 * s),
                decoration: BoxDecoration(
                  color: C.inner,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.borderSoft),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: app.failed ? C.red : C.green)),
                  const SizedBox(width: 6),
                  Text('LIVE', style: ts(context, 11, w: FontWeight.w700, color: C.muted)),
                ]),
              ),
              SizedBox(height: 4 * s),
              Ltr(Text('${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
                  style: ts(context, 14, w: FontWeight.w700, color: C.goldText))),
              Ltr(Text('${now.year}-${two(now.month)}-${two(now.day)}', style: ts(context, 11, color: C.muted))),
            ]),
          ]),
        ),
        SizedBox(height: 14 * s),
        if (app.ringing) ...[
          GoldCard(
            borderColor: C.red,
            width: 1.8,
            child: Row(children: [
              Icon(Icons.notifications_active_rounded, color: C.red, size: 32 * s),
              SizedBox(width: 12 * s),
              Expanded(child: Text(T.t('ringing'), style: ts(context, 16, w: FontWeight.w700))),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: C.red,
                  padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                ),
                onPressed: app.stopAlarm,
                icon: const Icon(Icons.volume_off_rounded, color: Colors.white),
                label: Text(T.t('stop_sound'), style: ts(context, 15, w: FontWeight.w700)),
              ),
            ]),
          ),
          SizedBox(height: 14 * s),
        ],
        Row(children: [
          Icon(Icons.notifications_rounded, color: C.goldText, size: 22 * s),
          SizedBox(width: 8 * s),
          Expanded(child: Text(T.t('alerts_log'), style: ts(context, 18, w: FontWeight.w700))),
          if (app.events.isNotEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF2A1414),
                foregroundColor: const Color(0xFFF07B72),
                side: const BorderSide(color: Color(0xFF8A2D27)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
              ),
              onPressed: app.clearEvents,
              icon: Icon(Icons.delete_rounded, size: 18 * s),
              label: Text(T.t('clear_all'), style: ts(context, 13, w: FontWeight.w700, color: const Color(0xFFF07B72))),
            ),
        ]),
        SizedBox(height: 12 * s),
        if (app.events.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24 * s),
            child: Center(child: Text(T.t('no_alerts'), style: ts(context, 15, color: C.muted))),
          )
        else
          for (final e in app.events) _EventTile(e: e),
        SizedBox(height: 8 * s),
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: app.serviceRunning ? C.green : const Color(0xFF6B7280)),
          ),
          SizedBox(width: 8 * s),
          Expanded(
            child: Text(app.serviceRunning ? T.t('bg_on') : T.t('bg_off'), style: ts(context, 13, color: C.muted)),
          ),
          TextButton.icon(
            onPressed: app.testAlert,
            icon: Icon(Icons.campaign_rounded, color: C.goldText, size: 20 * s),
            label: Text(T.t('test_alert'), style: ts(context, 13, w: FontWeight.w700, color: C.goldText)),
          ),
        ]),
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
    final buy = e.type == 'buy';
    final col = e.test ? C.goldBright : (buy ? C.green : C.red);
    final title = e.test
        ? T.t('test_alert')
        : '${T.t('hit_title')} ${buy ? T.t('buy_word') : T.t('sell_word')} (${karatLabel(e.karat)})';
    final t = DateTime.fromMillisecondsSinceEpoch(e.time);
    return Container(
      margin: EdgeInsets.only(bottom: 12 * s),
      padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 12 * s),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withOpacity(0.75), width: 1.6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(e.test ? Icons.campaign_rounded : (buy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
              color: col, size: 20 * s),
          SizedBox(width: 6 * s),
          Expanded(child: Text(title, style: ts(context, 16, w: FontWeight.w700, color: col))),
        ]),
        SizedBox(height: 4 * s),
        if (!e.test) ...[
          Text(T.t('hit_body'), style: ts(context, 14, color: const Color(0xFFE5E7EB))),
          Ltr(Text('${f2(e.price)} ${unitOf(e.karat)}   [${f2(e.low)} - ${f2(e.high)}]',
              style: ts(context, 14, w: FontWeight.w700, color: C.gold))),
        ] else
          Text(T.t('test_body'), style: ts(context, 14, color: const Color(0xFFE5E7EB))),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Ltr(Text(fmtShort(t), style: ts(context, 12, color: C.muted))),
        ),
      ]),
    );
  }
}
