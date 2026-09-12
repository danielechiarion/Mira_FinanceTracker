import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/single_elements/EntityListSection.dart';

/// Generic list-management page: search, add, edit and delete entries of
/// type [T]. Used as the common structure for pages that manage a registry
/// of reusable entities (e.g. contacts for operations, financial
/// institutes), so they share the same behaviour and graphics.
///
/// The toolbar/list/tile logic itself lives in EntityListSection, which is
/// also reused - without the surrounding Scaffold - by pages that need to
/// embed an entity list inside a bigger page, such as the "movimenti
/// comuni" section of AccountTypePage.
class EntityManagementPage<T> extends StatelessWidget {
  final String title;
  final String searchHint;
  final String addLabel;
  final IconData icon;
  final Color color;
  final Future<List<T>> Function() loadItems;
  final bool Function(T item, String query) matchesQuery;
  final String Function(T item) titleOf;
  final String Function(T item) subtitleOf;
  final WidgetBuilder buildAddPage;
  final Widget Function(BuildContext context, T item) buildEditPage;
  final Future<void> Function(T item) deleteItem;

  const EntityManagementPage({
    super.key,
    required this.title,
    required this.searchHint,
    required this.addLabel,
    required this.icon,
    required this.color,
    required this.loadItems,
    required this.matchesQuery,
    required this.titleOf,
    required this.subtitleOf,
    required this.buildAddPage,
    required this.buildEditPage,
    required this.deleteItem,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: EntityListSection<T>(
                searchHint: searchHint,
                addLabel: addLabel,
                icon: icon,
                color: color,
                loadItems: loadItems,
                matchesQuery: matchesQuery,
                titleOf: titleOf,
                subtitleOf: subtitleOf,
                buildAddPage: buildAddPage,
                buildEditPage: buildEditPage,
                deleteItem: deleteItem,
              ),
            ),
          ),
        ),
      ),
    );
  }
}