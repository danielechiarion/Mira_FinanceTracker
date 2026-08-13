import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/navbar/NavItems.dart';

/// Shared scaffold for all top-level pages of the app
/// (Home/Review, Custom Check, Add, Settings).
///
/// Based on the available width, it displays navigation in 3 ways:
/// - >= 1024px (desktop): full top bar with all links.
/// - 600-1024px (tablet): vertical sidebar (Drawer) opened via hamburger menu.
/// - < 600px (mobile): full bottom navigation bar (all items visible).
///
/// Each page uses it like this:
/// ```dart
/// return ResponsiveScaffold(
///   currentRoute: AppRoutes.home,
///   title: 'Summary',
///   body: ... ,
/// );
/// ```
class ResponsiveScaffold extends StatelessWidget {
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1024;

  /// route of the current page, to 
  /// understand which one is active
  final String currentRoute;

  /// title shown in the app bar 
  /// as a fallback for desktop (where the title is not shown)
  final String title;

  /// content of the page
  final Widget body;

  /// optional actions to show in the app bar
  /// (extra actions like a profile button, etc.)
  final List<Widget>? actions;

  final Widget? floatingActionButton;

  const ResponsiveScaffold({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  void _navigate(BuildContext context, String route) {
    if (route == currentRoute) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  int get _selectedIndex => kAppNavItems.indexWhere((item) => item.route == currentRoute);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= desktopBreakpoint) {
      return _buildDesktop(context);
    } else if (width >= tabletBreakpoint) {
      return _buildTablet(context);
    } else {
      return _buildMobile(context);
    }
  }

  // ------------------------------------------------------------------
  // COMPUTER: complete top bar
  // ------------------------------------------------------------------
  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          titleSpacing: 24,
          title: Row(
            children: [
              // same logo of the login, in a reduced version
              Image.asset(
                'assets/logos/extended_logo.png',
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.teal, size: 28),
                    SizedBox(width: 8),
                    Text('Mira Finance', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Row(
                  children: kAppNavItems.map((item) => _DesktopNavButton(
                    item: item,
                    selected: item.route == currentRoute,
                    onTap: () => _navigate(context, item.route),
                  )).toList(),
                ),
              ),
            ],
          ),
          actions: actions,
        ),
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }

  // ------------------------------------------------------------------
  // TABLET: vertical bar (Drawer) accessible by a hamburger
  // ------------------------------------------------------------------
  Widget _buildTablet(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        /* hamburger added automatically 
        because a 'drawer' has been used */
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: actions,
      ),
      drawer: Drawer(
        width: 260,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.teal, size: 26),
                    SizedBox(width: 10),
                    Text('Mira Finance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: kAppNavItems.map((item) {
                    final selected = item.route == currentRoute;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: ListTile(
                        leading: Icon(item.icon, color: selected ? Colors.teal : Colors.grey.shade600),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? Colors.teal : Colors.black87,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: selected,
                        selectedTileColor: Colors.teal.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onTap: () {
                          Navigator.of(context).pop(); // chiude il drawer
                          _navigate(context, item.route);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }

  // ------------------------------------------------------------------
  // PHONE: complete menu at the bottom
  // ------------------------------------------------------------------
  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: actions,
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex < 0 ? 0 : _selectedIndex,
        onDestinationSelected: (index) => _navigate(context, kAppNavItems[index].route),
        backgroundColor: Colors.white,
        indicatorColor: Colors.teal.withOpacity(0.15),
        destinations: kAppNavItems
            .map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
            .toList(),
      ),
    );
  }
}

class _DesktopNavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopNavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(item.icon, size: 20, color: selected ? Colors.teal : Colors.grey.shade600),
        label: Text(
          item.label,
          style: TextStyle(
            color: selected ? Colors.teal : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: selected ? Colors.teal.withOpacity(0.08) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}