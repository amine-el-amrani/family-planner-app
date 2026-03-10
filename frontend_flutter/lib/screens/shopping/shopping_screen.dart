import 'dart:async';
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
  List<Map<String, dynamic>> _families = [];
  bool _loading = true;
  int? _selectedListId;
  Map<String, dynamic>? _selectedList;
  List<Map<String, dynamic>> _items = [];
  bool _loadingItems = false;

  final _listNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLists();
    _fetchFamilies();
  }

  Future<void> _fetchFamilies() async {
    try {
      final res = await _api.dio.get('/families/');
      if (mounted) {
        setState(() {
          _families = List<Map<String, dynamic>>.from(
            (res.data as List).map((e) => Map<String, dynamic>.from(e)),
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _listNameCtrl.dispose();
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
    // Show the detail view immediately — no wait for API
    final list = _lists.firstWhere((l) => l['id'] == listId);
    setState(() {
      _selectedList = list;
      _selectedListId = listId;
      _loadingItems = true;
    });
    try {
      final res = await _api.dio.get('/shopping/lists/$listId/items');
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(
            (res.data as List).map((e) => Map<String, dynamic>.from(e)),
          );
          _loadingItems = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  Future<void> _createList(int? familyId) async {
    if (_listNameCtrl.text.trim().isEmpty || familyId == null) return;
    try {
      await _api.dio.post('/shopping/lists', data: {
        'name': _listNameCtrl.text.trim(),
        'family_id': familyId,
      });
      if (mounted) Navigator.pop(context);
      _listNameCtrl.clear();
      _fetchLists();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la création de la liste'),
          backgroundColor: C.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _addItem(String title, int qty, {String? imageUrl}) async {
    if (title.trim().isEmpty || _selectedListId == null) return;
    // Optimistic update — show item instantly before API confirms
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    setState(() => _items.insert(0, {
          'id': tempId,
          'title': title.trim(),
          'quantity': qty.toString(),
          'image_url': imageUrl,
          'is_checked': false,
        }));
    try {
      final res = await _api.dio.post('/shopping/lists/$_selectedListId/items', data: {
        'title': title.trim(),
        'quantity': qty.toString(),
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      });
      // Replace temp item with real server data (preserves real id)
      final newItem = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        final idx = _items.indexWhere((i) => i['id'] == tempId);
        if (idx != -1) _items[idx] = newItem;
      });
    } catch (e) {
      setState(() => _items.removeWhere((i) => i['id'] == tempId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de l\'ajout de l\'article'),
          backgroundColor: C.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    // Optimistic toggle — flip immediately, revert on error
    final idx = _items.indexWhere((i) => i['id'] == item['id']);
    if (idx != -1) {
      final toggled = Map<String, dynamic>.from(item);
      toggled['is_checked'] = !(item['is_checked'] ?? false);
      setState(() => _items[idx] = toggled);
    }
    try {
      final res = await _api.dio.patch('/shopping/items/${item['id']}/toggle');
      // Update item from server response (checked_by, checked_at, etc.)
      final updated = Map<String, dynamic>.from(res.data as Map);
      if (mounted) {
        setState(() {
          final i2 = _items.indexWhere((i) => i['id'] == item['id']);
          if (i2 != -1) _items[i2] = updated;
        });
      }
    } catch (_) {
      // Revert optimistic change on failure
      if (idx != -1 && mounted) setState(() => _items[idx] = item);
    }
  }

  Future<void> _deleteItem(int itemId) async {
    // Optimistic delete — remove instantly, revert on error
    final idx = _items.indexWhere((i) => i['id'] == itemId);
    final removed = idx != -1 ? Map<String, dynamic>.from(_items[idx]) : null;
    if (idx != -1) setState(() => _items.removeAt(idx));
    try {
      await _api.dio.delete('/shopping/items/$itemId');
    } catch (_) {
      // Revert on failure
      if (removed != null && mounted) setState(() => _items.insert(idx, removed));
    }
  }

  Future<void> _deleteList(int listId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la liste'),
        content: const Text('Supprimer cette liste et tous ses articles ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: C.destructive),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _api.dio.delete('/shopping/lists/$listId');
        setState(() {
          _lists.removeWhere((l) => l['id'] == listId);
          _selectedListId = null;
          _selectedList = null;
          _items = [];
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erreur lors de la suppression'),
            backgroundColor: C.destructive,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  void _showCreateListSheet() {
    int? selectedFamilyId =
        _families.isNotEmpty ? _families.first['id'] as int : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  decoration:
                      const InputDecoration(hintText: 'Nom de la liste'),
                  onSubmitted: (_) => _createList(selectedFamilyId),
                ),
                if (_families.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedFamilyId,
                    decoration: const InputDecoration(hintText: 'Famille'),
                    items: _families
                        .map((f) => DropdownMenuItem<int>(
                              value: f['id'] as int,
                              child: Text(f['name'] ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setSheetState(() => selectedFamilyId = v),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Vous devez rejoindre une famille pour créer une liste.',
                    style: TextStyle(color: C.textSecondary, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _families.isNotEmpty
                      ? () => _createList(selectedFamilyId)
                      : null,
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
        onBack: () => setState(() {
          _selectedListId = null;
          _selectedList = null;
          _items = [];
        }),
        onAddItem: _addItem,
        onToggleItem: _toggleItem,
        onDeleteItem: _deleteItem,
        onDeleteList: () => _deleteList(_selectedListId!),
        onRefresh: () => _loadItems(_selectedListId!),
      );
    }

    return Scaffold(
      backgroundColor: C.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
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
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _lists.length,
                            itemBuilder: (ctx, i) {
                              final list = _lists[i];
                              final totalItems = list['item_count'] ?? 0;
                              final checkedItems = list['checked_count'] ?? 0;
                              final progress = totalItems > 0
                                  ? checkedItems / totalItems
                                  : 0.0;
                              final isComplete = totalItems > 0 && checkedItems == totalItems;
                              return GestureDetector(
                                onTap: () => _loadItems(list['id']),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: C.surface,
                                    borderRadius: BorderRadius.circular(C.radiusLg),
                                    border: Border.all(color: C.borderLight),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: isComplete
                                              ? const Color(0xFFECFDF5)
                                              : C.primaryLight,
                                          borderRadius: BorderRadius.circular(C.radiusBase),
                                        ),
                                        child: Icon(
                                          isComplete
                                              ? Icons.check_circle
                                              : Icons.shopping_cart_outlined,
                                          color: isComplete
                                              ? const Color(0xFF059669)
                                              : C.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              list['name'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: C.textPrimary,
                                              ),
                                            ),
                                            if (list['family_name'] != null) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(Icons.group_outlined,
                                                      size: 11, color: C.textTertiary),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    list['family_name'],
                                                    style: const TextStyle(
                                                        fontSize: 12, color: C.textTertiary),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (totalItems > 0) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: LinearProgressIndicator(
                                                        value: progress.toDouble(),
                                                        backgroundColor: C.borderLight,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          isComplete
                                                              ? const Color(0xFF059669)
                                                              : C.primary,
                                                        ),
                                                        minHeight: 4,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '$checkedItems/$totalItems',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: C.textTertiary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else ...[
                                              const SizedBox(height: 2),
                                              const Text('Liste vide',
                                                  style: TextStyle(
                                                      fontSize: 12, color: C.textTertiary)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: C.textTertiary, size: 20),
                                    ],
                                  ),
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

// ─── Product picker sheet ──────────────────────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  final Future<void> Function(String title, int qty, {String? imageUrl}) onAdd;
  final ScrollController scrollController;
  const _ProductPickerSheet({required this.onAdd, required this.scrollController});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  // Common products shown when search is empty
  static const _commonProducts = [
    // ── Fruits ──
    ('🍎', 'Pommes'), ('🍊', 'Oranges'), ('🍋', 'Citrons'), ('🍌', 'Bananes'),
    ('🍇', 'Raisins'), ('🍓', 'Fraises'), ('🫐', 'Myrtilles'), ('🍒', 'Cerises'),
    ('🍑', 'Pêches'), ('🍐', 'Poires'), ('🥝', 'Kiwis'), ('🍍', 'Ananas'),
    ('🥭', 'Mangues'), ('🍉', 'Pastèque'), ('🍈', 'Melon'), ('🍑', 'Abricots'),
    ('🫒', 'Olives'), ('🍒', 'Framboises'),
    // ── Légumes ──
    ('🍅', 'Tomates'), ('🥕', 'Carottes'), ('🥦', 'Brocoli'), ('🥬', 'Salade'),
    ('🧅', 'Oignons'), ('🥔', 'Pommes de terre'), ('🫑', 'Poivrons'), ('🥒', 'Concombres'),
    ('🍆', 'Aubergines'), ('🥑', 'Avocats'), ('🌽', 'Maïs'), ('🧄', 'Ail'),
    ('🥜', 'Haricots verts'), ('🌿', 'Poireaux'), ('🍄', 'Champignons'),
    ('🥗', 'Épinards'), ('🌱', 'Courgettes'), ('🫛', 'Petits pois'),
    ('🥦', 'Chou-fleur'), ('🥬', 'Chou'), ('🫚', 'Betteraves'), ('🌾', 'Asperges'),
    ('🥗', 'Céleri'), ('🥦', 'Brocolis'),
    // ── Viandes & Poissons ──
    ('🍗', 'Poulet'), ('🥩', 'Bœuf haché'), ('🥓', 'Lardons'), ('🍖', 'Côtelettes'),
    ('🥩', 'Steak'), ('🌭', 'Jambon'), ('🐟', 'Saumon'), ('🐟', 'Thon'),
    ('🦐', 'Crevettes'), ('🐠', 'Poisson'), ('🥚', 'Œufs'),
    // ── Produits laitiers ──
    ('🥛', 'Lait'), ('🧀', 'Fromage'), ('🧈', 'Beurre'), ('🥛', 'Yaourts'),
    ('🍦', 'Crème fraîche'), ('🥛', 'Crème liquide'),
    // ── Boulangerie & Petit-déj ──
    ('🍞', 'Pain de mie'), ('🥖', 'Baguette'), ('🥐', 'Croissants'),
    ('🥣', 'Céréales'), ('🍯', 'Miel'), ('🍫', 'Chocolat à tartiner'),
    ('🫙', 'Confiture'),
    // ── Épicerie ──
    ('🍝', 'Pâtes'), ('🍚', 'Riz'), ('🌾', 'Farine'), ('🧂', 'Sel'),
    ('🍬', 'Sucre'), ('🫒', 'Huile d\'olive'), ('🍶', 'Vinaigre'),
    ('🥫', 'Conserves'), ('🍲', 'Bouillon'), ('🧴', 'Sauce tomate'),
    ('🥡', 'Moutarde'), ('🍅', 'Ketchup'),
    // ── Boissons ──
    ('☕', 'Café'), ('🍵', 'Thé'), ('🧃', 'Jus d\'orange'), ('💧', 'Eau'),
    ('🍺', 'Bière'), ('🍷', 'Vin'), ('🥤', 'Sodas'),
    // ── Surgelés & Snacks ──
    ('🍕', 'Pizza surgelée'), ('🍟', 'Frites surgelées'), ('🍫', 'Chocolat'),
    ('🍪', 'Biscuits'), ('🥨', 'Chips'),
    // ── Hygiène & Maison ──
    ('🧻', 'Papier WC'), ('🧴', 'Shampooing'), ('🪥', 'Dentifrice'),
    ('🧼', 'Savon'), ('🧺', 'Lessive'), ('🫧', 'Liquide vaisselle'),
    ('🧹', 'Éponges'),
  ];

  final _searchCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  final _api = ApiClient();
  int _qty = 1;
  String _query = '';
  String? _selected;
  String? _selectedImage;
  List<Map<String, dynamic>> _apiResults = [];
  bool _apiLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    setState(() => _query = q);
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() { _apiResults = []; _apiLoading = false; });
      return;
    }
    setState(() => _apiLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchProducts(q));
  }

  Future<void> _searchProducts(String query) async {
    try {
      final res = await _api.dio.get(
        '/shopping/search-products',
        queryParameters: {'q': query},
      );
      final products = (res.data as List? ?? [])
          .map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p))
          .toList();
      if (mounted) setState(() { _apiResults = products; _apiLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _apiResults = []; _apiLoading = false; });
    }
  }

  List<(String, String)> get _filteredCommon {
    if (_query.isEmpty) return _commonProducts;
    final q = _query.toLowerCase();
    return _commonProducts.where((p) => p.$2.toLowerCase().contains(q)).toList();
  }

  void _selectProduct(String name, {String? imageUrl}) {
    setState(() {
      _selected = name;
      _selectedImage = imageUrl;
      _customCtrl.clear();
    });
  }

  void _submit() {
    final title = _customCtrl.text.trim().isNotEmpty
        ? _customCtrl.text.trim()
        : _selected ?? '';
    if (title.isEmpty) return;
    final image = _customCtrl.text.trim().isNotEmpty ? null : _selectedImage;
    Navigator.of(context).pop();
    widget.onAdd(title, _qty, imageUrl: image);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: C.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ajouter un article',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.textPrimary),
              ),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un article...',
                prefixIcon: const Icon(Icons.search, color: C.textSecondary),
                isDense: true,
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          const SizedBox(height: 10),

          // Results area — Expanded so it fills available sheet space
          Expanded(
            child: _query.length >= 2
                // ── Search mode: common matches on top, then API results ──
                ? CustomScrollView(
                    controller: widget.scrollController,
                    slivers: [
                      // Section: common product suggestions
                      if (_filteredCommon.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Text(
                              'Suggestions',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.textSecondary),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final (emoji, name) = _filteredCommon[i];
                                final isSelected = _selected == name && _customCtrl.text.trim().isEmpty;
                                return GestureDetector(
                                  onTap: () => _selectProduct(name, imageUrl: 'emoji:$emoji'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      color: isSelected ? C.primaryLight : C.surfaceAlt,
                                      borderRadius: BorderRadius.circular(C.radiusBase),
                                      border: Border.all(
                                        color: isSelected ? C.primary : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(emoji, style: const TextStyle(fontSize: 24)),
                                        const SizedBox(height: 4),
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? C.primary : C.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: _filteredCommon.length,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      ],
                      // Section: API catalogue results
                      if (_apiLoading)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(color: C.primary, strokeWidth: 2)),
                          ),
                        )
                      else if (_apiResults.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text(
                              'Catalogue',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.textSecondary),
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final p = _apiResults[i];
                              final isSelected = _selected == p['name'] && _customCtrl.text.trim().isEmpty;
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: p['image'] != ''
                                      ? Image.network(
                                          p['image'],
                                          width: 40, height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 40, height: 40,
                                            color: C.surfaceAlt,
                                            child: const Icon(Icons.shopping_basket_outlined, size: 20, color: C.textTertiary),
                                          ),
                                        )
                                      : Container(
                                          width: 40, height: 40,
                                          color: C.surfaceAlt,
                                          child: const Icon(Icons.shopping_basket_outlined, size: 20, color: C.textTertiary),
                                        ),
                                ),
                                title: Text(
                                  p['name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? C.primary : C.textPrimary,
                                  ),
                                ),
                                subtitle: p['brand'] != ''
                                    ? Text(p['brand'], maxLines: 1, style: const TextStyle(fontSize: 12, color: C.textSecondary))
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: C.primary, size: 20)
                                    : null,
                                tileColor: isSelected ? C.primaryLight : null,
                                onTap: () => _selectProduct(
                                  p['name'],
                                  imageUrl: (p['image'] as String?)?.isNotEmpty == true ? p['image'] : null,
                                ),
                              );
                            },
                            childCount: _apiResults.length,
                          ),
                        ),
                      ] else if (_filteredCommon.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'Aucun résultat pour "$_query"',
                              style: const TextStyle(color: C.textSecondary, fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  )
                // ── No query: full common products grid ──
                : _filteredCommon.isEmpty
                    ? const Center(
                        child: Text('Aucun produit trouvé', style: TextStyle(color: C.textSecondary)),
                      )
                    : GridView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _filteredCommon.length,
                        itemBuilder: (ctx, i) {
                          final (emoji, name) = _filteredCommon[i];
                          final isSelected = _selected == name && _customCtrl.text.trim().isEmpty;
                          return GestureDetector(
                            onTap: () => _selectProduct(name, imageUrl: 'emoji:$emoji'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: isSelected ? C.primaryLight : C.surfaceAlt,
                                borderRadius: BorderRadius.circular(C.radiusBase),
                                border: Border.all(
                                  color: isSelected ? C.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? C.primary : C.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          const SizedBox(height: 10),
          // Custom product field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _customCtrl,
              decoration: const InputDecoration(
                hintText: 'Ou saisir un article personnalisé...',
                isDense: true,
              ),
              onChanged: (v) => setState(() {
                if (v.isNotEmpty) _selected = null;
              }),
            ),
          ),
          const SizedBox(height: 12),
          // Qty + Add button
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: C.border),
                    borderRadius: BorderRadius.circular(C.radiusBase),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 18, color: _qty > 1 ? C.textPrimary : C.textTertiary),
                        onPressed: () { if (_qty > 1) setState(() => _qty--); },
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$_qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.textPrimary)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () => setState(() => _qty++),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_selected != null || _customCtrl.text.trim().isNotEmpty) ? _submit : null,
                    child: const Text('Ajouter'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── List detail view ──────────────────────────────────────────────────────────

class _ListDetailView extends StatelessWidget {
  final Map<String, dynamic> list;
  final List<Map<String, dynamic>> items;
  final bool loading;
  final VoidCallback onBack;
  final Future<void> Function(String title, int qty, {String? imageUrl}) onAddItem;
  final ValueChanged<Map<String, dynamic>> onToggleItem;
  final ValueChanged<int> onDeleteItem;
  final VoidCallback onDeleteList;
  final VoidCallback onRefresh;
  const _ListDetailView({
    required this.list,
    required this.items,
    required this.loading,
    required this.onBack,
    required this.onAddItem,
    required this.onToggleItem,
    required this.onDeleteItem,
    required this.onDeleteList,
    required this.onRefresh,
  });

  void _openPicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 1.0,
        expand: false,
        snap: true,
        snapSizes: const [0.6, 1.0],
        builder: (sheetCtx, scrollCtrl) => _ProductPickerSheet(
          onAdd: onAddItem,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = items.where((i) => !(i['is_checked'] ?? false)).toList();
    final checked = items.where((i) => i['is_checked'] ?? false).toList();
    final progress =
        items.isNotEmpty ? checked.length / items.length : 0.0;

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
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (list['family_name'] != null)
              Text(
                list['family_name'],
                style: const TextStyle(
                    fontSize: 12, color: C.textSecondary),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Builder(
              builder: (innerCtx) => TextButton.icon(
                onPressed: () => _openPicker(innerCtx),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                style: TextButton.styleFrom(foregroundColor: C.primary),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: C.destructive),
            tooltip: 'Supprimer la liste',
            onPressed: onDeleteList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          if (items.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

          const Divider(height: 1),

          // Items list
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: C.primary),
                  )
                : items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_basket_outlined,
                              size: 48,
                              color: C.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Liste vide',
                              style: TextStyle(
                                fontSize: 16,
                                color: C.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (innerCtx) => TextButton.icon(
                                onPressed: () => _openPicker(innerCtx),
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter un article'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => onRefresh(),
                        color: C.primary,
                        child: ListView(
                          children: [
                            ...pending.map(
                              (item) => _ShoppingItem(
                                item: item,
                                onToggle: () => onToggleItem(item),
                                onDelete: () => onDeleteItem(item['id']),
                              ),
                            ),
                            if (checked.isNotEmpty) ...[
                              const Padding(
                                padding:
                                    EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                                  onDelete: () =>
                                      onDeleteItem(item['id']),
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
    final imageUrl = item['image_url'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final isEmoji = hasImage && imageUrl.startsWith('emoji:');
    final emojiChar = isEmoji ? imageUrl.substring(6) : '';

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GestureDetector(
          onTap: onToggle,
          child: hasImage
              ? Stack(
                  children: [
                    // Emoji product (common predefined items)
                    if (isEmoji)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: C.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(emojiChar, style: const TextStyle(fontSize: 24)),
                        ),
                      )
                    // Real product photo from Open Food Facts
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: C.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shopping_basket_outlined, size: 20, color: C.textTertiary),
                          ),
                        ),
                      ),
                    if (isChecked)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: C.green.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isChecked ? C.green : Colors.transparent,
                    border: Border.all(
                      color: isChecked ? C.green : C.border,
                      width: 2,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
