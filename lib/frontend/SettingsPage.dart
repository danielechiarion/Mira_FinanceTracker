import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';

/// SETTINGS page from the functional analysis, featuring the 3 planned categories:
/// Account, Application, Cloud. The individual items are still stubs
/// (no logic connected): they serve to wire up the navbar and display
/// the page structure.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: AppRoutes.settings,
      title: 'Impostazioni',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _settingsGroup('Account', [
                  _settingsTile(Icons.person_outline, 'Username', 'Cambia il tuo username'),
                  _settingsTile(Icons.lock_outline, 'Password', 'Cambia la password di accesso'),
                ]),
                const SizedBox(height: 24),
                _settingsGroup('Applicazione', [
                  _settingsTile(Icons.sync, 'Attività in background', 'Calcolo automatico di entrate/uscite periodiche'),
                  _settingsTile(Icons.notifications_none, 'Notifiche', 'Promemoria su revisioni e pagamenti periodici'),
                  _settingsTile(Icons.history, 'Periodo di modifica', 'Intervallo di tempo modificabile e backup incrementali'),
                ]),
                const SizedBox(height: 24),
                _settingsGroup('Cloud', [
                  _settingsTile(Icons.cloud_outlined, 'Account Google', 'Collega o rimuovi la sincronizzazione cloud'),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsGroup(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }
}