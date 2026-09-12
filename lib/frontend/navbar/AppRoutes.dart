/// Names of the main app routes (top-level pages only,
/// as requested: REVIEW, CUSTOM CHECK, ACTION PAGES, SETTINGS).
/// Detail subpages do not have an entry here: they are reached
/// by navigating within their respective main pages.
class AppRoutes {
  AppRoutes._();

  static const String home = '/home';       // REVIEW
  static const String check = '/check';     // CUSTOM CHECK
  static const String actions = '/actions'; // ACTION PAGES
  static const String settings = '/settings';

  /* routes for pages not included
  inside the main menu */
  static const String currentAccounts = '/current-accounts';
}