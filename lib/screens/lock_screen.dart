import 'package:flutter/material.dart';

import '../i18n.dart';
import '../store.dart';
import '../ui.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _wrong = false;

  void _press(String k) {
    setState(() {
      _wrong = false;
      if (k == '<') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 4) {
        _pin += k;
      }
    });
    if (_pin.length == 4) {
      if (!app.checkPin(_pin)) {
        setState(() {
          _wrong = true;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: EdgeInsets.all(24 * s),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                GoldBarsIcon(size: 72 * s),
                SizedBox(height: 16 * s),
                Text(T.t('enter_pin'), style: ts(context, 20, w: FontWeight.w700, color: C.goldText)),
                SizedBox(height: 20 * s),
                Ltr(Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? C.gold : Colors.transparent,
                        border: Border.all(color: _wrong ? C.red : C.gold, width: 2),
                      ),
                    ),
                ])),
                SizedBox(height: 10 * s),
                SizedBox(
                  height: 24 * s,
                  child: _wrong ? Text(T.t('wrong_pin'), style: ts(context, 14, color: C.red)) : null,
                ),
                SizedBox(height: 10 * s),
                Ltr(GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.4,
                  children: [
                    for (final k in keys)
                      k.isEmpty
                          ? const SizedBox()
                          : InkWell(
                              onTap: () => _press(k),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: C.card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: C.border),
                                ),
                                child: k == '<'
                                    ? Icon(Icons.backspace_rounded, color: C.goldText, size: 24 * s)
                                    : Text(k, style: ts(context, 24, w: FontWeight.w700)),
                              ),
                            ),
                  ],
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
