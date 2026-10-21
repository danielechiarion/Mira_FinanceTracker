import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/error_pages/CloudErrorPage.dart';

/// Page shown when an error occurs while writing data on the cloud.
/// It also shows the text of the exception that has been caught.
class CloudWritingErrorPage extends StatelessWidget {
  /// Text of the exception raised during the writing
  final String errorText;

  /// Callback executed when the user presses the reload button
  final VoidCallback onReload;

  /// Creates a [CloudWritingErrorPage] widget instance.
  const CloudWritingErrorPage({
    super.key,
    required this.errorText,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return CloudErrorPage(
      icon: Icons.cloud_upload_rounded,
      color: Colors.pink.shade700,
      title: 'Errore di scrittura',
      message: 'Si è verificato un errore durante il salvataggio dei dati '
          'sul cloud. Ricarica l\'applicazione per riprovare.\n\n'
          'Dettaglio: $errorText',
      onReload: onReload,
    );
  }
}