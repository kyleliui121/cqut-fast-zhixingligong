import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'core/store.dart';
import 'ui/home_shell.dart';
import 'ui/login_page.dart';

const Color kSeed = Color(0xFF2F5BFF);
const Color kBg = Color(0xFFF4F5F9);

/// 最近一次未捕获异常，显示在界面上方便排查（release 包也能看到）。
final ValueNotifier<String?> kFatalError = ValueNotifier<String?>(null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    kFatalError.value = details.exceptionAsString();
  };
  ErrorWidget.builder = (details) => _ErrorPane(
        text: details.exceptionAsString(),
        stack: details.stack?.toString() ?? '',
      );

  runZonedGuarded(() async {
    final store = await LocalStore.open();
    final state = AppState(store);
    await state.init();
    runApp(ZhixingApp(state: state));
  }, (error, stack) {
    kFatalError.value = '$error';
  });
}

class _ErrorPane extends StatelessWidget {
  final String text;
  final String stack;

  const _ErrorPane({required this.text, required this.stack});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFDEEEE),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '出错了',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF9B2C2C)),
              ),
              const SizedBox(height: 8),
              SelectableText(
                text,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9B2C2C), height: 1.5),
              ),
              if (stack.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  stack,
                  style: const TextStyle(fontSize: 10, color: Color(0xFFB06A6A), height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ZhixingApp extends StatelessWidget {
  final AppState state;

  const ZhixingApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          title: '知行闪课',
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(),
          builder: (context, child) => ValueListenableBuilder<String?>(
            valueListenable: kFatalError,
            builder: (context, fatal, _) {
              if (fatal == null) return child ?? const SizedBox.shrink();
              return _ErrorPane(text: fatal, stack: '');
            },
          ),
          home: state.initializing
              ? const _SplashScreen()
              : state.loggedIn
                  ? HomeShell(state: state)
                  : LoginPage(state: state),
        );
      },
    );
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kSeed);
  final base = ThemeData(colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      height: 64,
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFEDEFF5),
      thickness: 1,
      space: 1,
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('知行闪课', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 16),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
