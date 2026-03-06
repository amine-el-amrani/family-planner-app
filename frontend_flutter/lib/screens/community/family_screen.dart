import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _families = [];
  bool _loading = true;

  // Create family form
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFamilies();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFamilies() async {
    setState(() => _loading = true);
    try {
      final res = await _api.dio.get('/families/');
      setState(() {
        _families = List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _createFamily() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    try {
      await _api.dio.post(
        '/families/',
        queryParameters: {'name': _nameCtrl.text.trim()},
      );
      if (mounted) Navigator.pop(context);
      _nameCtrl.clear();
      _fetchFamilies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Famille créée !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _leaveFamily(int familyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter la famille'),
        content: const Text('Êtes-vous sûr de vouloir quitter cette famille ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: C.destructive),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _api.dio.post('/families/$familyId/leave');
        _fetchFamilies();
      } catch (_) {}
    }
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
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
                'Nouvelle famille',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Nom de la famille'),
                onSubmitted: (_) => _createFamily(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createFamily,
                child: const Text('Créer'),
              ),
              const SizedBox(height: 8),
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

  String _avatarUrl(Map<String, dynamic> family) {
    final img = family['family_image'];
    if (img == null) return '';
    if (img.startsWith('http')) return img;
    return '${_api.dio.options.baseUrl}$img';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mes Familles',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: C.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (_families.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: C.primary,
                        borderRadius: BorderRadius.circular(C.radiusFull),
                      ),
                      child: Text(
                        '${_families.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => context.push('/invitations'),
                    icon: const Icon(
                      Icons.mail_outline,
                      color: C.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: C.primary),
                    )
                  : _families.isEmpty
                      ? _EmptyFamilies(onAdd: _showCreateModal)
                      : RefreshIndicator(
                          onRefresh: _fetchFamilies,
                          color: C.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _families.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 72,
                            ),
                            itemBuilder: (ctx, i) {
                              final family = _families[i];
                              final url = _avatarUrl(family);
                              return ListTile(
                                onTap: () =>
                                    context.push('/families/${family['id']}'),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 6,
                                ),
                                leading: url.isNotEmpty
                                    ? CircleAvatar(
                                        radius: 22,
                                        backgroundImage: NetworkImage(url),
                                        backgroundColor: C.primaryLight,
                                      )
                                    : CircleAvatar(
                                        radius: 22,
                                        backgroundColor: C.primaryLight,
                                        child: const Icon(
                                          Icons.group,
                                          color: C.primary,
                                          size: 22,
                                        ),
                                      ),
                                title: Text(
                                  family['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: C.textPrimary,
                                  ),
                                ),
                                subtitle: family['description'] != null
                                    ? Text(
                                        family['description'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: C.textSecondary,
                                        ),
                                      )
                                    : null,
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: C.textTertiary,
                                  size: 20,
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
        onPressed: _showCreateModal,
        backgroundColor: C.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Créer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _EmptyFamilies extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyFamilies({required this.onAdd});

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
              child: const Icon(Icons.group_outlined, color: C.primary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucune famille',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: C.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Créez votre première famille pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: C.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
