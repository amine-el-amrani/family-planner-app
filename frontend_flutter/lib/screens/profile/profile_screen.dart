import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient();
  final _nameCtrl = TextEditingController();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  bool _pushLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await _api.dio.get('/users/me');
      setState(() {
        _profile = res.data;
        _nameCtrl.text = res.data['full_name'] ?? '';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await _api.dio.put('/users/me', data: {
        'full_name': _nameCtrl.text.trim(),
      });
      await _fetchProfile();
      await context.read<AuthProvider>().refreshUser();
      setState(() => _editing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour'),
            backgroundColor: C.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (result == null) return;

    try {
      final bytes = await result.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'profile.jpg'),
      });
      await _api.dio.post('/users/me/profile-image', data: formData);
      await _fetchProfile();
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo mise à jour !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de l'upload"),
            backgroundColor: C.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _enablePush() async {
    setState(() => _pushLoading = true);
    try {
      await PushService.initialize();
      await PushService.subscribeAndRegister();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications push activées !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'activer les notifications. Vérifiez les permissions dans les réglages du navigateur.'),
            backgroundColor: C.destructive,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
    if (mounted) setState(() => _pushLoading = false);
  }

  ImageProvider? _avatarImage() {
    final img = _profile?['profile_image'];
    if (img == null) return null;
    if (img.startsWith('data:')) {
      try {
        final b64 = img.split(',')[1];
        return MemoryImage(base64Decode(b64));
      } catch (_) {}
    }
    if (img.startsWith('http')) return NetworkImage(img);
    return NetworkImage('${_api.dio.options.baseUrl}$img');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: C.primary))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'Mon Profil',
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

                    // Avatar
                    const SizedBox(height: 24),
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: C.primaryLight,
                          backgroundImage: _avatarImage(),
                          child: _avatarImage() == null
                              ? const Icon(
                                  Icons.account_circle,
                                  size: 48,
                                  color: C.primary,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: C.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: C.background,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _profile?['full_name'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: C.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profile?['email'] ?? '',
                      style: const TextStyle(fontSize: 14, color: C.textSecondary),
                    ),

                    // Info section
                    const SizedBox(height: 24),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(C.radiusLg),
                        border: Border.all(color: C.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'INFORMATIONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: C.textTertiary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Email row
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: C.primaryLight,
                                  borderRadius:
                                      BorderRadius.circular(C.radiusSm),
                                ),
                                child: const Icon(
                                  Icons.email_outlined,
                                  color: C.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'EMAIL',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: C.textTertiary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _profile?['email'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: C.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, indent: 50),
                          // Name row
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: C.primaryLight,
                                  borderRadius:
                                      BorderRadius.circular(C.radiusSm),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: C.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'NOM COMPLET',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: C.textTertiary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    _editing
                                        ? TextField(
                                            controller: _nameCtrl,
                                            autofocus: true,
                                            style: const TextStyle(fontSize: 15),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                vertical: 6,
                                                horizontal: 8,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            _profile?['full_name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: C.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                              if (!_editing)
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: C.textTertiary,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => _editing = true),
                                ),
                            ],
                          ),
                          if (_editing) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _editing = false),
                                    child: const Text('Annuler'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _saveProfile,
                                    child: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Sauvegarder'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Karma
                    if (_profile?['karma_total'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(C.radiusLg),
                          border: Border.all(color: C.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: C.primaryLight,
                                borderRadius: BorderRadius.circular(C.radiusSm),
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: C.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'KARMA TOTAL',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: C.textTertiary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_profile!['karma_total']} points',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: C.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text('🏆', style: TextStyle(fontSize: 24)),
                          ],
                        ),
                      ),
                    ],

                    // Push notifications
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        onPressed: _pushLoading ? null : _enablePush,
                        icon: _pushLoading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: C.primary),
                              )
                            : const Icon(Icons.notifications_outlined, color: C.primary),
                        label: const Text('Activer les notifications push'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.primary,
                          side: const BorderSide(color: C.primary),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),

                    // Logout
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Déconnexion'),
                              content: const Text(
                                'Êtes-vous sûr de vouloir vous déconnecter ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    context.read<AuthProvider>().logout();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: C.destructive,
                                  ),
                                  child: const Text('Déconnexion'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.logout, color: C.destructive),
                        label: const Text('Déconnexion'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.destructive,
                          side: const BorderSide(color: C.destructive),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}
