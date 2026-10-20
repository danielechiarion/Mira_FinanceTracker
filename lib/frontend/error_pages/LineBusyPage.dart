import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/error_pages/CloudErrorPage.dart';

/// Page shown when [CloudConnectionStatus.line_busy] is returned:
/// another device is using the application with the same cloud.
class LineBusyPage extends StatelessWidget {
  /// Callback executed when the user presses the reload button
  final VoidCallback? onReload;

  /// Creates a [LineBusyPage] widget instance.
  const LineBusyPage({super.key, this.onReload});

  @override
  Widget build(BuildContext context) {
    return CloudErrorPage(
      icon: Icons.devices_other_rounded,
      color: Colors.indigo,
      title: 'Linea occupata',
      message: 'L\'applicazione è in uso su un altro dispositivo '
          'collegato allo stesso cloud. Chiudila sull\'altro dispositivo '
          'e riprova.',
      onReload: onReload,
    );
  }
}