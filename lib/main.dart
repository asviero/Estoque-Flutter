import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const CasaNoturnaApp());
}

class CasaNoturnaApp extends StatelessWidget {
  const CasaNoturnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const corPrimaria = Color(0xFF7C3AED);
    const corFundo = Color(0xFF0A0A0F);
    const corSuperficie = Color(0xFF13131F);
    const corAppBar = Color(0xFF10101A);

    return MaterialApp(
      title: 'Controle de Estoque',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: corPrimaria,
          secondary: const Color(0xFFA78BFA),
          surface: corSuperficie,
          onPrimary: Colors.white,
          onSurface: const Color(0xFFDDD0F5),
        ),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: corFundo,
        appBarTheme: const AppBarTheme(
          backgroundColor: corAppBar,
          foregroundColor: Color(0xFFE8D5FF),
          elevation: 0,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: const Color(0xFFC084FC),
          unselectedLabelColor: const Color(0xFF5A5070),
          indicator: BoxDecoration(
            color: const Color(0xFF1E1030),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF6D28D9), width: 0.5),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: corSuperficie,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF2A2040), width: 0.5),
          ),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D0D1A),
          labelStyle: const TextStyle(color: Color(0xFF9880C0)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3D2F6E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3D2F6E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF7C3AED)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF10101A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2040), width: 0.5),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1E1030),
          contentTextStyle: const TextStyle(color: Color(0xFFDDD0F5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF5B21B6),
          foregroundColor: Color(0xFFE9D5FF),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFA78BFA)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5B21B6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return corPrimaria;
            return Colors.transparent;
          }),
          side: const BorderSide(color: Color(0xFF6D28D9)),
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
