import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _notifCount = 0;
  Timer? _notifTimer;

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
    _fetchNotifCount();
    _notifTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchNotifCount(),
    );
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _eventTitleCtrl.dispose();
    _eventDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchNotifCount() async {
    try {
      final res = await _api.dio.get('/notifications/');
      if (mounted) {
        setState(() {
          _notifCount = (res.data as List? ?? []).length;
        });
      }
    } catch (_) {}
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

  Future<void> _refreshKarma() async {
    try {
      final res = await _api.dio.get('/users/me/karma');
      if (mounted) setState(() => _karma = res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    HapticFeedback.lightImpact();
    final newStatus = task['status'] == 'fait' ? 'en_attente' : 'fait';
    // Optimistic update — flip instantly in all lists
    void flipIn(List<Map<String, dynamic>> list) {
      final idx = list.indexWhere((t) => t['id'] == task['id']);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(task);
        updated['status'] = newStatus;
        list[idx] = updated;
      }
    }
    setState(() {
      flipIn(_myTasks);
      flipIn(_familyTasks);
      flipIn(_tomorrowUrgent);
    });
    try {
      final res = await _api.dio.patch('/tasks/${task['id']}', data: {'status': newStatus});
      // Backend now includes current_user_karma_total in the response — update directly
      final newKarma = res.data['current_user_karma_total'];
      if (newKarma != null && _karma != null && mounted) {
        setState(() {
          _karma = Map<String, dynamic>.from(_karma!)..['karma_total'] = newKarma;
        });
      } else {
        // Fallback: separate GET request
        _refreshKarma();
      }
    } catch (_) {
      // Revert on failure
      void revertIn(List<Map<String, dynamic>> list) {
        final idx = list.indexWhere((t) => t['id'] == task['id']);
        if (idx != -1) list[idx] = task;
      }
      if (mounted) {
        setState(() {
          revertIn(_myTasks);
          revertIn(_familyTasks);
          revertIn(_tomorrowUrgent);
        });
      }
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la tâche'),
        content: Text('Supprimer "${(task['title'] ?? 'cette tâche').toString()}" ?'),
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
    if (confirmed != true || !mounted) return;
    void removeFrom(List<Map<String, dynamic>> list) =>
        list.removeWhere((t) => t['id'] == task['id']);
    setState(() {
      removeFrom(_myTasks);
      removeFrom(_familyTasks);
      removeFrom(_tomorrowUrgent);
    });
    try {
      final taskId = task['id'];
      await _api.dio.delete('/tasks/$taskId');
    } catch (_) {
      if (mounted) _loadData();
    }
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la création de la tâche'),
          backgroundColor: C.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
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
        'event_date': DateFormat('yyyy-MM-dd').format(_eventDate),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la création de l\'événement'),
          backgroundColor: C.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
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
                            _UserAvatar(user: user),
                            const SizedBox(width: 12),
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
                            GestureDetector(
                              onTap: () async {
                                await context.push('/notifications');
                                _fetchNotifCount();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      _notifCount > 0
                                          ? Icons.notifications
                                          : Icons.notifications_outlined,
                                      color: _notifCount > 0
                                          ? C.primary
                                          : C.textSecondary,
                                      size: 26,
                                    ),
                                    if (_notifCount > 0)
                                      Positioned(
                                        right: -5,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: C.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 17,
                                            minHeight: 17,
                                          ),
                                          child: Text(
                                            _notifCount > 99
                                                ? '99+'
                                                : '$_notifCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
                            onDelete: () => _deleteTask(_myTasks[i]),
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
                            onDelete: () => _deleteTask(_familyTasks[i]),
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
                            onDelete: () => _deleteTask(_tomorrowUrgent[i]),
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

  String _formatK(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final total = (karma['karma_total'] ?? 0) as int;
    final daily = (karma['daily_completed'] ?? 0) as int;
    final goal = (karma['daily_goal'] ?? 5) as int;
    final weekly = (karma['weekly_completed'] ?? 0) as int;
    final weeklyGoal = goal * 5;
    final goalReached = goal > 0 && daily >= goal;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [C.primary, Color(0xFFCF3520)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(C.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4DE44232),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.white70, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'KARMA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatK(total)} pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _ProgressRow(
                  label: "Aujourd'hui",
                  current: daily,
                  total: goal,
                ),
                const SizedBox(height: 6),
                _ProgressRow(
                  label: 'Cette semaine',
                  current: weekly,
                  total: weeklyGoal > 0 ? weeklyGoal : 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                goalReached ? '🏆' : '🎯',
                style: const TextStyle(fontSize: 38),
              ),
              if (goalReached) ...[
                const SizedBox(height: 4),
                const Text(
                  'Objectif !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int current;
  final int total;
  const _ProgressRow({
    required this.label,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const Spacer(),
            Text(
              '$current/$total',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 4,
          ),
        ),
      ],
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
  final VoidCallback? onDelete;
  const _TaskTile({
    required this.task,
    required this.priorityColor,
    required this.onToggle,
    this.onDelete,
  });

  String? _dueDateLabel() {
    final s = task['due_date'] as String?;
    if (s == null) return null;
    try {
      final d = DateTime.parse(s);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final taskDate = DateTime(d.year, d.month, d.day);
      final diff = taskDate.difference(todayDate).inDays;
      if (diff == 0) return "Aujourd'hui";
      if (diff == 1) return 'Demain';
      if (diff < 0) return 'En retard';
      return DateFormat('d MMM', 'fr_FR').format(d);
    } catch (_) {
      return null;
    }
  }

  Color _dueDateColor() {
    final s = task['due_date'] as String?;
    if (s == null) return C.textTertiary;
    try {
      final d = DateTime.parse(s);
      final today = DateTime.now();
      final diff = DateTime(d.year, d.month, d.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      if (diff < 0) return C.destructive;
      if (diff == 0) return C.priorityHaute;
    } catch (_) {}
    return C.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final isDone = task['status'] == 'fait';
    final dueDateLabel = _dueDateLabel();
    final dueDateColor = _dueDateColor();
    final familyName = task['family_name'] as String?;
    final assignedName = task['assigned_to_name'] as String?;
    final hasChips =
        dueDateLabel != null || familyName != null || assignedName != null;
    final checkColor =
        priorityColor == C.borderLight ? C.primary : priorityColor;

    return GestureDetector(
      onLongPress: onDelete == null ? null : () {
        HapticFeedback.mediumImpact();
        onDelete!();
      },
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.radiusBase),
        border: Border(
          left: BorderSide(
            color: isDone ? C.borderLight : priorityColor,
            width: 3,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? checkColor : Colors.transparent,
                  border: Border.all(color: checkColor, width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDone ? C.textTertiary : C.textPrimary,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (hasChips) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (dueDateLabel != null)
                          _InfoChip(
                            label: dueDateLabel,
                            icon: Icons.schedule_outlined,
                            color: dueDateColor,
                          ),
                        if (familyName != null)
                          _InfoChip(
                            label: familyName,
                            icon: Icons.group_outlined,
                          ),
                        if (assignedName != null)
                          _InfoChip(
                            label: assignedName,
                            icon: Icons.person_outline,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
    DateTime? eventDate;
    String? dayAbbrev;
    String? dayNum;
    if (event['date'] != null) {
      try {
        eventDate = DateTime.parse(event['date'] as String);
        dayAbbrev = DateFormat('EEE', 'fr_FR').format(eventDate).toUpperCase();
        dayNum = DateFormat('d').format(eventDate);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.radiusBase),
        border: const Border(left: BorderSide(color: C.blue, width: 3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (dayAbbrev != null) ...[
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: C.blueLight,
                  borderRadius: BorderRadius.circular(C.radiusSm),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayAbbrev,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: C.blue,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      dayNum!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: C.blue,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: C.blueLight,
                  borderRadius: BorderRadius.circular(C.radiusSm),
                ),
                child: const Icon(Icons.event, color: C.blue, size: 20),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: C.textPrimary,
                    ),
                  ),
                  if (event['time_from'] != null ||
                      event['family_name'] != null) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (event['time_from'] != null)
                          _InfoChip(
                            label: event['time_from'] as String,
                            icon: Icons.access_time_outlined,
                            color: C.blue,
                          ),
                        if (event['family_name'] != null)
                          _InfoChip(
                            label: event['family_name'] as String,
                            icon: Icons.group_outlined,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(C.radius2xl),
            ),
            child: const Center(
              child: Text('🏖️', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Journée libre !',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: C.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aucune tâche ni événement.\nProfitez-en !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: C.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Planifier quelque chose'),
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(C.radiusBase),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const _InfoChip({required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(C.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: c),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final Map<String, dynamic>? user;
  const _UserAvatar({this.user});

  @override
  Widget build(BuildContext context) {
    final profileImage = user?['profile_image'] as String?;
    final fullName = user?['full_name'] as String? ?? '';
    final initials = fullName
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    if (profileImage != null && profileImage.contains('base64,')) {
      try {
        final bytes = base64Decode(profileImage.split('base64,').last);
        return CircleAvatar(
          radius: 20,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: C.primaryLight,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: C.primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
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
  final _api = ApiClient();
  late String _priority;
  late String _visibility;
  DateTime? _dueDate;
  int? _familyId;
  int? _assignedToId;
  List<Map<String, dynamic>> _familyMembers = [];

  @override
  void initState() {
    super.initState();
    _priority = widget.priority;
    _visibility = widget.visibility;
    _dueDate = widget.dueDate;
    _familyId = widget.familyId;
    _assignedToId = widget.assignedToId;
    _familyMembers = List.from(widget.familyMembers);
  }

  Future<void> _onFamilyChanged(int? fid) async {
    setState(() {
      _familyId = fid;
      _assignedToId = null;
      _familyMembers = [];
    });
    widget.onFamilyChanged(fid);
    widget.onAssignedChanged(null);
    if (fid != null) {
      try {
        final res = await _api.dio.get('/families/$fid/members');
        if (mounted) {
          setState(() {
            _familyMembers = List<Map<String, dynamic>>.from(
              (res.data as List).map((e) => Map<String, dynamic>.from(e)),
            );
          });
        }
      } catch (_) {}
    }
  }

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
                selected: _priority,
                onSelected: (v) {
                  setState(() => _priority = v);
                  widget.onPriorityChanged(v);
                },
              ),
              const SizedBox(height: 12),
              // Visibility
              _SheetLabel(label: 'Visibilité'),
              const SizedBox(height: 6),
              _SegmentedRow(
                items: const [('prive', 'Privée'), ('famille', 'Famille')],
                selected: _visibility,
                onSelected: (v) {
                  setState(() => _visibility = v);
                  widget.onVisibilityChanged(v);
                },
              ),
              const SizedBox(height: 12),
              // Date
              _SheetLabel(label: 'Échéance'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                    widget.onDueDateChanged(picked);
                  }
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
                        _dueDate == null
                            ? 'Aucune date'
                            : DateFormat('EEE d MMM', 'fr_FR').format(_dueDate!),
                        style: TextStyle(
                          fontSize: 14,
                          color: _dueDate == null
                              ? C.textPlaceholder
                              : C.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() => _dueDate = null);
                            widget.onDueDateChanged(null);
                          },
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
              if (_visibility == 'famille' && widget.families.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SheetLabel(label: 'Famille'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _familyId,
                  decoration: const InputDecoration(
                    hintText: 'Choisir une famille',
                  ),
                  items: widget.families.map((f) {
                    return DropdownMenuItem<int>(
                      value: f['id'],
                      child: Text(f['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => _onFamilyChanged(v),
                ),
              ],
              // Assign to member
              if (_familyMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SheetLabel(label: 'Assigner à'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _assignedToId,
                  decoration: const InputDecoration(hintText: 'Non assigné'),
                  items: _familyMembers.map((m) {
                    return DropdownMenuItem<int>(
                      value: m['id'],
                      child: Text(m['full_name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() => _assignedToId = v);
                    widget.onAssignedChanged(v);
                  },
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
  late DateTime _date;
  TimeOfDay? _time;
  int? _familyId;

  @override
  void initState() {
    super.initState();
    _date = widget.date;
    _time = widget.time;
    _familyId = widget.familyId;
  }

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
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                    widget.onDateChanged(picked);
                  }
                },
                child: _DateField(
                  label: DateFormat('EEE d MMMM yyyy', 'fr_FR').format(_date),
                ),
              ),
              const SizedBox(height: 10),
              _SheetLabel(label: 'Heure (optionnel)'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time ?? TimeOfDay.now(),
                  );
                  setState(() => _time = picked);
                  widget.onTimeChanged(picked);
                },
                child: _DateField(
                  label: _time == null
                      ? 'Toute la journée'
                      : _time!.format(context),
                  isPlaceholder: _time == null,
                ),
              ),
              const SizedBox(height: 12),
              _SheetLabel(label: 'Famille *'),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _familyId,
                decoration: const InputDecoration(hintText: 'Choisir une famille'),
                items: widget.families.map((f) {
                  return DropdownMenuItem<int>(
                    value: f['id'],
                    child: Text(f['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() => _familyId = v);
                  widget.onFamilyChanged(v);
                },
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
