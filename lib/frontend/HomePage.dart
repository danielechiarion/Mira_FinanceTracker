import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // --- SEZIONE SUPERIORE: Logo in centro in alto ---
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/images/logo.png', // Assicurati che il percorso esista nel pubspec.yaml
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),

              // Spacer per spingere i pulsanti verso il basso
              const Spacer(),

              // --- SEZIONE INFERIORE: I due pulsanti ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Logica per la registrazione
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Registrazione'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Logica per la gestione dell'elenco account
                  },
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Gestisci Account'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}