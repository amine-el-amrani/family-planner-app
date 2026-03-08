import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabController;

  List<Map<String, dynamic>> _received = [];
  List<Map<String, dynamic>> _sent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.dio.get('/families/my-invitations'),
        _api.dio.get('/families/my-sent-invitations'),
      ]);
      setState(() {
        _received = List<Map<String, dynamic>>.from(
          (results[0].data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _sent = List<Map<String, dynamic>>.from(
          (results[1].data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(int id, String action) async {
    try {
      await _api.dio.post('/families/invitations/$id/$action');
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept' ? 'Invitation acceptée !' : 'Invitation refusée',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background,
      appBar: AppBar(
        title: const Text('Invitations'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: C.primary,
          labelColor: C.primary,
          unselectedLabelColor: C.textSecondary,
          tabs: [
            Tab(text: 'Reçues (${_received.length})'),
            Tab(text: 'Envoyées (${_sent.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                // Received invitations
                _received.isEmpty
                    ? _EmptyInvitations(
                        message: 'Aucune invitation reçue',
                        icon: Icons.mail_outline,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: C.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _received.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final inv = _received[i];
                            return _ReceivedInvitationTile(
                              invitation: inv,
                              onAccept: () => _respond(inv['id'], 'accept'),
                              onReject: () => _respond(inv['id'], 'reject'),
                            );
                          },
                        ),
                      ),

                // Sent invitations
                _sent.isEmpty
                    ? _EmptyInvitations(
                        message: 'Aucune invitation envoyée',
                        icon: Icons.send_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: C.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _sent.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final inv = _sent[i];
                            return _SentInvitationTile(invitation: inv);
                          },
                        ),
                      ),
              ],
            ),
    );
  }
}

class _ReceivedInvitationTile extends StatelessWidget {
  final Map<String, dynamic> invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _ReceivedInvitationTile({
    required this.invitation,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(C.radiusLg),
          border: Border.all(color: C.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: C.primaryLight,
                    borderRadius: BorderRadius.circular(C.radiusBase),
                  ),
                  child: const Icon(Icons.group, color: C.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation['family_name'] ?? 'Famille inconnue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: C.textPrimary,
                        ),
                      ),
                      Text(
                        'Invité par ${invitation['invited_by'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: C.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.destructive,
                      side: const BorderSide(color: C.destructive),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SentInvitationTile extends StatelessWidget {
  final Map<String, dynamic> invitation;
  const _SentInvitationTile({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final status = invitation['status'] ?? 'pending';
    final (statusLabel, statusColor) = switch (status) {
      'accepted' => ('Acceptée', C.green),
      'rejected' => ('Refusée', C.destructive),
      _ => ('En attente', C.textTertiary),
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: C.primaryLight,
        child: const Icon(Icons.person_outline, color: C.primary),
      ),
      title: Text(
        invitation['email'] ?? '',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: C.textPrimary,
        ),
      ),
      subtitle: Text(
        invitation['family_name'] ?? '',
        style: const TextStyle(fontSize: 13, color: C.textSecondary),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(C.radiusFull),
        ),
        child: Text(
          statusLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}

class _EmptyInvitations extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyInvitations({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(C.radius2xl),
            ),
            child: Icon(icon, color: C.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: C.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
