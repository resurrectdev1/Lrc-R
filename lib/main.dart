import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'models/lrc_session.dart';
import 'theme/lrc_theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = LrcSettings();
  await settings.init(null, null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => LrcSession()),
      ],
      child: const LrcMakerApp(),
    ),
  );
}

class LrcMakerApp extends StatelessWidget {
  const LrcMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final settings = context.read<LrcSettings>();
        if (lightDynamic != null || darkDynamic != null) {
          settings.applyDynamicColorsIfChanged(lightDynamic, darkDynamic);
        }
        return Consumer<LrcSettings>(
          builder: (ctx, settings, child) {
            final gt = settings.theme;
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              statusBarColor:                    Colors.transparent,
              statusBarIconBrightness:           gt.brightness == Brightness.light ? Brightness.dark : Brightness.light,
              systemNavigationBarColor:          gt.bg,
              systemNavigationBarIconBrightness: gt.brightness == Brightness.light ? Brightness.dark : Brightness.light,
            ));
            return MaterialApp(
              title:                      'Lrc-R',
              debugShowCheckedModeBanner: false,
              theme:                      _buildTheme(gt),
              home:                       const LrcHomeScreen(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme(LrcTheme gt) {
    final cs = ColorScheme.fromSeed(
      seedColor:  gt.primary,
      brightness: gt.brightness,
    ).copyWith(
      surface:                 gt.surface,
      surfaceContainerHighest: gt.surfaceHigh,
      primary:                 gt.primary,
      error:                   LrcTheme.errorRed,
      onSurface:               gt.textPrimary,
      onPrimary:               Colors.white,
    );
    return ThemeData(
      useMaterial3:            true,
      brightness:              gt.brightness,
      colorScheme:             cs,
      scaffoldBackgroundColor: gt.bg,
      dialogTheme: DialogThemeData(
        backgroundColor: gt.surfaceHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:        true,
        fillColor:     gt.surface,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: gt.textMuted)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: gt.textMuted)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: gt.primary, width: 1.5)),
        labelStyle:    TextStyle(color: gt.textSecondary),
        hintStyle:     TextStyle(color: gt.textMuted),
      ),
    );
  }
}
