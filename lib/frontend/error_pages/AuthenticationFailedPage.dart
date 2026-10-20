import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/error_pages/CloudErrorPage.dart';

/// Page shown when [CloudConnectionStatus.authentication_failed] is returned:
/// the authentication has not been restored correctly from the database.
class AuthenticationFailedPage extends StatelessWidget {
  /// Callback executed when the user presses the reload button
  final VoidCallback? onReload;

  /// Creates an [AuthenticationFailedPage] widget instance.
  const AuthenticationFailedPage({super.key, this.onReload});

  @override
  Widget build(BuildContext context) {
    return CloudErrorPage(
      icon: Icons.gpp_bad_rounded,
      color: Colors.red.shade700,
      title: 'Autenticazione non riuscita',
      message: 'Non è stato possibile ripristinare l\'autenticazione '
          'del tuo account. Ricarica l\'applicazione per riprovare.',
      onReload: onReload,
    );
  }
}