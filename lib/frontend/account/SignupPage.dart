import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';
import 'package:mira_finance_tracker/frontend/account/LoginPage.dart';
import 'package:mira_finance_tracker/frontend/account/GoogleConnectionPage.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/backend/operation/account/Signup.dart';

/// Main entry point for the Signup feature.
/// This page handles user data input, real-time username validation,
/// and encryption passkey generation.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  /// Global key to manage and validate the Form state
  final _formKey = GlobalKey<FormState>();

  /// Controllers for input fields
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _passkeyController = TextEditingController();

  /// Logic for real-time username checking
  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  String? _usernameAvailabilityMessage;
  bool _usernameAvailable = false;
  User? _user;

  /// Wrapper for system database operations 
  /// to save the user and access to the methods
  final SystemDatabaseWrapper _systemDatabaseWrapper = SystemDatabaseWrapper();

  @override
  void initState() {
    super.initState();
    // Initialize the passkey with a random default value
    _passkeyController.text = _generateRandomPasskey(12);

    /* initialize the system database
    catching possible errors during initialization */
    _systemDatabaseWrapper.init().catchError((error){
      AppToast.show(context, "Errore durante l'inizializzazione del database: $error", ToastType.fatal);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passkeyController.dispose();
    super.dispose();

    _systemDatabaseWrapper.closeDatabase(); // dispose the database connection at the end
  }

  /// Generates a random alphanumeric string for the default passkey.
  String _generateRandomPasskey(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Simulates an asynchronous call to check if the username is taken.
  /// Uses a debounce logic to avoid excessive calls while typing.
  void _onUsernameChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    setState(() {
      _isCheckingUsername = true;
      _usernameAvailabilityMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (value.isEmpty) {
        setState(() {
          _isCheckingUsername = false;
          _usernameAvailable = false;
        });
        return;
      }

      /* control if the username is available
      for creating the new account */
      bool isAvailable = await _systemDatabaseWrapper.userValidity(value);
      
      setState(() {
        _isCheckingUsername = false;
        _usernameAvailable = isAvailable;
        _usernameAvailabilityMessage = _usernameAvailable 
            ? 'Username disponibile' 
            : 'Username già in uso';
      });
    });
  }

  /// Validates the form and processes Signup data.
  Future<bool> _submitSignup() async {
    // Calling validate() triggers error messages under required fields
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (!_usernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli un username disponibile prima di continuare.')),
      );
      return false;
    }

    /* create the user based on 
    the parameters given by the user */
    _user = User(_usernameController.text.trim(), _passwordController.text.trim(), _nameController.text.trim(), 
                          surname: _surnameController.text.trim());

    /* use backend logic to signup the user
    inside the database and adjust all the cryptography settings */
    Signup signup = Signup(_user!, _passkeyController.text.trim());
    try {
      await signup.execute();
      return true;
    } catch (error) {
      /* AppToast.show(context, "Errore durante la registrazione: $error", ToastType.fatal);
      return false; */
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea Account', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                // Limits the maximum width of the input fields box container
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Inserisci i tuoi dati per iniziare.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 32),

                      // --- USERNAME FIELD (Required + Real-time check) ---
                      _buildLabel('Username *'),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'Scegli il tuo username',
                          prefixIcon: const Icon(Icons.person, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2.0),
                          ),
                          suffixIcon: _isCheckingUsername 
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : _usernameAvailabilityMessage != null
                                  ? Icon(
                                      _usernameAvailable ? Icons.check_circle : Icons.error,
                                      color: _usernameAvailable ? Colors.green : Colors.red,
                                    )
                                  : null,
                        ),
                        onChanged: _onUsernameChanged,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
                          return null;
                        },
                      ),
                      if (_usernameAvailabilityMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            _usernameAvailabilityMessage!,
                            style: TextStyle(
                              fontSize: 12, 
                              color: _usernameAvailable ? Colors.green : Colors.red
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // --- NAME FIELD (Required) ---
                      _buildLabel('Nome *'),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Il tuo nome',
                          prefixIcon: const Icon(Icons.badge_outlined, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2.0),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Il valore deve essere impostato' : null,
                      ),
                      const SizedBox(height: 20),

                      // --- SURNAME FIELD (Optional) ---
                      _buildLabel('Cognome'),
                      TextFormField(
                        controller: _surnameController,
                        decoration: InputDecoration(
                          hintText: 'Il tuo cognome (opzionale)',
                          prefixIcon: const Icon(Icons.badge_outlined, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- PASSWORD FIELDS (Required + Confirmation check) ---
                      _buildLabel('Password *'),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password sicura',
                          prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2.0),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Il valore deve essere impostato' : null,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('Conferma Password *'),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Ripeti la password',
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2.0),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
                          if (value != _passwordController.text) return 'Le password non corrispondono';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- PASSKEY FIELD (Encryption key with constraints) ---
                      _buildLabel('Passkey di Crittografia'),
                      TextFormField(
                        controller: _passkeyController,
                        decoration: InputDecoration(
                          hintText: 'Chiave segreta per i dati',
                          helperText: 'Verrà usata per proteggere il database locale.',
                          prefixIcon: const Icon(Icons.key, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2.0),
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty && value.length < 10) {
                            return 'La passkey deve essere lunga almeno 10 caratteri';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),

                      // --- SUBMIT BUTTON ---
                      ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final success = await _submitSignup();
                          if (!success || !mounted) return;

                          await navigator.pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => GoogleConnectionPage(user: _user!),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('REGISTRATI', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(height: 12),

                      /* --- SIGNUP CANCELATION BUTTON --- */
                      OutlinedButton(
                        onPressed: () {
                          // Check if there is a route in the navigation stack to pop back to
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            // Fallback navigation to the Login page if pop is not possible
                            // Replace 'LoginPage()' with your actual login widget class name
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('ANNULLA', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to build consistent labels for the form fields
  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }
}

/// Custom InputDecoration theme to maintain the professional aesthetic
final customInputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFD1D1D1)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFD1D1D1)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFF008080), width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.red),
  ),
);