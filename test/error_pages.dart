import 'package:flutter/material.dart';
import 'package:mira_finance_tracker/frontend/error_pages/AuthenticationFailedPage.dart';
import 'package:mira_finance_tracker/frontend/error_pages/CloudReadingErrorPage.dart';
import 'package:mira_finance_tracker/frontend/error_pages/CloudWritingErrorPage.dart';
import 'package:mira_finance_tracker/frontend/error_pages/LineBusyPage.dart';
import 'package:mira_finance_tracker/frontend/error_pages/NetworkErrorPage.dart';

void main(List<String> args) {
  if (args.length != 1) {
    throw ArgumentError(
      'Specifica una pagina: authentication, reading, writing, line-busy, network',
    );
  }

  runApp(ErrorPagesTestApp(pageName: args.single));
}

class ErrorPagesTestApp extends StatelessWidget {
  const ErrorPagesTestApp({super.key, required this.pageName});

  final String pageName;

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (pageName) {
      'authentication' => const AuthenticationFailedPage(onReload: _onReload),
      'reading' => const CloudReadingErrorPage(
          errorText: 'Errore di lettura di test',
          onReload: _onReload,
        ),
      'writing' => const CloudWritingErrorPage(
          errorText: 'Errore di scrittura di test',
          onReload: _onReload,
        ),
      'line-busy' => const LineBusyPage(onReload: _onReload),
      'network' => const NetworkErrorPage(onReload: _onReload),
      _ => throw ArgumentError.value(pageName, 'pageName', 'Pagina non valida'),
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: page,
    );
  }
}

void _onReload() {}