import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mira_finance_tracker/backend/operation/account/SuperAccountManager.dart';
import 'package:mira_finance_tracker/backend/service/security/LocalAuthSupport.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

/// Card widget representing a single user account registered
/// inside the local database, with the actions to change its
/// password or delete it entirely.
///
/// Both actions are considered sensitive: after the user confirms
/// them inside their respective popup, the device unlock (biometrics
/// or PIN/pattern/password) is requested again before the operation
/// is actually applied to the database.
class UserCardManager extends StatelessWidget {
  final User user;

  const UserCardManager({super.key, required this.user});

  /// Requests the device unlock (biometrics with fallback to
  /// PIN/pattern/password) and returns whether it succeeded.
  Future<bool> _confirmUnlock(String reason) async {
    return await LocalAuthSupport.authenticate(reason);
  }
 
  /// Opens the popup to set a new password for [user], validates
  /// that the two fields match, then re-confirms the unlock before
  /// actually saving the new password.
  Future<void> _handleChangePassword(BuildContext context) async {
    final String? newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _ChangePasswordDialog(),
    );
 
    if (newPassword == null) return;
    if (!context.mounted) return;
 
    final bool unlocked = await _confirmUnlock('Conferma la tua identità per cambiare la password');
    if (!context.mounted) return;
    if (!unlocked) {
      AppToast.show(context, 'Sblocco non riuscito. Operazione annullata.', ToastType.error);
      return;
    }
 
    try {
      await context.read<SuperAccountManager>().changePassword(user, newPassword);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password aggiornata con successo.')),
        );
      }
    } catch (e, stackTrace) {
      // TEMPORARY debug logging: check the console for the real cause,
      // then this can be removed once the issue is fixed.
      debugPrint('Aggiornamento password fallito: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        AppToast.show(context, 'Errore durante l\'aggiornamento della password.', ToastType.error);
      }
    }
  }
 
  /// Opens the popup warning about the risk of deleting [user],
  /// then re-confirms the unlock before actually removing it.
  Future<void> _handleDelete(BuildContext context) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('Elimina Account', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Stai per eliminare definitivamente l\'account "${user.username}" e tutti i dati ad esso associati. '
              'Questa operazione non può essere annullata. Continuare?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;
 
    if (!confirmed) return;
    if (!context.mounted) return;
 
    final bool unlocked = await _confirmUnlock('Conferma la tua identità per eliminare l\'account');
    if (!context.mounted) return;
    if (!unlocked) {
      AppToast.show(context, 'Sblocco non riuscito. Operazione annullata.', ToastType.error);
      return;
    }
 
    try {
      await context.read<SuperAccountManager>().removeUser(user);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account eliminato con successo.')),
        );
      }
    } catch (e, stackTrace) {
      // TEMPORARY debug logging: check the console for the real cause,
      // then this can be removed once the issue is fixed.
      debugPrint('Eliminazione account fallita: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        AppToast.show(context, 'Errore durante l\'eliminazione dell\'account.', ToastType.error);
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final bool hasSurname = user.surname.isNotEmpty;
    final String displayName = hasSurname ? '${user.name} ${user.surname}' : user.name;
 
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.teal.shade50,
              child: const Icon(Icons.account_circle, color: Colors.teal, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Modifica password',
              icon: const Icon(Icons.lock_reset, color: Colors.teal),
              onPressed: () => _handleChangePassword(context),
            ),
            IconButton(
              tooltip: 'Elimina account',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _handleDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}
 
/// Popup used to collect and validate the new password for an account.
/// Owning the [TextEditingController]s and the [GlobalKey] as part of
/// its own State (instead of managing them from outside, in the caller)
/// ensures Flutter disposes them at the correct point in the widget
/// lifecycle, i.e. only once the dialog's closing transition has
/// actually finished.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();
 
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}
 
class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
 
  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
 
  void _confirm() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _newPasswordController.text);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Modifica Password', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nuova Password',
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal, width: 2.0),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Conferma Password',
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal, width: 2.0),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
                  if (value != _newPasswordController.text) return 'Le password non corrispondono';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          onPressed: _confirm,
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}