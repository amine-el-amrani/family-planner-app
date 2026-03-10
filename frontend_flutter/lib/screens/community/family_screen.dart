import 'dart:convert';
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
  int _pendingInvitCount = 0;

  // Create family form
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFamilies();
    _fetchInvitCount();
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

  Future<void> _fetchInvitCount() async {
    try {
      final res = await _api.dio.get('/families/invitations');
      if (mounted) {
        setState(() {
          _pendingInvitCount = (res.data as List? ?? []).length;
        });
      }
    } catch (_) {}
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

  ImageProvider? _avatarImage(Map<String, dynamic> family) {
    final img = family['family_image'] as String?;
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('data:')) {
      try {
        final b64 = img.split(',').last;
        return MemoryImage(base64Decode(b64));
      } catch (_) {
        return null;
      }
    }
    final url = img.startsWith('http') ? img : '${_api.dio.options.baseUrl}$img';
    return NetworkImage(url);
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
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () async {
                          await context.push('/invitations');
                          _fetchInvitCount();
                        },
                        icon: const Icon(Icons.mail_outline, color: C.textSecondary),
                      ),
                      if (_pendingInvitCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                            child: Text(
                              '$_pendingInvitCount',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
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
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: _families.length,
                            itemBuilder: (ctx, i) {
                              final family = _families[i];
                              final avatarImg = _avatarImage(family);
                              return GestureDetector(
                                onTap: () => context.push('/families/${family['id']}'),
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
                                      avatarImg != null
                                          ? CircleAvatar(
                                              radius: 24,
                                              backgroundImage: avatarImg,
                                              backgroundColor: C.primaryLight,
                                            )
                                          : Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: C.primaryLight,
                                                borderRadius: BorderRadius.circular(C.radiusBase),
                                              ),
                                              child: const Icon(Icons.group, color: C.primary, size: 24),
                                            ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              family['name'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: C.textPrimary,
                                              ),
                                            ),
                                            if (family['description'] != null &&
                                                (family['description'] as String).isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                family['description'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: C.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: C.textTertiary, size: 20),
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
