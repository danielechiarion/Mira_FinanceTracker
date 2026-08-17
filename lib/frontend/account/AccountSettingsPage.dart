import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/backend/operation/account/ProfileChanges.dart';
import 'package:mira_finance_tracker/backend/operation/account/Logout.dart';

import 'package:mira_finance_tracker/frontend/account/LoginPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

/// Account subpage reachable from the Settings page.
/// Shows the user logo, the username (read-only) and lets the user
/// update name, surname and password. A logout action is available
/// at the bottom of the page.
class AccountSettingsPage extends StatefulWidget {
  /// User whose data is being displayed/edited on this page.
  final User currentUser;

  const AccountSettingsPage({super.key, required this.currentUser});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  /// Global key to manage and validate the profile Form state
  final _formKey = GlobalKey<FormState>();

  /// Controllers for the editable profile fields.
  /// Name and surname are pre-filled with the current user data;
  /// remember that the name field is optional, so it might be empty.
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;

  /// Latest known version of the user, updated after a successful save.
  /// It is returned to the Settings page once the user goes back.
  /// Its "username" field is only displayed here, it is not editable from this page.
  late User _updatedUser;
  late ProfileChanges _profileOperations;

  @override
  void initState() {
    super.initState();
    _updatedUser = widget.currentUser;
    _nameController = TextEditingController(text: widget.currentUser.name);
    _surnameController = TextEditingController(text: widget.currentUser.surname);
    /* create profile operation
    and initialize it */
    _profileOperations = ProfileChanges(_updatedUser);
    _profileOperations.init();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
    _profileOperations.disconnect(); // disconnect profile operations resources
  }

  /// Validates and saves the changes made to name and surname.
  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    /* get name and surname and 
    save them into the state and the database */
    String name = _nameController.text.trim();
    String surname = _surnameController.text.trim().isEmpty ? '' : _surnameController.text.trim();
    await _profileOperations.changeUserNameSurname(name, surname);

    // Immediate visual update: reflect the new data on this page and
    // keep it ready to be returned to the Settings page
    setState(() {
      _updatedUser.name = name;
      _updatedUser.surname = surname;
    });

    AppToast.show(context, "Nome e cognome utente aggiornati con successo!", ToastType.success);
  }

  /// Opens a popup asking for the old password and the new one twice,
  /// making sure the two new-password inputs match before confirming.
  Future<void> _openChangePasswordDialog() async {
    final passwordFormKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cambia password', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: passwordFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- OLD PASSWORD FIELD ---
                TextFormField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password attuale',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.teal),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Il valore deve essere impostato' : null,
                ),
                const SizedBox(height: 16),

                // --- NEW PASSWORD FIELDS (double input + match check) ---
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nuova password',
                    prefixIcon: Icon(Icons.lock, color: Colors.teal),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Il valore deve essere impostato' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Conferma nuova password',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.teal),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
                    if (value != newPasswordController.text) return 'Le password non corrispondono';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ANNULLA', style: TextStyle(color: Colors.teal)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                if (!passwordFormKey.currentState!.validate()) return;

                bool result = await _profileOperations.changeUserPassword(oldPasswordController.text.trim(), newPasswordController.text.trim());

                Navigator.pop(dialogContext);
                if (!mounted) return;
                if(result == true){
                  AppToast.show(context, "Password aggiornata con successo", ToastType.success);
                }else{
                  AppToast.show(context, "Errore impostazioni password: vecchia password non valida", ToastType.error);
                }
              },
              child: const Text('CONFERMA'),
            ),
          ],
        );
      },
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  /// Executes the logout operations and brings the user back to the login page.
  Future<void> _logout() async {
    /* create a logout instance
    for the user and execute it */
    Logout logoutProcedure = Logout(_updatedUser);
    await logoutProcedure.execute();

    if (!mounted) return;

    // Clear the whole navigation stack so the user cannot go "back" into the app
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- USER LOGO ---
                      const CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.person, size: 48, color: Colors.white),
                        // TODO: replace with the actual user profile picture once available
                      ),
                      const SizedBox(height: 16),

                      // --- USERNAME (read-only) ---
                      Text(
                        _updatedUser.username,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),

                      // --- NAME FIELD (optional) ---
                      _buildLabel('Nome'),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Il tuo nome (opzionale)',
                          prefixIcon: const Icon(Icons.badge_outlined, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- SURNAME FIELD (optional) ---
                      _buildLabel('Cognome'),
                      TextFormField(
                        controller: _surnameController,
                        decoration: InputDecoration(
                          hintText: 'Il tuo cognome (opzionale)',
                          prefixIcon: const Icon(Icons.badge_outlined, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300, width: 1.5),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- SAVE PROFILE CHANGES ---
                      ElevatedButton(
                        onPressed: _saveProfileChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('SALVA MODIFICHE', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),

                      // --- CHANGE PASSWORD (opens popup) ---
                      OutlinedButton.icon(
                        onPressed: _openChangePasswordDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('CAMBIA PASSWORD', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 32),

                      const Divider(),
                      const SizedBox(height: 12),

                      /* --- BACK BUTTON, available once the operations above are completed --- */
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, _updatedUser),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Color(0xFFD1D1D1), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('TORNA INDIETRO', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),

                      // --- LOGOUT ---
                      OutlinedButton.icon(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('LOGOUT', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to build consistent labels for the form fields
  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }
}