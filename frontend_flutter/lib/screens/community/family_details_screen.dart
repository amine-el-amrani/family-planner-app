import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';

class FamilyDetailsScreen extends StatefulWidget {
  final int familyId;
  const FamilyDetailsScreen({super.key, required this.familyId});

  @override
  State<FamilyDetailsScreen> createState() => _FamilyDetailsScreenState();
}

class _FamilyDetailsScreenState extends State<FamilyDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabController;

  Map<String, dynamic>? _family;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;

  // Invite form
  final _inviteEmailCtrl = TextEditingController();

  // Edit family
  final _editNameCtrl = TextEditingController();
  final _editDescCtrl = TextEditingController();

  // Add note
  final _noteTitleCtrl = TextEditingController();
  final _noteContentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inviteEmailCtrl.dispose();
    _editNameCtrl.dispose();
    _editDescCtrl.dispose();
    _noteTitleCtrl.dispose();
    _noteContentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.dio.get('/families/${widget.familyId}'),
        _api.dio.get('/families/${widget.familyId}/members'),
        _api.dio.get('/events/', queryParameters: {'family_id': widget.familyId}),
        _api.dio.get('/notes/${widget.familyId}'),
      ]);
      setState(() {
        _family = results[0].data as Map<String, dynamic>;
        _members = List<Map<String, dynamic>>.from(
          (results[1].data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _events = List<Map<String, dynamic>>.from(
          (results[2].data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _notes = List<Map<String, dynamic>>.from(
          (results[3].data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _inviteMember() async {
    if (_inviteEmailCtrl.text.trim().isEmpty) return;
    try {
      await _api.dio.post(
        '/families/${widget.familyId}/invite',
        queryParameters: {'email': _inviteEmailCtrl.text.trim()},
      );
      if (mounted) Navigator.pop(context);
      _inviteEmailCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation envoyée !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _editFamily() async {
    try {
      await _api.dio.put('/families/${widget.familyId}', data: {
        'name': _editNameCtrl.text.trim(),
        'description': _editDescCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
      _loadData();
    } catch (_) {}
  }

  Future<void> _pickFamilyImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (result == null) return;
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(result.path, filename: 'family.jpg'),
      });
      await _api.dio.post(
        '/families/${widget.familyId}/family-image',
        data: formData,
      );
      _loadData();
    } catch (_) {}
  }

  Future<void> _addNote() async {
    if (_noteTitleCtrl.text.trim().isEmpty) return;
    try {
      await _api.dio.post('/notes/${widget.familyId}', data: {
        'title': _noteTitleCtrl.text.trim(),
        'content': _noteContentCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
      _noteTitleCtrl.clear();
      _noteContentCtrl.clear();
      _loadData();
    } catch (_) {}
  }

  Future<void> _deleteNote(int noteId) async {
    try {
      await _api.dio.delete('/notes/$noteId');
      _loadData();
    } catch (_) {}
  }

  void _showInviteSheet() {
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
                'Inviter un membre',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inviteEmailCtrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email du membre',
                  prefixIcon: Icon(Icons.email_outlined, color: C.textSecondary),
                ),
                onSubmitted: (_) => _inviteMember(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _inviteMember,
                child: const Text('Envoyer l\'invitation'),
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

  void _showAddNoteSheet() {
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
                'Nouvelle note',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteTitleCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Titre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteContentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Contenu'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addNote,
                child: const Text('Ajouter'),
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

  String? _familyAvatarUrl() {
    final img = _family?['family_image'];
    if (img == null) return null;
    if (img.startsWith('http')) return img;
    return '${_api.dio.options.baseUrl}$img';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_family?['name'] ?? 'Famille'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _showInviteSheet,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              _editNameCtrl.text = _family?['name'] ?? '';
              _editDescCtrl.text = _family?['description'] ?? '';
              _showEditSheet();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: C.primary,
          labelColor: C.primary,
          unselectedLabelColor: C.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'À propos'),
            Tab(text: 'Membres'),
            Tab(text: 'Événements'),
            Tab(text: 'Notes'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _AboutTab(
                  family: _family!,
                  avatarUrl: _familyAvatarUrl(),
                  onPickImage: _pickFamilyImage,
                ),
                _MembersTab(members: _members),
                _EventsTab(events: _events),
                _NotesTab(
                  notes: _notes,
                  onAdd: _showAddNoteSheet,
                  onDelete: _deleteNote,
                ),
              ],
            ),
    );
  }

  void _showEditSheet() {
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
                'Modifier la famille',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _editNameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _editDescCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickFamilyImage();
                },
                icon: const Icon(Icons.image_outlined),
                label: const Text('Changer l\'image'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _editFamily,
                child: const Text('Sauvegarder'),
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
}

// ─── Tab content widgets ──────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final Map<String, dynamic> family;
  final String? avatarUrl;
  final VoidCallback onPickImage;
  const _AboutTab({
    required this.family,
    required this.avatarUrl,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: onPickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: C.primaryLight,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.group, color: C.primary, size: 40)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: C.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.background, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            family['name'] ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: C.textPrimary,
            ),
          ),
          if (family['description'] != null &&
              (family['description'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              family['description'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: C.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersTab extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  const _MembersTab({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(
        child: Text(
          'Aucun membre',
          style: TextStyle(color: C.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: members.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) {
        final m = members[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(
            backgroundColor: C.primaryLight,
            backgroundImage: m['profile_image'] != null
                ? NetworkImage(m['profile_image'])
                : null,
            child: m['profile_image'] == null
                ? Text(
                    (m['full_name'] as String? ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: C.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          title: Text(
            m['full_name'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: C.textPrimary,
            ),
          ),
          subtitle: Text(
            m['email'] ?? '',
            style: const TextStyle(fontSize: 13, color: C.textSecondary),
          ),
        );
      },
    );
  }
}

class _EventsTab extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  const _EventsTab({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'Aucun événement',
          style: TextStyle(color: C.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final event = events[i];
        String dateStr = event['date'] ?? '';
        try {
          final d = DateTime.parse(event['date']);
          dateStr = DateFormat('EEE d MMM', 'fr_FR').format(d);
        } catch (_) {}

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: C.blueLight,
              borderRadius: BorderRadius.circular(C.radiusBase),
            ),
            child: const Icon(Icons.event, color: C.blue, size: 22),
          ),
          title: Text(
            event['title'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: C.textPrimary,
            ),
          ),
          subtitle: Text(
            [dateStr, event['time_from']].whereType<String>().join(' · '),
            style: const TextStyle(fontSize: 13, color: C.textSecondary),
          ),
        );
      },
    );
  }
}

class _NotesTab extends StatelessWidget {
  final List<Map<String, dynamic>> notes;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  const _NotesTab({
    required this.notes,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        notes.isEmpty
            ? const Center(
                child: Text(
                  'Aucune note',
                  style: TextStyle(color: C.textSecondary),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: notes.length,
                itemBuilder: (ctx, i) {
                  final note = notes[i];
                  return _NoteCard(
                    note: note,
                    onDelete: () => onDelete(note['id']),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: onAdd,
            mini: true,
            backgroundColor: C.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onDelete;
  const _NoteCard({required this.note, required this.onDelete});

  static const _colors = [
    Color(0xFFFFF9C4),
    Color(0xFFFFE0B2),
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFF3E5F5),
  ];

  @override
  Widget build(BuildContext context) {
    final colorIdx = (note['id'] as int? ?? 0) % _colors.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors[colorIdx],
        borderRadius: BorderRadius.circular(C.radiusBase),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  note['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: C.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: C.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              note['content'] ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: C.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
