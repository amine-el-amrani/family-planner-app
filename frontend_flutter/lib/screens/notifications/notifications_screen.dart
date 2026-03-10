import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final res = await _api.dio.get('/notifications/');
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _dismissNotification(int id, Map<String, dynamic> notif) async {
    // Navigate based on entity type
    final entityType = notif['related_entity_type'];
    final entityId = notif['related_entity_id'];

    try {
      await _api.dio.post('/notifications/$id/read');
      setState(() {
        _notifications.removeWhere((n) => n['id'] == id);
      });
    } catch (_) {}

    if (mounted) {
      switch (entityType) {
        case 'family':
          if (entityId != null) {
            context.push('/families/$entityId');
          }
        case 'invitation':
          context.push('/invitations');
        case 'task':
          // Navigate to home screen where tasks are displayed
          context.go('/home');
        case 'event':
          // Navigate to agenda screen where events are displayed
          context.go('/agenda');
        case 'shopping':
        case 'shopping_list':
          // Navigate to shopping screen
          context.go('/shopping');
        default:
          break;
      }
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout supprimer'),
        content: const Text(
          'Supprimer toutes les notifications ?',
        ),
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
        await _api.dio.post('/notifications/mark-all-read');
        setState(() => _notifications.clear());
      } catch (_) {}
    }
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
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _deleteAll,
              child: const Text(
                'Tout supprimer',
                style: TextStyle(color: C.destructive, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : _notifications.isEmpty
              ? _EmptyNotifications()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: C.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _notifications.length,
                    itemBuilder: (ctx, i) {
                      final notif = _notifications[i];
                      return _NotificationTile(
                        notification: notif,
                        onDismiss: () => _dismissNotification(
                          notif['id'],
                          notif,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onDismiss;
  const _NotificationTile({
    required this.notification,
    required this.onDismiss,
  });

  IconData _icon() {
    switch (notification['related_entity_type']) {
      case 'task':
        return Icons.check_circle_outline;
      case 'event':
        return Icons.event_outlined;
      case 'family':
        return Icons.group_outlined;
      case 'invitation':
        return Icons.mail_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconBg() {
    switch (notification['related_entity_type']) {
      case 'task':
        return C.blueLight;
      case 'event':
        return const Color(0xFFF3F0FF);
      case 'family':
        return const Color(0xFFECFDF5);
      case 'invitation':
        return const Color(0xFFFFF7ED);
      default:
        return C.primaryLight;
    }
  }

  Color _iconColor() {
    switch (notification['related_entity_type']) {
      case 'task':
        return C.blue;
      case 'event':
        return C.purple;
      case 'family':
        return C.green;
      case 'invitation':
        return C.orange;
      default:
        return C.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('notif_${notification["id"]}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: C.destructive,
          borderRadius: BorderRadius.circular(C.radiusLg),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onDismiss,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _iconBg(),
                  borderRadius: BorderRadius.circular(C.radiusBase),
                ),
                child: Icon(_icon(), color: _iconColor(), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['message'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: C.textPrimary,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (notification['created_at'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(notification['created_at']),
                        style: const TextStyle(fontSize: 12, color: C.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: C.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
      return 'il y a ${diff.inDays} j';
    } catch (_) {
      return '';
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
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
            child: const Icon(
              Icons.notifications_none,
              color: C.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: C.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vous êtes à jour !',
            style: TextStyle(fontSize: 14, color: C.textTertiary),
          ),
        ],
      ),
    );
  }
}
