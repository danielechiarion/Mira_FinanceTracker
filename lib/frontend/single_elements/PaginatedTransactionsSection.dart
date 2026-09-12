import 'package:flutter/material.dart';

/// Section listing an account's transactions, loaded one page at a time
/// (10 items by default) instead of all at once. [loadPage] should
/// ideally query the backend/database directly for that page (e.g. with a
/// LIMIT/OFFSET-style query) so the whole history is never held in memory
class PaginatedTransactionsSection<T> extends StatefulWidget {
  final Future<List<T>> Function(int page, int pageSize) loadPage;
  final Widget Function(T transaction) itemBuilder;
  final int pageSize;

  const PaginatedTransactionsSection({
    super.key,
    required this.loadPage,
    required this.itemBuilder,
    this.pageSize = 10,
  });

  @override
  State<PaginatedTransactionsSection<T>> createState() => _PaginatedTransactionsSectionState<T>();
}

class _PaginatedTransactionsSectionState<T> extends State<PaginatedTransactionsSection<T>> {
  final List<T> _items = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final nextItems = await widget.loadPage(_page, widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(nextItems);
        _page++;
        _hasMore = nextItems.length == widget.pageSize;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }
    if (_items.isEmpty && _error != null) {
      return Text('Errore nel caricamento dei movimenti: $_error');
    }
    if (_items.isEmpty) {
      return const Text('Nessun movimento registrato');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: _items.map(widget.itemBuilder).toList()),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Errore nel caricamento: $_error', style: const TextStyle(color: Colors.red)),
          ),
        if (_hasMore)
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.teal)
                : TextButton.icon(
                    onPressed: _loadNextPage,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Carica altri movimenti'),
                  ),
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Non ci sono altri movimenti', style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }
}