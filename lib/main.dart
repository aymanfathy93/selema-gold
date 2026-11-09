import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n.dart';
import 'models.dart';
import 'screens/alerts_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/deals_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/prices_screen.dart';
import 'screens/settings_screen.dart';
import 'store.dart';
import 'ui.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: C.bg,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.panel,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await app.init();
  runApp(const SelemaApp());
}

class SelemaApp extends StatelessWidget {
  const SelemaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final ar = T.ar;
        return MaterialApp(
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          title: 'Selema Gold',
          locale: Locale(ar ? 'ar' : 'en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: 'Cairo',
            scaffoldBackgroundColor: C.bg,
            colorScheme: const ColorScheme.dark(primary: C.gold, secondary: C.gold, surface: C.card),
            sliderTheme: const SliderThemeData(
              activeTrackColor: C.gold,
              inactiveTrackColor: Color(0xFF3A3A3A),
              thumbColor: C.gold,
              overlayColor: Color(0x33C9AE84),
              trackHeight: 14,
            ),
          ),
          home: app.unlocked ? const HomeShell() : const LockScreen(),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  StreamSubscription<AlertEvent>? _sub;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = app.incoming.listen(_showAlert);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) app.onResume();
    if (state == AppLifecycleState.paused) app.onPause();
  }

  Future<void> _showAlert(AlertEvent ev) async {
    final ctx = navKey.currentContext;
    if (ctx == null || _dialogOpen) return;
    _dialogOpen = true;
    final label = '${ev.type == 'buy' ? T.t('buy') : T.t('sell')} (${karatLabel(ev.karat)})';
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22), side: const BorderSide(color: C.goldBright, width: 1.5)),
        title: Row(children: [
          const Icon(Icons.notifications_active_rounded, color: C.goldBright, size: 30),
          const SizedBox(width: 10),
          Expanded(child: Text(T.t('alert_hit'), style: ts(c, 18, w: FontWeight.w700, color: C.goldText))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: ts(c, 15, color: C.muted)),
          const SizedBox(height: 6),
          Ltr(Text('${unitOf(ev.karat)} ${f2(ev.price)}', style: ts(c, 26, w: FontWeight.w700))),
          const SizedBox(height: 6),
          Text('${T.t('range')} ${f2(ev.low)} - ${f2(ev.high)}', style: ts(c, 14, color: C.gold)),
          const SizedBox(height: 12),
          Text(T.t('open_trading'), style: ts(c, 14)),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              app.stopAlarm();
              Navigator.of(c).pop();
              setState(() => _tab = 2);
            },
            child: Text(T.t('view_deals'), style: ts(c, 14, color: C.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.gold, foregroundColor: const Color(0xFF1A1A1A)),
            onPressed: () {
              app.stopAlarm();
              Navigator.of(c).pop();
            },
            child: Text(T.t('stop_sound'), style: ts(c, 14, w: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: app, builder: (context, _) => _shell(context));
  }

  Widget _shell(BuildContext context) {
    // new (non-const) instances so every screen rebuilds when app state changes
    final screens = <Widget>[PricesScreen(), ChartScreen(), DealsScreen(), AlertsScreen(), SettingsScreen()];
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              _TopBar(),
              Expanded(child: IndexedStack(index: _tab, children: screens)),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(index: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

class _TopBar extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _TopBar();
  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    return Container(
      padding: EdgeInsets.fromLTRB(18 * s, 10 * s, 18 * s, 12 * s),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF3A3326), width: 1)),
      ),
      child: Row(children: [
        GoldBarsIcon(size: 38 * s),
        SizedBox(width: 10 * s),
        Expanded(
          child: Ltr(Align(
            alignment: T.ar ? Alignment.centerRight : Alignment.centerLeft,
            child: RichText(
              text: TextSpan(children: [
                TextSpan(text: 'Selema ', style: ts(context, 19, w: FontWeight.w700, color: C.goldText)),
                TextSpan(text: 'Trading', style: ts(context, 19, w: FontWeight.w700)),
              ]),
            ),
          )),
        ),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: app.failed ? C.red : C.green,
            boxShadow: [BoxShadow(color: (app.failed ? C.red : C.green).withOpacity(0.6), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 6),
        Text('LIVE', style: ts(context, 12, color: C.muted, w: FontWeight.w700)),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = sc(context);
    final items = <(IconData, String)>[
      (Icons.bar_chart_rounded, T.t('tab_prices')),
      (Icons.insert_chart_outlined_rounded, T.t('tab_chart')),
      (Icons.toll_rounded, T.t('tab_deals')),
      (Icons.notifications_rounded, T.t('tab_alerts')),
      (Icons.tune_rounded, T.t('tab_settings')),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: Color(0xFF3A3326), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * s),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4 * s),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Icon(items[i].$1, size: 30 * s, color: i == index ? C.goldText : C.muted),
                        if (i == 2)
                          Positioned(
                            top: -8,
                            right: -14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              constraints: const BoxConstraints(minWidth: 20),
                              decoration: BoxDecoration(
                                color: C.gold,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: C.panel, width: 2),
                              ),
                              child: Text('${app.activeCount}',
                                  textAlign: TextAlign.center,
                                  style: ts(context, 11, w: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                            ),
                          ),
                      ]),
                      SizedBox(height: 4 * s),
                      FittedBox(
                        child: Text(items[i].$2,
                            style: ts(context, 13,
                                color: i == index ? C.goldText : C.muted,
                                w: i == index ? FontWeight.w700 : FontWeight.w400)),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
