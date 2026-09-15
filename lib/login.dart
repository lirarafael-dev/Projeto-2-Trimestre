import 'authentication.dart';
import 'home.dart';
import 'package:flutter/material.dart';

import 'signup.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Padding(padding: EdgeInsets.all(16.0), child: LoginForm()),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(width: 30),
              const Text(
                "Ainda não possui cadastro? ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Signup()),
                  );
                },
                child: const Text(
                  "Registre-se!",
                  style: TextStyle(fontSize: 20, color: Colors.blue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();

  String? email;
  String? senha;

  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          TextFormField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(100.0)),
              ),
            ),
            validator: (value) {
              if (value!.isEmpty) {
                return 'Campo vazio';
              }
              return null;
            },
            onSaved: (val) {
              email = val;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(100.0)),
              ),
              suffixIcon: GestureDetector(
                onTap: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
                child: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            obscureText: _obscureText,
            onSaved: (val) {
              senha = val;
            },
            validator: (value) {
              if (value!.isEmpty) {
                return 'Campo vazio';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 54,
            width: 184,
            child: ElevatedButton(
              onPressed: () {
                // Respond to button press

                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  AuthenticationHelper()
                      .signIn(email: email!, password: senha!)
                      .then((result) {
                        if (result == null) {
                          SharedPreferences.getInstance().then((prefs) {
                            prefs.setBool('sessao_ativa', true);
                          });
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Home(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AuthenticationHelper().traduzirRetorno(result),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          );
                        }
                      });
                }
              },
              style: ElevatedButton.styleFrom(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24.0)),
                ),
              ),
              child: const Text('Login', style: TextStyle(fontSize: 24)),
            ),
          ),
        ],
      ),
    );
  }
}
