import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';

/// ACTION PAGES page from the functional analysis: entry point for
/// adding app entities (accounts, financial institutions, transactions,
/// financial instruments) and for viewing everything that has been added.
///
/// For now, it is a working stub (used only to wire up the navbar):
/// the cards/buttons for individual add actions will go here.
class ActionsPage extends StatelessWidget {
  const ActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: AppRoutes.actions,
      title: 'Aggiungi',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Sezione "Aggiungi" in costruzione:\nconti, istituti, operazioni, strumenti finanziari.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}