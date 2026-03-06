import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();

  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _familyTasks = [];
  List<Map<String, dynamic>> _tomorrowUrgent = [];
  List<Map<String, dynamic>> _weekEvents = [];
  Map<String, dynamic>? _karma;
  bool _loading = true;

  // Add task form
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _priority = 'normale';
  String _visibility = 'prive';
  DateTime? _dueDate;
  int? _familyId;
  List<Map<String, dynamic>> _families = [];
  int? _assignedToId;
  List<Map<String, dynamic>> _familyMembers = [];

  // Add event form
  final _eventTitleCtrl = TextEditingController();
  final _eventDescCtrl = TextEditingController();
  DateTime _eventDate = DateTime.now();
  TimeOfDay? _eventTime;
  int? _eventFamilyId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _eventTitleCtrl.dispose();
    _eventDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.dio.get('/tasks/today'),
        _api.dio.get('/users/me/karma'),
        _api.dio.get('/families/'),
        _api.dio.get('/events/this-week'),
      ]);

      final todayData = results[0].data as Map<String, dynamic>;
      final personal = List<Map<String, dynamic>>.from(
        (todayData['personal'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      final assignedToMe = List<Map<String, dynamic>>.from(
        (todayData['assigned_to_me'] ?? [])
            .map((e) => Map<String, dynamic>.from(e)),
      );
      final famille = List<Map<String, dynamic>>.from(
        (todayData['famille'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      final tomorrow = List<Map<String, dynamic>>.from(
        (todayData['tomorrow_urgent'] ?? [])
            .map((e) => Map<String, dynamic>.from(e)),
      );

      setState(() {
        _myTasks = [...personal, ...assignedToMe];
        _familyTasks = famille;
        _tomorrowUrgent = tomorrow;
        _karma = results[1].data as Map<String, dynamic>;
        _families = List<Map<String, dynamic>>.from(
          (results[2].data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        final weekData = results[3].data;
        _weekEvents = List<Map<String, dynamic>>.from(
          (weekData is List ? weekData : [])
              .map((e) => Map<String, dynamic>.from(e)),
        );
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final newStatus =
        task['status'] == 'fait' ? 'en_attente' : 'fait';
    try {
      await _api.dio.patch('/tasks/${task['id']}', data: {'status': newStatus});
      _loadData();
    } catch (_) {}
  }

  Future<void> _createTask() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    try {
      await _api.dio.post('/tasks/', data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'priority': _priority,
        'visibility': _visibility,
        'due_date': _dueDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_dueDate!),
        'family_id': _familyId,
        'assigned_to_id': _assignedToId,
      });
      if (mounted) Navigator.pop(context);
      _titleCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _priority = 'normale';
        _visibility = 'prive';
        _dueDate = null;
        _familyId = null;
        _assignedToId = null;
      });
      _loadData();
    } catch (_) {}
  }

  Future<void> _createEvent() async {
    if (_eventTitleCtrl.text.trim().isEmpty || _eventFamilyId == null) return;
    final timeStr = _eventTime != null
        ? '${_eventTime!.hour.toString().padLeft(2, '0')}:${_eventTime!.minute.toString().padLeft(2, '0')}'
        : null;
    try {
      await _api.dio.post('/events/', data: {
        'title': _eventTitleCtrl.text.trim(),
        'description': _eventDescCtrl.text.trim().isEmpty
            ? null
            : _eventDescCtrl.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(_eventDate),
        'time_from': timeStr,
        'family_id': _eventFamilyId,
      });
      if (mounted) Navigator.pop(context);
      _eventTitleCtrl.clear();
      _eventDescCtrl.clear();
      setState(() {
        _eventDate = DateTime.now();
        _eventTime = null;
        _eventFamilyId = null;
      });
      _loadData();
    } catch (_) {}
  }

  void _showFabChoiceModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(C.radiusXl),
        ),
        title: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.w700, color: C.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChoiceItem(
              icon: Icons.check_circle_outline,
              label: 'Tâche',
              color: C.primary,
              onTap: () {
                Navigator.pop(ctx);
                _showAddTaskSheet();
              },
            ),
            const SizedBox(height: 10),
            _ChoiceItem(
              icon: Icons.event_outlined,
              label: 'Événement',
              color: C.blue,
              onTap: () {
                Navigator.pop(ctx);
                _showAddEventSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTaskSheet(
        titleCtrl: _titleCtrl,
        descCtrl: _descCtrl,
        priority: _priority,
        visibility: _visibility,
        dueDate: _dueDate,
        familyId: _familyId,
        families: _families,
        assignedToId: _assignedToId,
        familyMembers: _familyMembers,
        onPriorityChanged: (v) => setState(() => _priority = v),
        onVisibilityChanged: (v) => setState(() => _visibility = v),
        onDueDateChanged: (d) => setState(() => _dueDate = d),
        onFamilyChanged: (fid) async {
          setState(() => _familyId = fid);
          if (fid != null) {
            try {
              final res =
                  await _api.dio.get('/families/$fid/members');
              setState(() {
                _familyMembers = List<Map<String, dynamic>>.from(
                  (res.data as List).map((e) => Map<String, dynamic>.from(e)),
                );
              });
            } catch (_) {}
          } else {
            setState(() {
              _familyMembers = [];
              _assignedToId = null;
            });
          }
        },
        onAssignedChanged: (id) => setState(() => _assignedToId = id),
        onSubmit: _createTask,
      ),
    );
  }

  void _showAddEventSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEventSheet(
        titleCtrl: _eventTitleCtrl,
        descCtrl: _eventDescCtrl,
        date: _eventDate,
        time: _eventTime,
        familyId: _eventFamilyId,
        families: _families,
        onDateChanged: (d) => setState(() => _eventDate = d),
        onTimeChanged: (t) => setState(() => _eventTime = t),
        onFamilyChanged: (fid) => setState(() => _eventFamilyId = fid),
        onSubmit: _createEvent,
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgente':
        return C.priorityUrgente;
      case 'haute':
        return C.priorityHaute;
      default:
        return C.borderLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = (user?['full_name'] as String? ?? '').split(' ').first;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bonjour'
        : now.hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';

    return Scaffold(
      backgroundColor: C.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: C.primary),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: C.primary,
                child: CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$greeting, $firstName 👋',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: C.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'EEEE d MMMM',
                                      'fr_FR',
                                    ).format(now),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: C.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => context.push('/notifications'),
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: C.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Karma widget
                    if (_karma != null)
                      SliverToBoxAdapter(
                        child: _KarmaWidget(karma: _karma!),
                      ),

                    // My tasks section
                    if (_myTasks.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Mes tâches',
                        count: _myTasks
                            .where((t) => t['status'] != 'fait')
                            .length,
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _TaskTile(
                            task: _myTasks[i],
                            priorityColor: _priorityColor(
                              _myTasks[i]['priority'] ?? 'normale',
                            ),
                            onToggle: () => _toggleTask(_myTasks[i]),
                          ),
                          childCount: _myTasks.length,
                        ),
                      ),
                    ],

                    // Family tasks section
                    if (_familyTasks.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'En famille',
                        count: _familyTasks
                            .where((t) => t['status'] != 'fait')
                            .length,
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _TaskTile(
                            task: _familyTasks[i],
                            priorityColor: _priorityColor(
                              _familyTasks[i]['priority'] ?? 'normale',
                            ),
                            onToggle: () => _toggleTask(_familyTasks[i]),
                          ),
                          childCount: _familyTasks.length,
                        ),
                      ),
                    ],

                    // Tomorrow urgent
                    if (_tomorrowUrgent.isNotEmpty) ...[
                      const _SectionHeader(
                        title: 'Urgent demain',
                        icon: Icons.warning_amber_rounded,
                        iconColor: C.priorityHaute,
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _TaskTile(
                            task: _tomorrowUrgent[i],
                            priorityColor: _priorityColor(
                              _tomorrowUrgent[i]['priority'] ?? 'haute',
                            ),
                            onToggle: () => _toggleTask(_tomorrowUrgent[i]),
                          ),
                          childCount: _tomorrowUrgent.length,
                        ),
                      ),
                    ],

                    // Week events
                    if (_weekEvents.isNotEmpty) ...[
                      const _SectionHeader(
                        title: 'Cette semaine',
                        icon: Icons.calendar_today_outlined,
                        iconColor: C.blue,
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _EventTile(event: _weekEvents[i]),
                          childCount: _weekEvents.length,
                        ),
                      ),
                    ],

                    if (_myTasks.isEmpty &&
                        _familyTasks.isEmpty &&
                        _tomorrowUrgent.isEmpty &&
                        _weekEvents.isEmpty)
                      SliverToBoxAdapter(
                        child: _EmptyState(onAdd: _showFabChoiceModal),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabChoiceModal,
        backgroundColor: C.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _KarmaWidget extends StatelessWidget {
  final Map<String, dynamic> karma;
  const _KarmaWidget({required this.karma});

  @override
  Widget build(BuildContext context) {
    final total = karma['karma_total'] ?? 0;
    final daily = karma['daily_completed'] ?? 0;
    final goal = karma['daily_goal'] ?? 5;
    final progress = goal > 0 ? (daily / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [C.primary, Color(0xFFCF3520)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(C.radiusLg),
        boxShadow: [
          BoxShadow(
            color: C.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    const Text(
                      'Karma',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$total pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white30,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$daily/$goal tâches aujourd\'hui',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '🏆',
            style: const TextStyle(fontSize: 36),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final IconData? icon;
  final Color? iconColor;
  const _SectionHeader({
    required this.title,
    this.count,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? C.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: C.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: C.primary,
                  borderRadius: BorderRadius.circular(C.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final VoidCallback onToggle;
  const _TaskTile({
    required this.task,
    required this.priorityColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task['status'] == 'fait';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.radiusBase),
        border: Border(
          left: BorderSide(color: priorityColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? C.primary : Colors.transparent,
              border: Border.all(
                color: isDone ? C.primary : C.border,
                width: 2,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        ),
        title: Text(
          task['title'] ?? '',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDone ? C.textTertiary : C.textPrimary,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: _buildSubtitle(task),
        trailing: task['priority'] != 'normale'
            ? _PriorityBadge(priority: task['priority'])
            : null,
      ),
    );
  }

  Widget? _buildSubtitle(Map<String, dynamic> task) {
    final parts = <String>[];
    if (task['family_name'] != null) parts.add(task['family_name']);
    if (task['assigned_to_name'] != null) parts.add('→ ${task['assigned_to_name']}');
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: const TextStyle(fontSize: 12, color: C.textSecondary),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = priority == 'urgente' ? C.priorityUrgente : C.priorityHaute;
    final label = priority == 'urgente' ? 'Urgent' : 'Haute';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(C.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.radiusBase),
        border: Border(left: BorderSide(color: C.blue, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: C.blueLight,
            borderRadius: BorderRadius.circular(C.radiusSm),
          ),
          child: const Icon(Icons.event, color: C.blue, size: 20),
        ),
        title: Text(
          event['title'] ?? '',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: C.textPrimary,
          ),
        ),
        subtitle: _buildSubtitle(),
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];
    if (event['date'] != null) {
      try {
        final d = DateTime.parse(event['date']);
        parts.add(DateFormat('EEE d MMM', 'fr_FR').format(d));
      } catch (_) {
        parts.add(event['date']);
      }
    }
    if (event['time_from'] != null) parts.add(event['time_from']);
    if (event['family_name'] != null) parts.add(event['family_name']);
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: const TextStyle(fontSize: 12, color: C.textSecondary),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(C.radius2xl),
            ),
            child: const Icon(Icons.check_circle_outline, color: C.primary, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Journée libre !',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: C.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aucune tâche pour aujourd\'hui. Profitez-en !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: C.textSecondary),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une tâche'),
          ),
        ],
      ),
    );
  }
}

class _ChoiceItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ChoiceItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(C.radiusBase),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(C.radiusBase),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Task Sheet ───────────────────────────────────────────────────────────

class _AddTaskSheet extends StatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final String priority;
  final String visibility;
  final DateTime? dueDate;
  final int? familyId;
  final List<Map<String, dynamic>> families;
  final int? assignedToId;
  final List<Map<String, dynamic>> familyMembers;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<DateTime?> onDueDateChanged;
  final ValueChanged<int?> onFamilyChanged;
  final ValueChanged<int?> onAssignedChanged;
  final VoidCallback onSubmit;

  const _AddTaskSheet({
    required this.titleCtrl,
    required this.descCtrl,
    required this.priority,
    required this.visibility,
    required this.dueDate,
    required this.familyId,
    required this.families,
    required this.assignedToId,
    required this.familyMembers,
    required this.onPriorityChanged,
    required this.onVisibilityChanged,
    required this.onDueDateChanged,
    required this.onFamilyChanged,
    required this.onAssignedChanged,
    required this.onSubmit,
  });

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
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
                'Nouvelle tâche',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: widget.titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Titre de la tâche'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: widget.descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Description (optionnel)'),
              ),
              const SizedBox(height: 12),
              // Priority
              _SheetLabel(label: 'Priorité'),
              const SizedBox(height: 6),
              _SegmentedRow(
                items: const [
                  ('normale', 'Normale'),
                  ('haute', 'Haute'),
                  ('urgente', 'Urgente'),
                ],
                selected: widget.priority,
                onSelected: widget.onPriorityChanged,
              ),
              const SizedBox(height: 12),
              // Visibility
              _SheetLabel(label: 'Visibilité'),
              const SizedBox(height: 6),
              _SegmentedRow(
                items: const [('prive', 'Privée'), ('famille', 'Famille')],
                selected: widget.visibility,
                onSelected: widget.onVisibilityChanged,
              ),
              const SizedBox(height: 12),
              // Date
              _SheetLabel(label: 'Échéance'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: widget.dueDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) widget.onDueDateChanged(picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: C.surfaceAlt,
                    borderRadius: BorderRadius.circular(C.radiusBase),
                    border: Border.all(color: C.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: C.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.dueDate == null
                            ? 'Aucune date'
                            : DateFormat('EEE d MMM', 'fr_FR')
                                .format(widget.dueDate!),
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.dueDate == null
                              ? C.textPlaceholder
                              : C.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (widget.dueDate != null)
                        GestureDetector(
                          onTap: () => widget.onDueDateChanged(null),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: C.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Family selector
              if (widget.visibility == 'famille' &&
                  widget.families.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SheetLabel(label: 'Famille'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: widget.familyId,
                  decoration: const InputDecoration(
                    hintText: 'Choisir une famille',
                  ),
                  items: widget.families.map((f) {
                    return DropdownMenuItem<int>(
                      value: f['id'],
                      child: Text(f['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => widget.onFamilyChanged(v),
                ),
              ],
              // Assign to member
              if (widget.familyMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SheetLabel(label: 'Assigner à'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: widget.assignedToId,
                  decoration: const InputDecoration(hintText: 'Non assigné'),
                  items: widget.familyMembers.map((m) {
                    return DropdownMenuItem<int>(
                      value: m['id'],
                      child: Text(m['full_name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => widget.onAssignedChanged(v),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: widget.onSubmit,
                child: const Text('Ajouter la tâche'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add Event Sheet ──────────────────────────────────────────────────────────

class _AddEventSheet extends StatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final DateTime date;
  final TimeOfDay? time;
  final int? familyId;
  final List<Map<String, dynamic>> families;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay?> onTimeChanged;
  final ValueChanged<int?> onFamilyChanged;
  final VoidCallback onSubmit;

  const _AddEventSheet({
    required this.titleCtrl,
    required this.descCtrl,
    required this.date,
    required this.time,
    required this.familyId,
    required this.families,
    required this.onDateChanged,
    required this.onTimeChanged,
    required this.onFamilyChanged,
    required this.onSubmit,
  });

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
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
                'Nouvel événement',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: widget.titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Titre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: widget.descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Description'),
              ),
              const SizedBox(height: 12),
              _SheetLabel(label: 'Date'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: widget.date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) widget.onDateChanged(picked);
                },
                child: _DateField(
                  label: DateFormat('EEE d MMMM yyyy', 'fr_FR').format(
                    widget.date,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _SheetLabel(label: 'Heure (optionnel)'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: widget.time ?? TimeOfDay.now(),
                  );
                  widget.onTimeChanged(picked);
                },
                child: _DateField(
                  label: widget.time == null
                      ? 'Toute la journée'
                      : widget.time!.format(context),
                  isPlaceholder: widget.time == null,
                ),
              ),
              const SizedBox(height: 12),
              _SheetLabel(label: 'Famille *'),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: widget.familyId,
                decoration: const InputDecoration(hintText: 'Choisir une famille'),
                items: widget.families.map((f) {
                  return DropdownMenuItem<int>(
                    value: f['id'],
                    child: Text(f['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (v) => widget.onFamilyChanged(v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: widget.onSubmit,
                child: const Text('Créer l\'événement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String label;
  const _SheetLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: C.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  final List<(String, String)> items;
  final String selected;
  final ValueChanged<String> onSelected;
  const _SegmentedRow({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final isSelected = item.$1 == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(item.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? C.primary : C.surfaceAlt,
                borderRadius: BorderRadius.circular(C.radiusBase),
                border: Border.all(
                  color: isSelected ? C.primary : C.border,
                ),
              ),
              child: Text(
                item.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : C.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final bool isPlaceholder;
  const _DateField({required this.label, this.isPlaceholder = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: C.surfaceAlt,
        borderRadius: BorderRadius.circular(C.radiusBase),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: C.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isPlaceholder ? C.textPlaceholder : C.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
