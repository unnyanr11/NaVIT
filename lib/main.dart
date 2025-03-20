import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'theme_provider.dart';
import 'language_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/navigation_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/indoor_navigation_screen.dart';
import 'screens/direction_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
  final savedLanguage = prefs.getString('language_code') ?? 'en';
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isDarkTheme: isDarkTheme, savedLanguage: savedLanguage, isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isDarkTheme;
  final String savedLanguage;
  final bool isLoggedIn;

  MyApp({required this.isDarkTheme, required this.savedLanguage, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialTheme: isDarkTheme ? ThemeMode.dark : ThemeMode.light),
        ),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(initialLanguage: savedLanguage),
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return MaterialApp(
            title: 'Campus Navigation App',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                bodyColor: Colors.blue[800],
                displayColor: Colors.blue[800],
              ),
            ),
            locale: languageProvider.locale,
            supportedLocales: [
              Locale('en', ''),
              Locale('es', ''),
              Locale('fr', ''),
            ],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: isLoggedIn ? '/home' : '/login',
            routes: {
              '/': (context) => SplashScreen(),
              '/login': (context) => LoginScreen(),
              '/home': (context) => HomeScreen(),
              '/search': (context) => SearchScreen(),
              '/navigation': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is Map<String, String>) {
                  return NavigationScreen(
                    start: args['start'] ?? '',
                    destination: args['destination'] ?? '',
                  );
                }
                return NavigationScreen(start: '', destination: '');
              },
              '/settings': (context) => SettingsScreen(),
              '/indoor_navigation': (context) => IndoorNavigationScreen(),
              '/direction': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is Map<String, dynamic>) {
                  return DirectionScreen(
                    startLatLng: args['startLatLng'],
                    destinationLatLng: args['destinationLatLng'],
                  );
                }
                return DirectionScreen(startLatLng: LatLng(0, 0), destinationLatLng: LatLng(0, 0));
              },
            },
          );
        },
      ),
    );
  }
}
