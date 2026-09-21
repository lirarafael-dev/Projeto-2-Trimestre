import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'home.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  runApp(App(sessaoAtiva: prefs.getBool('sessao_ativa') ?? false));
}

class App extends StatelessWidget {
  final bool sessaoAtiva;

  const App({super.key, required this.sessaoAtiva});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ClassHub",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB4232C),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFFB4232C),
          secondary: const Color(0xFFE87561),
          surface: const Color(0xFFFFFBF8),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF7F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8F1D2C),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        useMaterial3: true,
      ),
      home: sessaoAtiva ? const Home() : const Login(),
    );
  }
}

class MyApp extends App {
  const MyApp({super.key}) : super(sessaoAtiva: false);
}
