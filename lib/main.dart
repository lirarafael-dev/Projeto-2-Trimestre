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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: sessaoAtiva ? const Home() : const Login(),
    );
  }
}

// Mantém compatibilidade com o teste padrão criado pelo Flutter.
class MyApp extends App {
  const MyApp({super.key}) : super(sessaoAtiva: false);
}
