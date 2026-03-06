import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _lists = [];
  bool _loading = true;
  int? _selectedListId;
  Map<String, dynamic>? _selectedList;
  List<Map<String, dynamic>> _items = [];
  bool _loadingItems = false;

  final _listNameCtrl = TextEditingController();
  final _itemTitleCtrl = TextEditingController();
  final _itemQtyCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  @override
  void dispose() {
    _listNameCtrl.dispose();
    _itemTitleCtrl.dispose();
    _itemQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLists() async {
    setState(() => _loading = true);
    try {
      final res = await _api.dio.get('/shopping/my-lists');
      setState(() {
        _lists = List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _loading = false;
      });
      if (_selectedListId != null) {
        _loadItems(_selectedListId!);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadItems(int listId) async {
    setState(() => _loadingItems = true);
    try {
      final res = await _api.dio.get('/shopping/lists/$listId/items');
      final list = _lists.firstWhere((l) => l['id'] == listId);
      setState(() {
        _selectedList = list;
        _selectedListId = listId;
        _items = List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _loadingItems = false;
      });
    } catch (_) {
      setState(() => _loadingItems = false);
    }
  }

  Future<void> _createList() async {
    if (_listNameCtrl.text.trim().isEmpty) return;
    try {
      await _api.dio.post('/shopping/lists', data: {
        'name': _listNameCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
      _listNameCtrl.clear();
      _fetchLists();
    } catch (_) {}
  }

  Future<void> _addItem() async {
    if (_itemTitleCtrl.text.trim().isEmpty || _selectedListId == null) return;
    try {
      await _api.dio.post('/shopping/lists/$_selectedListId/items', data: {
        'title': _itemTitleCtrl.text.trim(),
        'quantity': _itemQtyCtrl.text.trim().isEmpty ? 1 : int.tryParse(_itemQtyCtrl.text) ?? 1,
      });
      _itemTitleCtrl.clear();
      _itemQtyCtrl.text = '1';
      _loadItems(_selectedListId!);
    } catch (_) {}
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    try {
      await _api.dio.patch('/shopping/items/${item['id']}/toggle');
      _loadItems(_selectedListId!);
    } catch (_) {}
  }

  Future<void> _deleteItem(int itemId) async {
    try {
      await _api.dio.delete('/shopping/items/$itemId');
      _loadItems(_selectedListId!);
    } catch (_) {}
  }

  void _showCreateListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nouvelle liste',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _listNameCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Nom de la liste'),
                onSubmitted: (_) => _createList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createList,
                child: const Text('Créer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedListId != null && _selectedList != null) {
      return _ListDetailView(
        list: _selectedList!,
        items: _items,
        loading: _loadingItems,
        itemTitleCtrl: _itemTitleCtrl,
        itemQtyCtrl: _itemQtyCtrl,
        onBack: () => setState(() {
          _selectedListId = null;
          _selectedList = null;
          _items = [];
        }),
        onAddItem: _addItem,
        onToggleItem: _toggleItem,
        onDeleteItem: _deleteItem,
        onRefresh: () => _loadItems(_selectedListId!),
      );
    }

    return Scaffold(
      backgroundColor: C.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Courses',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: C.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: C.primary),
                    )
                  : _lists.isEmpty
                      ? _EmptyLists(onAdd: _showCreateListSheet)
                      : RefreshIndicator(
                          onRefresh: _fetchLists,
                          color: C.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _lists.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final list = _lists[i];
                              final totalItems = list['item_count'] ?? 0;
                              final checkedItems = list['checked_count'] ?? 0;
                              final progress = totalItems > 0
                                  ? checkedItems / totalItems
                                  : 0.0;
                              return ListTile(
                                onTap: () => _loadItems(list['id']),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: C.primaryLight,
                                    borderRadius:
                                        BorderRadius.circular(C.radiusBase),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: C.primary,
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  list['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: C.textPrimary,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (list['family_name'] != null)
                                      Text(
                                        list['family_name'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: C.textSecondary,
                                        ),
                                      ),
                                    if (totalItems > 0) ...[
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: progress.toDouble(),
                                        backgroundColor: C.borderLight,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          C.primary,
                                        ),
                                        minHeight: 3,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$checkedItems/$totalItems',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: C.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: C.textTertiary,
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateListSheet,
        backgroundColor: C.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nouvelle liste',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ListDetailView extends StatelessWidget {
  final Map<String, dynamic> list;
  final List<Map<String, dynamic>> items;
  final bool loading;
  final TextEditingController itemTitleCtrl;
  final TextEditingController itemQtyCtrl;
  final VoidCallback onBack;
  final VoidCallback onAddItem;
  final ValueChanged<Map<String, dynamic>> onToggleItem;
  final ValueChanged<int> onDeleteItem;
  final VoidCallback onRefresh;
  const _ListDetailView({
    required this.list,
    required this.items,
    required this.loading,
    required this.itemTitleCtrl,
    required this.itemQtyCtrl,
    required this.onBack,
    required this.onAddItem,
    required this.onToggleItem,
    required this.onDeleteItem,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final pending = items.where((i) => !(i['is_checked'] ?? false)).toList();
    final checked = items.where((i) => i['is_checked'] ?? false).toList();
    final progress = items.isNotEmpty
        ? checked.length / items.length
        : 0.0;

    return Scaffold(
      backgroundColor: C.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              list['name'] ?? '',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (list['family_name'] != null)
              Text(
                list['family_name'],
                style: const TextStyle(fontSize: 12, color: C.textSecondary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: C.borderLight,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(C.primary),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${checked.length}/${items.length} articles',
                    style: const TextStyle(
                      fontSize: 12,
                      color: C.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Add item input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: itemTitleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un article...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => onAddItem(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: itemQtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'Qté',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onAddItem,
                  icon: const Icon(Icons.add_circle, color: C.primary, size: 28),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items list
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: C.primary),
                  )
                : RefreshIndicator(
                    onRefresh: () async => onRefresh(),
                    color: C.primary,
                    child: ListView(
                      children: [
                        // Pending items
                        ...pending.map(
                          (item) => _ShoppingItem(
                            item: item,
                            onToggle: () => onToggleItem(item),
                            onDelete: () => onDeleteItem(item['id']),
                          ),
                        ),
                        // Checked items
                        if (checked.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'DANS LE PANIER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: C.textTertiary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          ...checked.map(
                            (item) => _ShoppingItem(
                              item: item,
                              onToggle: () => onToggleItem(item),
                              onDelete: () => onDeleteItem(item['id']),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _ShoppingItem({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isChecked = item['is_checked'] ?? false;
    return Dismissible(
      key: Key('item_${item['id']}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: C.destructive,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isChecked ? C.green : Colors.transparent,
              border: Border.all(
                color: isChecked ? C.green : C.border,
                width: 2,
              ),
            ),
            child: isChecked
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        ),
        title: Text(
          item['title'] ?? '',
          style: TextStyle(
            fontSize: 15,
            color: isChecked ? C.textTertiary : C.textPrimary,
            decoration: isChecked ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: item['quantity'] != null && item['quantity'] != 1
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: C.surfaceAlt,
                  borderRadius: BorderRadius.circular(C.radiusFull),
                ),
                child: Text(
                  'x${item['quantity']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: C.textSecondary,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _EmptyLists extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLists({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: C.primaryLight,
                borderRadius: BorderRadius.circular(C.radius2xl),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: C.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucune liste',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: C.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Créez votre première liste de courses.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: C.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
