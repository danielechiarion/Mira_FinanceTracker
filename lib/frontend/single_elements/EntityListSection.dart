import 'package:flutter/material.dart';

/// Embeddable, list-style management widget for a set of entities of type
/// [T]: a search box, an "add" button, and a list of tiles with edit/delete
/// actions. This is the reusable core behind EntityManagementPage - which
/// wraps it in its own Scaffold/AppBar for full-page use - and can also be
/// embedded directly inside another page's section (e.g. the "movimenti
/// comuni" section of AccountTypePage).
class EntityListSection<T> extends StatefulWidget {
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
  final Future<void> Function(T item)? addItem;
  final Future<void> Function(T item)? updateItem;

  const EntityListSection({
    super.key,
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
    this.addItem,
    this.updateItem
  });

  @override
  State<EntityListSection<T>> createState() => _EntityListSectionState<T>();
}

class _EntityListSectionState<T> extends State<EntityListSection<T>> {
  late Future<List<T>> _itemsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.loadItems();
  }

  Future<void> _reload() async {
    final future = widget.loadItems();
    if (!mounted) return;
    setState(() {
      _itemsFuture = future;
    });
    await future;
  }

  Future<void> _openAddPage() async {
    T item = await Navigator.push(context, MaterialPageRoute(builder: widget.buildAddPage));
    await widget.addItem!(item);
    await _reload();
  }

  Future<void> _openEditPage(T item) async {
    T newItem = await Navigator.push(context, MaterialPageRoute(builder: (context) => widget.buildEditPage(context, item)));
    await widget.updateItem!(newItem);
    await _reload();
  }

  Future<void> _confirmDelete(T item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Conferma eliminazione', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Vuoi eliminare "${widget.titleOf(item)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ANNULLA', style: TextStyle(color: Colors.teal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // this is where the delete function of the specific entity is called
      await widget.deleteItem(item);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(),
        const SizedBox(height: 24),
        _buildList(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _openAddPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          icon: const Icon(Icons.add),
          label: Text(widget.addLabel),
        ),
      ],
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<T>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }
        if (snapshot.hasError) {
          return Text('Errore nel caricamento: ${snapshot.error}');
        }

        final items = snapshot.data!.where((item) => widget.matchesQuery(item, _query)).toList();
        if (items.isEmpty) {
          return const Text('Nessun elemento trovato');
        }

        return Column(children: items.map(_buildTile).toList());
      },
    );
  }

  Widget _buildTile(T item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: widget.color.withOpacity(0.12),
        child: Icon(widget.icon, color: widget.color, size: 18),
      ),
      title: Text(widget.titleOf(item), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(widget.subtitleOf(item)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.teal),
            onPressed: () => _openEditPage(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(item),
          ),
        ],
      ),
    );
  }
}