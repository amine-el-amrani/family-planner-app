import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';


// ─── Achievement milestones ────────────────────────────────────────────────
const _kAchievements = [
  (icon: '🌱', title: 'Premier pas',   desc: '10 points karma',        karma: 10),
  (icon: '⚡', title: 'Actif',         desc: '100 points karma',       karma: 100),
  (icon: '🔥', title: 'Régulier',      desc: '500 points karma',       karma: 500),
  (icon: '🏅', title: 'Champion',      desc: '1 000 points karma',     karma: 1000),
  (icon: '🏆', title: 'Maître',        desc: '5 000 points karma',     karma: 5000),
  (icon: '👑', title: 'Élite',         desc: '10 000 points karma',    karma: 10000),
  (icon: '⭐', title: 'Légende',      desc: '20 000 points karma',    karma: 20000),
];


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
  bool? _pushEnabled; // null = not checked yet

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _checkPushStatus();
  }

  Future<void> _checkPushStatus() async {
    try {
      final res = await _api.dio.get('/users/me/push-status');
      if (mounted) setState(() => _pushEnabled = res.data['has_subscription'] == true);
    } catch (_) {}
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

  Future<void> _showChangePasswordSheet() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    bool obsC = true, obsN = true, obsF = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Changer le mot de passe',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.textPrimary)),
                const SizedBox(height: 16),
                TextField(
                  controller: currentCtrl,
                  obscureText: obsC,
                  decoration: InputDecoration(
                    hintText: 'Mot de passe actuel',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: C.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(obsC ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18, color: C.textTertiary),
                      onPressed: () => setSt(() => obsC = !obsC),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newCtrl,
                  obscureText: obsN,
                  decoration: InputDecoration(
                    hintText: 'Nouveau mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: C.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(obsN ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18, color: C.textTertiary),
                      onPressed: () => setSt(() => obsN = !obsN),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obsF,
                  decoration: InputDecoration(
                    hintText: 'Confirmer le nouveau mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: C.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(obsF ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18, color: C.textTertiary),
                      onPressed: () => setSt(() => obsF = !obsF),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (newCtrl.text != confirmCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Les mots de passe ne correspondent pas'),
                        backgroundColor: C.destructive,
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                    setSt(() => saving = true);
                    try {
                      await _api.dio.post('/auth/change-password', data: {
                        'current_password': currentCtrl.text,
                        'new_password': newCtrl.text,
                      });
                      if (context.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Mot de passe modifié !'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } catch (e) {
                      String msg = 'Erreur';
                      try {
                        final d = (e as dynamic).response?.data;
                        if (d is Map && d['detail'] != null) msg = d['detail'];
                      } catch (_) {}
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(msg),
                          backgroundColor: C.destructive,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                      setSt(() => saving = false);
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Modifier le mot de passe'),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ],
            ),
          ),
        ),
      ),
    );
    currentCtrl.dispose(); newCtrl.dispose(); confirmCtrl.dispose();
  }

  Future<void> _showChangeEmailSheet() async {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    int step = 1;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(step == 1 ? "Changer l'email" : 'Vérification',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.textPrimary)),
                const SizedBox(height: 6),
                Text(
                  step == 1
                      ? 'Un code de vérification sera envoyé au nouvel email.'
                      : 'Entrez le code reçu sur ${emailCtrl.text}.',
                  style: const TextStyle(fontSize: 13, color: C.textSecondary),
                ),
                const SizedBox(height: 16),
                if (step == 1)
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Nouvel email',
                      prefixIcon: Icon(Icons.email_outlined, size: 18, color: C.textSecondary),
                    ),
                  )
                else
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 8),
                    decoration: const InputDecoration(hintText: '------'),
                    autofocus: true,
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    setSt(() => saving = true);
                    if (step == 1) {
                      try {
                        await _api.dio.post('/auth/request-email-change', data: {
                          'new_email': emailCtrl.text.trim(),
                        });
                        setSt(() { step = 2; saving = false; });
                      } catch (e) {
                        String msg = 'Erreur';
                        try {
                          final d = (e as dynamic).response?.data;
                          if (d is Map && d['detail'] != null) msg = d['detail'];
                        } catch (_) {}
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(msg),
                            backgroundColor: C.destructive,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                        setSt(() => saving = false);
                      }
                    } else {
                      try {
                        await _api.dio.post('/auth/verify-email-change', data: {
                          'new_email': emailCtrl.text.trim(),
                          'code': codeCtrl.text.trim(),
                        });
                        if (context.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          await _fetchProfile();
                          await context.read<AuthProvider>().refreshUser();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Email mis à jour !'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      } catch (e) {
                        String msg = 'Code invalide ou expiré';
                        try {
                          final d = (e as dynamic).response?.data;
                          if (d is Map && d['detail'] != null) msg = d['detail'];
                        } catch (_) {}
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(msg),
                            backgroundColor: C.destructive,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                        setSt(() => saving = false);
                      }
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(step == 1 ? 'Envoyer le code' : 'Vérifier et mettre à jour'),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ],
            ),
          ),
        ),
      ),
    );
    emailCtrl.dispose(); codeCtrl.dispose();
  }

  Future<void> _showDailyGoalDialog() async {
    final current = (_profile?['daily_goal'] as int?) ?? 5;
    int selected = current;
    final ctrl = TextEditingController(text: '$current');
    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Objectif quotidien',
              style: TextStyle(fontWeight: FontWeight.w700, color: C.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nombre de tâches à accomplir par jour',
                  style: TextStyle(fontSize: 13, color: C.textSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: selected > 1 ? () {
                      setSt(() { selected--; ctrl.text = '$selected'; ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length); });
                    } : null,
                    icon: const Icon(Icons.remove_circle_outline, color: C.primary, size: 28),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: C.textPrimary),
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 1 && n <= 50) setSt(() => selected = n);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: selected < 50 ? () {
                      setSt(() { selected++; ctrl.text = '$selected'; ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length); });
                    } : null,
                    icon: const Icon(Icons.add_circle_outline, color: C.primary, size: 28),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('tâches / jour (1 – 50)',
                  style: TextStyle(fontSize: 13, color: C.textTertiary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () { ctrl.dispose(); Navigator.pop(ctx); },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () { ctrl.dispose(); Navigator.pop(ctx, selected); },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == null || confirmed == current || !mounted) return;
    try {
      await _api.dio.put('/users/me/daily-goal', queryParameters: {'goal': confirmed});
      if (mounted) {
        setState(() {
          if (_profile != null) _profile!['daily_goal'] = confirmed;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Objectif mis à jour : $confirmed tâches/jour'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la mise à jour'),
          backgroundColor: C.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _enablePush() async {
    setState(() => _pushLoading = true);
    String msg;
    Color? color;
    try {
      await PushService.initialize();
      final success = await PushService.subscribeAndRegister();
      if (success) {
        msg = 'Notifications push activées ! Vous pouvez fermer l\'app.';
        color = null;
        if (mounted) setState(() => _pushEnabled = true);
      } else {
        msg = 'Permission refusée. Allez dans les réglages du navigateur → Notifications → Autoriser ce site.';
        color = C.destructive;
      }
    } catch (e) {
      msg = 'Erreur : $e';
      color = C.destructive;
    }
    if (mounted) {
      setState(() => _pushLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    }
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
                        GestureDetector(
                          onTap: () {
                            final ip = _avatarImage();
                            if (ip != null) _openPhotoViewer(context, ip);
                          },
                          child: CircleAvatar(
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
                            color: Colors.black.withValues(alpha: 0.04),
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
                    // Achievements section
                    if (_profile?['karma_total'] != null) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          const Text('Succès', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.textPrimary)),
                          const SizedBox(width: 8),
                          Text(
                            '${_kAchievements.where((a) => (_profile!['karma_total'] as int? ?? 0) >= a.karma).length}/${_kAchievements.length}',
                            style: const TextStyle(fontSize: 13, color: C.textSecondary),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _kAchievements.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final a = _kAchievements[i];
                            final unlocked = (_profile!['karma_total'] as int? ?? 0) >= a.karma;
                            return Container(
                              width: 78,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: unlocked ? C.primaryLight : C.surfaceAlt,
                                borderRadius: BorderRadius.circular(C.radiusBase),
                                border: Border.all(color: unlocked ? C.primary.withValues(alpha: 0.35) : C.borderLight),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(unlocked ? a.icon : '🔒', style: TextStyle(fontSize: 26, color: unlocked ? null : const Color(0xFFcbd5e1))),
                                const SizedBox(height: 4),
                                Text(a.title, textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: unlocked ? C.textPrimary : C.textTertiary),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              ]),
                            );
                          },
                        ),
                      ),
                    ],
                    // Daily goal section
                    if (_profile != null) ...[
                      const SizedBox(height: 8),
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
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: C.primaryLight,
                                borderRadius: BorderRadius.circular(C.radiusSm),
                              ),
                              child: const Icon(Icons.flag_outlined, color: C.primary, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('OBJECTIF QUOTIDIEN',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                          color: C.textTertiary, letterSpacing: 0.2)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(_profile?['daily_goal'] as int?) ?? 5} tâches par jour',
                                    style: const TextStyle(fontSize: 15, color: C.textPrimary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: C.textTertiary, size: 18),
                              onPressed: _showDailyGoalDialog,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Push notifications
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_pushEnabled == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(C.radiusSm),
                                border: Border.all(color: const Color(0xFF6EE7B7)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Color(0xFF059669), size: 16),
                                  SizedBox(width: 8),
                                  Text('Notifications push actives', style: TextStyle(color: Color(0xFF059669), fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          if (_pushEnabled == true) const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _pushLoading ? null : _enablePush,
                            icon: _pushLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.primary))
                                : Icon(_pushEnabled == true ? Icons.refresh : Icons.notifications_outlined, color: C.primary),
                            label: Text(_pushEnabled == true ? 'Renouveler l\'abonnement push' : 'Activer les notifications push'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: C.primary,
                              side: const BorderSide(color: C.primary),
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Change password + change email
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showChangePasswordSheet,
                            icon: const Icon(Icons.lock_outline, color: C.textSecondary),
                            label: const Text('Changer le mot de passe'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: C.textSecondary,
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _showChangeEmailSheet,
                            icon: const Icon(Icons.email_outlined, color: C.textSecondary),
                            label: const Text('Changer l\'email'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: C.textSecondary,
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
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

void _openPhotoViewer(BuildContext context, ImageProvider image) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    barrierDismissible: true,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.of(ctx).pop(),
      child: Center(
        child: InteractiveViewer(
          child: Image(image: image),
        ),
      ),
    ),
  );
}
