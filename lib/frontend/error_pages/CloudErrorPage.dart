import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';

/// Base page used to show a static cloud connection error.
/// It only shows the app logo, an error icon, the error text
/// and a button to reload the application. The user cannot
/// navigate back or reach any other part of the app from here.
class CloudErrorPage extends StatelessWidget {
  /// Icon representing the error
  final IconData icon;

  /// Main color of the icon
  final Color color;

  /// Short title of the error
  final String title;

  /// Description of the error
  final String message;

  /// Callback executed when the user presses the reload button
  final VoidCallback? onReload;

  /// Creates a [CloudErrorPage] widget instance.
  const CloudErrorPage({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    // PopScope blocks the back button: no other page can be reached
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Image.asset(
              'assets/logos/extended_logo.png',
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withOpacity(0.12),
                          ),
                          child: Icon(icon, size: 72, color: color),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: onReload ?? () {
                          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false); // it's not possible to come back
                        },
                        icon: const Icon(Icons.refresh),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        label: const Text(
                          'Ricarica applicazione',
                          style: TextStyle(fontSize: 18),
                        ),
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
}