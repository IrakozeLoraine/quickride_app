import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:quickride/config/theme_config.dart';
import 'package:quickride/core/localization/kinyarwanda_material_localization.dart';
import 'package:quickride/data/providers/auth_provider.dart';
import 'package:quickride/data/providers/language_provider.dart';
import 'package:quickride/data/providers/location_provider.dart';
import 'package:quickride/data/providers/ride_provider.dart';
import 'package:quickride/data/providers/theme_provider.dart';
import 'package:quickride/firebase_options.dart';
import 'package:quickride/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => LocationProvider()),
      ChangeNotifierProvider(create: (_) => RideProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuickRide',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode 
        ? ThemeMode.dark
        : themeProvider.isLightMode
          ? ThemeMode.light
          : ThemeMode.system,
      locale: languageProvider.locale,
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('fr', ''), // French
        Locale('rw', ''), // Kinyarwanda
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        KinyarwandaMaterialLocalizations()
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return const Locale('en', '');
      },
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
