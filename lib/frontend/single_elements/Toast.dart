import 'package:flutter/material.dart';

/// Enumerator to define the different type
/// of toasts to appear in the application
enum ToastType{
  /* define different values of the enumerator */
  success(Colors.green, Icons.check),
  error(Colors.red, Icons.close),
  warning(Colors.amber, Icons.warning),
  fatal(Colors.purple, Icons.error);

  /* define the variables for the enumerator */
  final Color color;
  final IconData icon;

  /* define constructor for the enumerator */
  const ToastType(this.color, this.icon);
}

/// Class to manage the app toast display
class AppToast{
  /* define attributes */
  final BuildContext context;
  final String message;
  final ToastType toastType;

  AppToast.show(this.context, this.message, this.toastType){
    /* get the scaffold messenger and remove 
    previous toast put in the page, if they exists */
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.removeCurrentSnackBar();

    /* show the snackbar */
    scaffoldMessenger.showSnackBar(
      SnackBar(
        backgroundColor: toastType.color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              toastType.icon,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}