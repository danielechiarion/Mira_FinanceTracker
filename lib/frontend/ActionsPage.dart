import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';

/// ACTION PAGES from the functional analysis: entry point to add bank
/// accounts, financial institutes, operations and financial instruments,
/// grouped by category and displayed as a two-column grid on wide screens.
class ActionsPage extends StatelessWidget {
  const ActionsPage({super.key});

  // Placeholder category/action list: replace with the real one.
  static final List<_ActionCategory> _categories = [
    _ActionCategory(
      title: 'Conti e istituti',
      color: Colors.teal,
      actions: [
        _ActionItem(
          label: 'Nuovo conto corrente',
          icon: Icons.account_balance,
          pageBuilder: (context) => ActionOperationPage(
            title: 'Nuovo conto corrente',
            inputBuilder: (context) => const TextField(
              decoration: InputDecoration(labelText: 'Nome conto'),
            ),
            onConfirm: (context) async {
              // TODO: call the save/processing function for this action
              Navigator.pop(context);
            },
          ),
        ),
        _ActionItem(
          label: 'Nuovo istituto finanziario',
          icon: Icons.business,
          pageBuilder: (context) => ActionOperationPage(
            title: 'Nuovo istituto finanziario',
            inputBuilder: (context) => const TextField(
              decoration: InputDecoration(labelText: 'Nome istituto'),
            ),
            onConfirm: (context) async {
              // TODO: call the save/processing function for this action
              Navigator.pop(context);
            },
          ),
        ),
      ],
    ),
    _ActionCategory(
      title: 'Movimenti',
      color: Colors.indigo,
      actions: [
        _ActionItem(
          label: 'Nuova entrata',
          icon: Icons.arrow_downward,
          pageBuilder: (context) => ActionOperationPage(
            title: 'Nuova entrata',
            inputBuilder: (context) => const TextField(
              decoration: InputDecoration(labelText: 'Importo'),
            ),
            onConfirm: (context) async {
              // TODO: call the save/processing function for this action
              Navigator.pop(context);
            },
          ),
        ),
        _ActionItem(
          label: 'Nuova uscita',
          icon: Icons.arrow_upward,
          pageBuilder: (context) => ActionOperationPage(
            title: 'Nuova uscita',
            inputBuilder: (context) => const TextField(
              decoration: InputDecoration(labelText: 'Importo'),
            ),
            onConfirm: (context) async {
              // TODO: call the save/processing function for this action
              Navigator.pop(context);
            },
          ),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: AppRoutes.actions,
      title: 'Azioni',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category in _categories) ...[
                      _sectionCard(category.title, _buildActionGrid(context, category, isWide)),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, _ActionCategory category, bool isWide) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: category.actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 2 : 1,
        mainAxisSpacing: 8,
        crossAxisSpacing: 16,
        mainAxisExtent: 64,
      ),
      itemBuilder: (context, index) => _buildActionTile(context, category, category.actions[index]),
    );
  }

  Widget _buildActionTile(BuildContext context, _ActionCategory category, _ActionItem action) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: action.pageBuilder)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: CircleAvatar(
          backgroundColor: category.color.withOpacity(0.12),
          child: Icon(action.icon, color: category.color, size: 18),
        ),
        title: Text(action.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ActionCategory {
  final String title;
  final Color color;
  final List<_ActionItem> actions;

  const _ActionCategory({required this.title, required this.color, required this.actions});
}

class _ActionItem {
  final String label;
  final IconData icon;
  final WidgetBuilder pageBuilder;

  const _ActionItem({required this.label, required this.icon, required this.pageBuilder});
}