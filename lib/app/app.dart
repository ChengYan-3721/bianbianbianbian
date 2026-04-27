import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_router.dart';
import 'app_theme.dart';

class BianBianApp extends StatelessWidget {
  const BianBianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '边边记账',
      theme: appTheme,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
