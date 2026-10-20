import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/error_pages/CloudErrorPage.dart';

/// Page shown when [CloudConnectionStatus.network_error] is returned:
/// the device is not connected to the internet.
class NetworkErrorPage extends StatelessWidget {
  /// Callback executed when the user presses the reload button
  final VoidCallback? onReload;

  /// Creates a [NetworkErrorPage] widget instance.
  const NetworkErrorPage({super.key, this.onReload});

  @override
  Widget build(BuildContext context) {
    return CloudErrorPage(
      icon: Icons.wifi_off_rounded,
      color: Colors.orange.shade800,
      title: 'Nessuna connessione',
      message: 'Non è possibile raggiungere il cloud. '
          'Controlla di essere connesso a internet e riprova.',
      onReload: onReload,
    );
  }
}