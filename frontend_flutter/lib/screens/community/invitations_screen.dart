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
  String? _error;

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
    setState(() { _loading = true; _error = null; });
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
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
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
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_outlined,
                            size: 48, color: C.textTertiary),
                        const SizedBox(height: 12),
                        const Text('Impossible de charger les invitations',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15, color: C.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
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
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _received.length,
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
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _sent.length,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(C.radiusLg),
          border: Border.all(color: C.borderLight),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: C.primaryLight,
                borderRadius: BorderRadius.circular(C.radiusBase),
              ),
              child: const Icon(Icons.person_outline, color: C.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invitation['email'] ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: C.textPrimary),
                  ),
                  if ((invitation['family_name'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.group_outlined, size: 11, color: C.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          invitation['family_name'],
                          style: const TextStyle(fontSize: 12, color: C.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(C.radiusFull),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ),
          ],
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
