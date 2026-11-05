import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mira_finance_tracker/backend/operation/account/SuperAccountManager.dart';
import 'package:mira_finance_tracker/backend/service/security/LocalAuthSupport.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UserCardManager.dart';

/// Page dedicated to advanced account management: lists every user
/// registered inside the local database, and lets the operator change
/// a password or delete an account.
///
/// Access to the whole page content is protected by the device unlock
/// (biometrics or PIN/pattern/password): nothing is shown until the
/// authentication succeeds.
class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  late final SuperAccountManager _manager;
  late final Future<void> _initFuture;

  bool _unlocked = false;
  bool _authInProgress = true;
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();

    /* prepare the account manager and start loading the user list
    right away, in parallel with the unlock request */
    _manager = SuperAccountManager();
    _initFuture = _manager.init();

    _authenticate();
  }

  @override
  void dispose() {
    _manager.disconnect();
    _manager.dispose();
    super.dispose();
  }

  /// Requests the device unlock (biometrics with fallback to
  /// PIN/pattern/password) and gates the page content on the result.
  Future<void> _authenticate() async {
    setState(() {
      _authInProgress = true;
      _authFailed = false;
    });

    final bool authenticated = await LocalAuthSupport.authenticate(
      'Sblocca per accedere alla gestione degli account',
    );

    if (!mounted) return;
    setState(() {
      _authInProgress = false;
      _unlocked = authenticated;
      _authFailed = !authenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Account', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _unlocked ? _buildContent() : _buildLockedView(),
      ),
    );
  }

  /// View shown while the device unlock hasn't succeeded yet: no
  /// account data is built or displayed behind this screen.
  Widget _buildLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 72, color: Colors.teal.shade300),
            const SizedBox(height: 24),
            const Text(
              'Area protetta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _authFailed
                  ? 'Sblocco non riuscito. Riprova per continuare.'
                  : 'Sblocca il dispositivo per accedere alla gestione degli account.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_authInProgress)
              const CircularProgressIndicator(color: Colors.teal)
            else ...[
              ElevatedButton(
                onPressed: _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Sblocca', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                child: const Text('Torna indietro'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Actual page content: the always up-to-date list of registered
  /// users, rebuilt automatically whenever the account manager
  /// notifies a change (e.g. after a deletion).
  Widget _buildContent() {
    return ChangeNotifierProvider<SuperAccountManager>.value(
      value: _manager,
      child: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Errore durante il caricamento degli account.',
                style: TextStyle(color: Colors.red.shade700),
              ),
            );
          }

          return Consumer<SuperAccountManager>(
            builder: (context, manager, _) {
              final users = manager.users;

              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Nessun account registrato.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) => UserCardManager(user: users[index]),
              );
            },
          );
        },
      ),
    );
  }
}