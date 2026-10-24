import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/error_pages/CloudErrorPage.dart';

/// Page shown when an error occurs while reading data from the cloud.
/// It also shows the text of the exception that has been caught.
class CloudReadingErrorPage extends StatelessWidget {
  /// Text of the exception raised during the reading
  final String errorText;

  /// Callback executed when the user presses the reload button
  final VoidCallback? onReload;

  /// Creates a [CloudReadingErrorPage] widget instance.
  const CloudReadingErrorPage({
    super.key,
    required this.errorText,
    this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return CloudErrorPage(
      icon: Icons.cloud_download_rounded,
      color: Colors.deepOrange.shade700,
      title: 'Errore di lettura',
      message: 'Si è verificato un errore durante la lettura dei dati '
          'dal cloud. Ricarica l\'applicazione per riprovare.\n\n'
          'Dettaglio: $errorText',
      onReload: onReload,
    );
  }
}