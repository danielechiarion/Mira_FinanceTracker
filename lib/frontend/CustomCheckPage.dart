import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';

/// CUSTOM CHECK page from the functional analysis: it will allow checking
/// the status of selected accounts within a specific date range.
///
/// For now, it is a working stub (used only to wire up the navbar):
/// the account selector, date range picker, and related filtered
/// charts/summaries will go here.
class CustomCheckPage extends StatelessWidget {
  const CustomCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: AppRoutes.check,
      title: 'Verifica conti',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Sezione "Verifica conti" in costruzione.',
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