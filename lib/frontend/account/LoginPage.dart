import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/HomePage.dart';
import 'package:mira_finance_tracker/frontend/account/SignupPage.dart';
import 'package:mira_finance_tracker/frontend/account/AccountManagementPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

import 'package:mira_finance_tracker/backend/operation/account/Login.dart';

/// Represents the login page where users can authenticate, register,
/// or navigate to account management settings.
class LoginPage extends StatefulWidget {
  /// Creates a [LoginPage] widget instance.
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _login(BuildContext context) async {
    /* put there the logic of authentication and 
    then, if everything goes right, 
    send the user to home page */
    Login loginOperation = Login(_usernameController.text, _passwordController.text);
    bool result = await loginOperation.execute();
    if(!result){
      AppToast.show(context, "Accesso non consentito. Account non esistente.", ToastType.error);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  void _navigateToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignupPage()),
    );
  }

  void _navigateToAccountManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountManagementPage()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          child: Image.asset('assets/logos/extended_logo.png', height: 80, fit: BoxFit.contain,),
          padding: const EdgeInsets.only(top: 16.0),
        ),
        centerTitle: true
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                // Limits the maximum width of the input fields box container
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Benvenuto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(Icons.person, color: Colors.teal),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal, width: 2.0),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal, width: 2.0),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await _login(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Accedi', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _navigateToRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Registrati', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _navigateToAccountManagement,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber.shade900,
                      ),
                      child: const Text(
                        'Gestione Account',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}