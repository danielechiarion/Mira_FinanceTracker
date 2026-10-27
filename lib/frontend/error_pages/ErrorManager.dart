import 'package:flutter/material.dart';
import 'package:mira_finance_tracker/globals.dart';

import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnection.dart';

import 'package:mira_finance_tracker/frontend/error_pages/AuthenticationFailedPage.dart';
import 'package:mira_finance_tracker/frontend/error_pages/CloudReadingErrorPage.dart';
import 'package:mira_finance_tracker/frontend/error_pages/CloudWritingErrorPage.dart';
import 'package:mira_finance_tracker/frontend/error_pages/LineBusyPage.dart';
import 'package:mira_finance_tracker/frontend/error_pages/NetworkErrorPage.dart';

/// Function to manage errors during operations
/// provided. The main purporse is to redirect errors
/// to other pages.
class ErrorManager {
  /* function to reload the home page to
  another one in case of error,
  especially during background operations */
  static Future<void> redirectToErrorPageImport(dynamic error) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) {
            if(error is CloudConnectionStatus) {
              switch(error){
                case CloudConnectionStatus.authentication_failed:
                  return AuthenticationFailedPage();
                case CloudConnectionStatus.line_busy:
                  return LineBusyPage();
                default:
                  return NetworkErrorPage();
              }
            }else{
              return CloudReadingErrorPage(errorText: error.toString());
            }
          }
        ),
      );
    });
  }

  /* function to redirect error during export */
  static Future<void> redirectToErrorPageExport(dynamic error) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) {
            return CloudWritingErrorPage(errorText: error.toString());
          },
        ),
      );
    });
  }
}
