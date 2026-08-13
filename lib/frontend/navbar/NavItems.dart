import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';

/// A single navigation item, used by the desktop bar,
/// the tablet drawer, and the mobile bottom bar.
class NavItem {
  final String route;
  final IconData icon;
  final String label;

  const NavItem({required this.route, required this.icon, required this.label});
}

/// The 4 main pages identified in the functional analysis
/// (REVIEW, CUSTOM CHECK, ACTION PAGES, SETTINGS). Subpages intentionally
/// do not appear here.
const List<NavItem> kAppNavItems = [
  NavItem(route: AppRoutes.home, icon: Icons.pie_chart_rounded, label: 'Riepilogo'),
  NavItem(route: AppRoutes.check, icon: Icons.fact_check_outlined, label: 'Verifica conti'),
  NavItem(route: AppRoutes.actions, icon: Icons.add_circle_outline, label: 'Aggiungi'),
  NavItem(route: AppRoutes.settings, icon: Icons.settings_outlined, label: 'Impostazioni'),
];