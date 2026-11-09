import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../native.dart';
import '../store.dart';
import '../ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  late final TextEditingController _email = TextEditingController(text: app.settings.email);
  bool _batteryOk = false;
  double? _margin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _email.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkBattery();
  }

  Future<void> _checkBattery() async {
    final ok = await Native.isBatteryExempt();
    if (mounted) setState(() => _batteryOk = ok);
  }

  Future<void> _togglePin(bool v) async {
    if (!v) {
      await app.updateSettings((s) {
        s.pinEnabled = false;
        s.pin = '';
      });
      return;
    }
    final c = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: C.border)),
        title: Text(T.t('set_pin'), style: ts(ctx, 17, w: FontWeight.w700, color: C.goldText)),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: ts(ctx, 26, w: FontWeight.w700),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(T.t('cancel'), style: ts(ctx, 14, color: C.muted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.gold),
            onPressed: () {
              if (c.text.length == 4) Navigator.pop(ctx, c.text);
            },
            child: Text(T.t('confirm'), style: ts(ctx, 14, w: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
    if (pin != null && pin.length == 4) {
      await app.updateSettings((s) {
        s.pinEnabled = true;
        s.pin = pin;
      });
    }
  }

  Widget _row(String label, Widget trailing) {
    return Row(children: [
      Expanded(child: Text(label, style: ts(context, 15, color: const Color(0xFFE5E7EB)))),
      const SizedBox(width: 12),
      trailing,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final st = app.settings;
    final margin = _margin ?? st.margin;
    return ListView(
      padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 24 * s),
      children: [
        GoldCard(
          padding: EdgeInsets.fromLTRB(20 * s, 22 * s, 20 * s, 14 * s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(T.t('settings_title'), style: ts(context, 21, w: FontWeight.w700)),
            const HLine(),
            Text(T.t('email'), style: ts(context, 15, color: C.goldText, w: FontWeight.w700)),
            SizedBox(height: 10 * s),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              style: ts(context, 16),
              onChanged: (v) => app.updateSettings((x) => x.email = v.trim()),
              decoration: InputDecoration(
                hintText: 'user@selematrading.com',
                hintStyle: ts(context, 15, color: const Color(0xFF6B7280)),
                filled: true,
                fillColor: C.field,
                contentPadding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 14 * s),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: C.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: C.gold, width: 1.5)),
              ),
            ),
            SizedBox(height: 4 * s),
            Text(T.t('email_note'), style: ts(context, 12, color: C.muted)),
            const HLine(),
            Text(T.t('language'), style: ts(context, 15, color: C.goldText, w: FontWeight.w700)),
            SizedBox(height: 10 * s),
            Segmented(
              labels: const ['العربية (Arabic)', 'English'],
              index: st.lang == 'ar' ? 0 : 1,
              onChanged: (i) => app.updateSettings((x) => x.lang = i == 0 ? 'ar' : 'en'),
            ),
            const HLine(),
            _row(T.t('pin'), GoldCheck(value: st.pinEnabled, onChanged: _togglePin)),
            const HLine(),
            Text(T.t('spreads'), style: ts(context, 15, color: C.goldText, w: FontWeight.w700)),
            SizedBox(height: 12 * s),
            Row(children: [
              Expanded(child: Text(T.t('buy_margin'), style: ts(context, 15, color: const Color(0xFFE5E7EB)))),
              Ltr(Text('EGP ${margin.round()}', style: ts(context, 16, color: C.goldText, w: FontWeight.w700))),
            ]),
            Slider(
              value: margin.clamp(0, 100).toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (v) => setState(() => _margin = v),
              onChangeEnd: (v) async {
                await app.updateSettings((x) => x.margin = v.roundToDouble());
                if (mounted) setState(() => _margin = null);
              },
            ),
            const HLine(),
            _row(T.t('push'), GoldCheck(value: st.push, onChanged: (v) => app.updateSettings((x) => x.push = v))),
            SizedBox(height: 16 * s),
            _row(T.t('sound'), GoldCheck(value: st.sound, onChanged: (v) => app.updateSettings((x) => x.sound = v))),
            const HLine(),
            if (_batteryOk)
              Row(children: [
                Icon(Icons.verified_rounded, color: C.green, size: 22 * s),
                SizedBox(width: 8 * s),
                Expanded(child: Text(T.t('battery_ok'), style: ts(context, 14, color: C.muted))),
              ])
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.goldText,
                    side: const BorderSide(color: C.gold),
                    padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 12 * s),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    await Native.requestBatteryExemption();
                  },
                  icon: Icon(Icons.battery_charging_full_rounded, size: 22 * s),
                  label: Text(T.t('battery'),
                      textAlign: TextAlign.center, style: ts(context, 14, w: FontWeight.w700, color: C.goldText)),
                ),
              ),
            SizedBox(height: 6 * s),
          ]),
        ),
      ],
    );
  }
}
