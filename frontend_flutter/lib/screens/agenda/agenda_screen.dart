import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';


// ─── Predefined task categories (shared with home_screen) ────────────────
const _kCategories = [
  ('Fitness', Color(0xFF22c55e), '🏃'),
  ('Sport', Color(0xFF3b82f6), '⚽'),
  ('Courses', Color(0xFFf59e0b), '🛒'),
  ('Rendez-vous', Color(0xFF8b5cf6), '📅'),
  ('Ménage', Color(0xFF06b6d4), '🧹'),
  ('Cuisine', Color(0xFFef4444), '🍳'),
  ('Famille', Color(0xFFe44232), '👨‍👩‍👧'),
  ('Travail', Color(0xFF64748b), '💼'),
  ('Santé', Color(0xFFf43f5e), '❤️'),
  ('Loisirs', Color(0xFF7c3aed), '🎨'),
];


class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _api = ApiClient();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<dynamic>> _markerMap = {};
  List<Map<String, dynamic>> _dayTasks = [];
  List<Map<String, dynamic>> _dayEvents = [];
  bool _loadingDay = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId =
        context.read<AuthProvider>().user?['id'] as int?;
    _loadMonthData(_focusedDay);
    _loadDayData(_selectedDay);
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadMonthData(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    try {
      final results = await Future.wait([
        _api.dio.get('/tasks/agenda', queryParameters: {
          'start_date': startStr,
          'end_date': endStr,
        }),
        _api.dio.get('/events/my-events', queryParameters: {
          'start_date': startStr,
          'end_date': endStr,
        }),
      ]);
      final Map<DateTime, List<dynamic>> map = {};
      for (final item in (results[0].data as List? ?? [])) {
        try {
          final d = _normalizeDate(
              DateTime.parse(item['due_date'] ?? item['date']));
          map[d] = [...(map[d] ?? []), item];
        } catch (_) {}
      }
      for (final item in (results[1].data as List? ?? [])) {
        try {
          final d = _normalizeDate(DateTime.parse(item['date']));
          map[d] = [...(map[d] ?? []), item];
        } catch (_) {}
      }
      if (mounted) setState(() => _markerMap = map);
    } catch (_) {}
  }

  Future<void> _loadDayData(DateTime day) async {
    setState(() => _loadingDay = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    try {
      final results = await Future.wait([
        _api.dio.get('/tasks/agenda', queryParameters: {
          'start_date': dateStr,
          'end_date': dateStr,
        }),
        _api.dio.get('/events/my-events', queryParameters: {
          'start_date': dateStr,
          'end_date': dateStr,
        }),
      ]);
      if (mounted) {
        setState(() {
          _dayTasks = List<Map<String, dynamic>>.from(
            (results[0].data as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)),
          );
          _dayEvents = List<Map<String, dynamic>>.from(
            (results[1].data as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)),
          );
          _loadingDay = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDay = false);
    }
  }

  Future<void> _handleRsvp(int eventId, String status) async {
    try {
      await _api.dio.patch('/events/$eventId/rsvp', data: {'status': status});
      await _loadDayData(_selectedDay);
    } catch (_) {}
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final newStatus = task['status'] == 'fait' ? 'en_attente' : 'fait';
    // Optimistic update — flip immediately
    final idx = _dayTasks.indexWhere((t) => t['id'] == task['id']);
    if (idx != -1) {
      final updated = Map<String, dynamic>.from(task);
      updated['status'] = newStatus;
      setState(() => _dayTasks[idx] = updated);
    }
    try {
      await _api.dio.patch('/tasks/${task['id']}', data: {'status': newStatus});
    } catch (_) {
      // Revert on failure
      if (idx != -1 && mounted) setState(() => _dayTasks[idx] = task);
    }
  }

  Future<void> _deleteTask(int id) async {
    final confirmed = await _confirmDelete('Supprimer cette tâche ?');
    if (!confirmed) return;
    // Optimistic removal
    final taskIdx = _dayTasks.indexWhere((t) => t['id'] == id);
    final taskData = taskIdx != -1 ? Map<String, dynamic>.from(_dayTasks[taskIdx]) : null;
    if (taskIdx != -1) setState(() => _dayTasks.removeAt(taskIdx));
    try {
      await _api.dio.delete('/tasks/$id');
      _loadMonthData(_focusedDay); // refresh markers in background
    } catch (_) {
      // Revert on failure
      if (taskData != null && mounted) setState(() => _dayTasks.insert(taskIdx, taskData));
    }
  }

  Future<void> _deleteEvent(int id) async {
    final confirmed = await _confirmDelete('Supprimer cet événement ?');
    if (!confirmed) return;
    // Optimistic removal
    final eventIdx = _dayEvents.indexWhere((e) => e['id'] == id);
    final eventData = eventIdx != -1 ? Map<String, dynamic>.from(_dayEvents[eventIdx]) : null;
    if (eventIdx != -1) setState(() => _dayEvents.removeAt(eventIdx));
    try {
      await _api.dio.delete('/events/$id');
      _loadMonthData(_focusedDay); // refresh markers in background
    } catch (_) {
      // Revert on failure
      if (eventData != null && mounted) setState(() => _dayEvents.insert(eventIdx, eventData));
    }
  }

  Future<bool> _confirmDelete(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text(message),
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
    return result ?? false;
  }


  void _showAddForDay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickAddForDaySheet(
        selectedDay: _selectedDay,
        onCreated: () {
          _loadDayData(_selectedDay);
          _loadMonthData(_focusedDay);
        },
      ),
    );
  }

  void _showEditTask(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditTaskSheet(
        task: task,
        onSave: (data) async {
          await _api.dio.patch('/tasks/${task['id']}', data: data);
          if (mounted) {
            _loadDayData(_selectedDay);
            _loadMonthData(_focusedDay);
          }
        },
      ),
    );
  }

  void _showEventDetail(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EventDetailSheet(event: event),
    );
  }

  void _showEditEvent(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditEventSheet(
        event: event,
        onSave: (data) async {
          await _api.dio.put('/events/${event['id']}', data: data);
          if (mounted) {
            _loadDayData(_selectedDay);
            _loadMonthData(_focusedDay);
          }
        },
      ),
    );
  }

  void _showTaskDetail(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskDetailSheet(task: task),
    );
  }

  List<dynamic> _getMarkersForDay(DateTime day) {
    return _markerMap[_normalizeDate(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddForDay,
        backgroundColor: C.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: const [
                  Text(
                    'Agenda',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: C.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Calendar
            TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Mois',
                CalendarFormat.twoWeeks: '2 semaines',
                CalendarFormat.week: 'Semaine',
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'fr_FR',
              eventLoader: _getMarkersForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadDayData(selectedDay);
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadMonthData(focusedDay);
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                  color: C.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: C.primaryLight,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: C.primary,
                  fontWeight: FontWeight.w700,
                ),
                markerDecoration: const BoxDecoration(
                  color: C.primary,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                outsideDaysVisible: false,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  color: C.primaryLight,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                formatButtonTextStyle: TextStyle(
                  color: C.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                titleTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
                leftChevronIcon:
                    Icon(Icons.chevron_left, color: C.textSecondary),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: C.textSecondary),
              ),
            ),

            const Divider(height: 1),

            // Day header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDay),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: C.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Day content
            Expanded(
              child: _loadingDay
                  ? const Center(
                      child: CircularProgressIndicator(color: C.primary),
                    )
                  : _dayTasks.isEmpty && _dayEvents.isEmpty
                      ? _EmptyDay()
                      : RefreshIndicator(
                          onRefresh: () => _loadDayData(_selectedDay),
                          color: C.primary,
                          child: ListView(
                          padding: const EdgeInsets.only(bottom: 20),
                          children: [
                            if (_dayEvents.isNotEmpty) ...[
                              _DaySection(label: 'ÉVÉNEMENTS'),
                              ..._dayEvents.map((e) => _EventItem(
                                    event: e,
                                    isCreator:
                                        e['created_by_id'] == _currentUserId,
                                    currentUserId: _currentUserId,
                                    onDelete: () =>
                                        _deleteEvent(e['id'] as int),
                                    onEdit: () => _showEditEvent(e),
                                    onRsvp: _handleRsvp,
                                    onTap: () => _showEventDetail(e),
                                  )),
                            ],
                            if (_dayTasks.isNotEmpty) ...[
                              _DaySection(label: 'TÂCHES'),
                              ..._dayTasks.map((t) => _TaskItem(
                                    task: t,
                                    isCreator:
                                        t['created_by_id'] == _currentUserId,
                                    onToggle: () => _toggleTask(t),
                                    onDelete: () =>
                                        _deleteTask(t['id'] as int),
                                    onEdit: () => _showEditTask(t),
                                    onTap: () => _showTaskDetail(t),
                                  )),
                            ],
                          ],
                        ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  final String label;
  const _DaySection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: C.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Event item ───────────────────────────────────────────────────────────────

class _EventItem extends StatefulWidget {
  final Map<String, dynamic> event;
  final bool isCreator;
  final int? currentUserId;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Future<void> Function(int eventId, String status) onRsvp;
  final VoidCallback onTap;

  const _EventItem({
    required this.event,
    required this.isCreator,
    required this.currentUserId,
    required this.onDelete,
    required this.onEdit,
    required this.onRsvp,
    required this.onTap,
  });

  @override
  State<_EventItem> createState() => _EventItemState();
}

class _EventItemState extends State<_EventItem> {
  bool _rsvpLoading = false;

  String? get _myStatus {
    final attendees = widget.event['attendees'] as List? ?? [];
    for (final a in attendees) {
      final map = a as Map;
      if (map['user_id'] == widget.currentUserId) {
        return map['status'] as String?;
      }
    }
    return null;
  }

  Future<void> _setRsvp(String status) async {
    if (_rsvpLoading) return;
    setState(() => _rsvpLoading = true);
    try {
      await widget.onRsvp(widget.event['id'] as int, status);
    } finally {
      if (mounted) setState(() => _rsvpLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goingCount = widget.event['going_count'] as int? ?? 0;
    final notGoingCount = widget.event['not_going_count'] as int? ?? 0;
    final pendingCount = widget.event['pending_count'] as int? ?? 0;
    final hasAttendees = (goingCount + notGoingCount + pendingCount) > 0;
    final myStatus = _myStatus;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.radiusBase),
        border: const Border(left: BorderSide(color: C.blue, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.blueLight,
                    borderRadius: BorderRadius.circular(C.radiusSm),
                  ),
                  child: const Icon(Icons.event, color: C.blue, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: C.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.event['time_from'] != null) ...[
                            Text(
                              widget.event['time_from'],
                              style: const TextStyle(fontSize: 12, color: C.textSecondary),
                            ),
                            const Text(' · ', style: TextStyle(fontSize: 12, color: C.textTertiary)),
                          ],
                          if (widget.event['family_name'] != null)
                            Text(
                              widget.event['family_name'],
                              style: const TextStyle(fontSize: 12, color: C.textSecondary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.isCreator)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: C.textTertiary, size: 18),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(C.radiusBase),
                    ),
                    onSelected: (val) {
                      if (val == 'edit') widget.onEdit();
                      if (val == 'delete') widget.onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 16, color: C.textSecondary),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 16, color: C.destructive),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: C.destructive)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ),

            // RSVP section — only shown when there are attendees
            if (hasAttendees) ...[
              const SizedBox(height: 8),
              // Attendance counts
              Row(
                children: [
                  if (goingCount > 0) ...[
                    const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF22c55e)),
                    const SizedBox(width: 3),
                    Text(
                      '$goingCount',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF22c55e), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (notGoingCount > 0) ...[
                    const Icon(Icons.cancel_outlined, size: 13, color: C.destructive),
                    const SizedBox(width: 3),
                    Text(
                      '$notGoingCount',
                      style: const TextStyle(fontSize: 12, color: C.destructive, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (pendingCount > 0) ...[
                    const Icon(Icons.schedule, size: 13, color: C.textTertiary),
                    const SizedBox(width: 3),
                    Text(
                      '$pendingCount en attente',
                      style: const TextStyle(fontSize: 12, color: C.textTertiary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // RSVP action buttons
              if (_rsvpLoading)
                const SizedBox(
                  height: 28,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: C.primary),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    _RsvpButton(
                      label: 'Je serai là',
                      icon: Icons.check,
                      isSelected: myStatus == 'going',
                      activeColor: const Color(0xFF22c55e),
                      // Tap again to toggle back to pending
                      onTap: () => _setRsvp(myStatus == 'going' ? 'pending' : 'going'),
                    ),
                    const SizedBox(width: 8),
                    _RsvpButton(
                      label: 'Non dispo',
                      icon: Icons.close,
                      isSelected: myStatus == 'not_going',
                      activeColor: C.destructive,
                      onTap: () => _setRsvp(myStatus == 'not_going' ? 'pending' : 'not_going'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

// ─── RSVP button ──────────────────────────────────────────────────────────────

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : C.surfaceAlt,
          borderRadius: BorderRadius.circular(C.radiusFull),
          border: Border.all(
            color: isSelected ? activeColor : C.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? activeColor : C.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? activeColor : C.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Task item ────────────────────────────────────────────────────────────────

class _TaskItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isCreator;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onTap;
  const _TaskItem({
    required this.task,
    required this.isCreator,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task['status'] == 'fait';
    final priority = task['priority'] ?? 'normale';
    final priorityColor = priority == 'urgente'
        ? C.priorityUrgente
        : priority == 'haute'
            ? C.priorityHaute
            : C.borderLight;
    final checkColor = priorityColor == C.borderLight ? C.primary : priorityColor;
    final familyName = task['family_name'] as String?;
    final assignedName = task['assigned_to_name'] as String?;

    return GestureDetector(
      onTap: onTap,
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
            BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (familyName != null || assignedName != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (familyName != null)
                            _AgendaChip(label: familyName, icon: Icons.group_outlined),
                          if (assignedName != null)
                            _AgendaChip(label: assignedName, icon: Icons.person_outline),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isCreator)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: C.textTertiary, size: 18),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(C.radiusBase),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16, color: C.textSecondary),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 16, color: C.destructive),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: C.destructive)),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Edit Task sheet ──────────────────────────────────────────────────────────

class _EditTaskSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final Future<void> Function(Map<String, dynamic> data) onSave;
  const _EditTaskSheet({required this.task, required this.onSave});

  @override
  State<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<_EditTaskSheet> {
  late TextEditingController _titleCtrl;
  late String _priority;
  DateTime? _dueDate;
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.task['title'] as String? ?? '');
    _priority = widget.task['priority'] as String? ?? 'normale';
    _category = widget.task['category'] as String?;
    final raw = widget.task['due_date'] as String?;
    if (raw != null) {
      try {
        _dueDate = DateTime.parse(raw);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'priority': _priority,
        if (_dueDate != null)
          'due_date': DateFormat('yyyy-MM-dd').format(_dueDate!),
        if (_category != null)
          'category': _category,
      };
      await widget.onSave(data);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la modification'),
          backgroundColor: C.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              'Modifier la tâche',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: C.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 14),
            // Priority chips
            Wrap(
              spacing: 8,
              children: [
                for (final p in ['normale', 'haute', 'urgente'])
                  ChoiceChip(
                    label: Text(p == 'normale'
                        ? 'Normale'
                        : p == 'haute'
                            ? 'Haute'
                            : 'Urgente'),
                    selected: _priority == p,
                    selectedColor: p == 'urgente'
                        ? const Color(0xFFfee2e2)
                        : p == 'haute'
                            ? const Color(0xFFffedd5)
                            : C.primaryLight,
                    onSelected: (_) => setState(() => _priority = p),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Due date
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                _dueDate != null
                    ? DateFormat('EEE d MMM', 'fr_FR').format(_dueDate!)
                    : 'Date d\'échéance',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Catégorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _kCategories.map((cat) {
                final selected = _category == cat.$1;
                return GestureDetector(
                  onTap: () => setState(() => _category = selected ? null : cat.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? cat.$2.withValues(alpha: 0.15) : C.surfaceAlt,
                      borderRadius: BorderRadius.circular(C.radiusFull),
                      border: Border.all(color: selected ? cat.$2 : C.border, width: 1.2),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(cat.$3, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(cat.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? cat.$2 : C.textSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sauvegarder'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Event sheet ─────────────────────────────────────────────────────────

class _EditEventSheet extends StatefulWidget {
  final Map<String, dynamic> event;
  final Future<void> Function(Map<String, dynamic> data) onSave;
  const _EditEventSheet({required this.event, required this.onSave});

  @override
  State<_EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<_EditEventSheet> {
  late TextEditingController _titleCtrl;
  DateTime? _eventDate;
  TimeOfDay? _timeFrom;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.event['title'] as String? ?? '');
    final rawDate = widget.event['date'] as String?;
    if (rawDate != null) {
      try {
        _eventDate = DateTime.parse(rawDate);
      } catch (_) {}
    }
    final rawTime = widget.event['time_from'] as String?;
    if (rawTime != null) {
      try {
        final parts = rawTime.split(':');
        _timeFrom = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _eventDate == null) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'event_date': DateFormat('yyyy-MM-dd').format(_eventDate!),
        if (_timeFrom != null)
          'time_from':
              '${_timeFrom!.hour.toString().padLeft(2, '0')}:${_timeFrom!.minute.toString().padLeft(2, '0')}',
      };
      await widget.onSave(data);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la modification'),
          backgroundColor: C.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) setState(() => _eventDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _timeFrom ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _timeFrom = t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              'Modifier l\'événement',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: C.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon:
                        const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      _eventDate != null
                          ? DateFormat('EEE d MMM', 'fr_FR')
                              .format(_eventDate!)
                          : 'Date',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_outlined, size: 16),
                    label: Text(
                      _timeFrom != null
                          ? _timeFrom!.format(context)
                          : 'Heure',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sauvegarder'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Event detail sheet ───────────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventDetailSheet({required this.event});

  @override
  Widget build(BuildContext context) {
    final attendees = event['attendees'] as List? ?? [];
    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            // Title
            Text(
              event['title'] ?? '',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: C.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            // Date + time
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: C.textSecondary),
                const SizedBox(width: 6),
                Text(
                  event['date'] ?? '',
                  style: const TextStyle(fontSize: 14, color: C.textSecondary),
                ),
                if (event['time_from'] != null) ...[
                  const Text(' · ', style: TextStyle(color: C.textTertiary)),
                  const Icon(Icons.access_time_outlined, size: 14, color: C.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    event['time_from'],
                    style: const TextStyle(fontSize: 14, color: C.textSecondary),
                  ),
                ],
              ],
            ),
            if (event['family_name'] != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.group_outlined, size: 14, color: C.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    event['family_name'],
                    style: const TextStyle(fontSize: 14, color: C.textSecondary),
                  ),
                ],
              ),
            ],
            if (event['created_by'] != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: C.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Par ${event['created_by']}',
                    style: const TextStyle(fontSize: 14, color: C.textSecondary),
                  ),
                ],
              ),
            ],
            if (event['description'] != null &&
                (event['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                event['description'],
                style: const TextStyle(fontSize: 14, color: C.textPrimary, height: 1.4),
              ),
            ],
            if (attendees.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                'PARTICIPANTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: C.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ...attendees.map((a) {
                final map = a as Map;
                final status = map['status'] as String? ?? 'pending';
                final icon = status == 'going'
                    ? Icons.check_circle
                    : status == 'not_going'
                        ? Icons.cancel
                        : Icons.schedule;
                final color = status == 'going'
                    ? const Color(0xFF22c55e)
                    : status == 'not_going'
                        ? C.destructive
                        : C.textTertiary;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 10),
                      Text(
                        map['user_name'] ?? '',
                        style: const TextStyle(fontSize: 14, color: C.textPrimary),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.calendar_today_outlined,
              size: 40, color: C.textTertiary),
          SizedBox(height: 12),
          Text(
            'Rien pour ce jour',
            style: TextStyle(fontSize: 15, color: C.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Task detail sheet ────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final Map<String, dynamic> task;
  const _TaskDetailSheet({required this.task});

  @override
  Widget build(BuildContext context) {
    final priority = task['priority'] ?? 'normale';
    final priorityColor = priority == 'urgente'
        ? C.priorityUrgente
        : priority == 'haute'
            ? C.priorityHaute
            : C.textTertiary;
    final priorityLabel = priority == 'urgente'
        ? 'Urgente'
        : priority == 'haute'
            ? 'Haute'
            : 'Normale';
    final isDone = task['status'] == 'fait';
    final dueDate = task['due_date'] as String?;

    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            // Status + priority chips
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDone ? C.primaryLight : C.surfaceAlt,
                    borderRadius: BorderRadius.circular(C.radiusFull),
                    border: Border.all(color: isDone ? C.primary : C.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 12,
                        color: isDone ? C.primary : C.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDone ? 'Terminée' : 'En cours',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDone ? C.primary : C.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(C.radiusFull),
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              task['title'] ?? '',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDone ? C.textSecondary : C.textPrimary,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            if (task['description'] != null &&
                (task['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                task['description'] as String,
                style: const TextStyle(
                    fontSize: 14, color: C.textSecondary, height: 1.4),
              ),
            ],
            const SizedBox(height: 14),
            if (dueDate != null) ...[
              _AgendaDetailRow(
                icon: Icons.calendar_today_outlined,
                text: () {
                  try {
                    final d = DateTime.parse(dueDate);
                    return DateFormat('EEE d MMMM yyyy', 'fr_FR').format(d);
                  } catch (_) {
                    return dueDate;
                  }
                }(),
              ),
            ],
            if (task['family_name'] != null) ...[
              const SizedBox(height: 8),
              _AgendaDetailRow(
                icon: Icons.group_outlined,
                text: task['family_name'] as String,
              ),
            ],
            if (task['assigned_to_name'] != null) ...[
              const SizedBox(height: 8),
              _AgendaDetailRow(
                icon: Icons.person_outline,
                text: 'Assignée à ${task['assigned_to_name']}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgendaDetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AgendaDetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: C.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 14, color: C.textSecondary)),
      ],
    );
  }
}

class _AgendaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _AgendaChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: C.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(C.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: C.textTertiary),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: C.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Add For Day Sheet ──────────────────────────────────────────────────

class _QuickAddForDaySheet extends StatefulWidget {
  final DateTime selectedDay;
  final VoidCallback onCreated;
  const _QuickAddForDaySheet({required this.selectedDay, required this.onCreated});

  @override
  State<_QuickAddForDaySheet> createState() => _QuickAddForDaySheetState();
}

class _QuickAddForDaySheetState extends State<_QuickAddForDaySheet> {
  final _api = ApiClient();
  final _titleCtrl = TextEditingController();
  List<Map<String, dynamic>> _families = [];
  int? _familyId;
  String _type = 'task';
  String _priority = 'normale';
  TimeOfDay? _eventTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchFamilies();
  }

  Future<void> _fetchFamilies() async {
    try {
      final res = await _api.dio.get('/families/');
      if (mounted) {
        setState(() {
          _families = List<Map<String, dynamic>>.from(
            (res.data as List).map((e) => Map<String, dynamic>.from(e)),
          );
          if (_families.isNotEmpty) _familyId = _families.first['id'] as int;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDay);
    try {
      if (_type == 'task') {
        await _api.dio.post('/tasks/', data: {
          'title': _titleCtrl.text.trim(),
          'priority': _priority,
          'due_date': dateStr,
          'visibility': _familyId != null ? 'famille' : 'prive',
          if (_familyId != null) 'family_id': _familyId,
        });
      } else {
        if (_familyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Choisissez une famille pour cet événement'),
            behavior: SnackBarBehavior.floating,
          ));
          setState(() => _saving = false);
          return;
        }
        String? timeStr;
        if (_eventTime != null) {
          final h = _eventTime!.hour.toString().padLeft(2, '0');
          final m = _eventTime!.minute.toString().padLeft(2, '0');
          timeStr = '$h:$m';
        }
        await _api.dio.post('/events/', data: {
          'title': _titleCtrl.text.trim(),
          'event_date': dateStr,
          'family_id': _familyId,
          if (timeStr != null) 'time_from': timeStr,
        });
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la création'),
          backgroundColor: C.destructive,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: C.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat('EEEE d MMMM', 'fr_FR').format(widget.selectedDay),
              style: const TextStyle(
                  fontSize: 13,
                  color: C.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TypeToggleButton(
                    label: 'Tâche',
                    icon: Icons.check_circle_outline,
                    isSelected: _type == 'task',
                    color: C.primary,
                    onTap: () => setState(() => _type = 'task'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeToggleButton(
                    label: 'Événement',
                    icon: Icons.event_outlined,
                    isSelected: _type == 'event',
                    color: C.blue,
                    onTap: () => setState(() => _type = 'event'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _type == 'task'
                    ? 'Titre de la tâche'
                    : "Titre de l'événement",
              ),
            ),
            if (_type == 'task') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in [
                    ('normale', 'Normale'),
                    ('haute', 'Haute'),
                    ('urgente', 'Urgente'),
                  ])
                    GestureDetector(
                      onTap: () => setState(() => _priority = p.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _priority == p.$1 ? C.primary : C.surfaceAlt,
                          borderRadius: BorderRadius.circular(C.radiusFull),
                          border: Border.all(
                            color: _priority == p.$1 ? C.primary : C.border,
                          ),
                        ),
                        child: Text(
                          p.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _priority == p.$1
                                ? Colors.white
                                : C.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (_type == 'event') ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _eventTime ?? TimeOfDay.now(),
                  );
                  if (t != null) setState(() => _eventTime = t);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: C.surfaceAlt,
                    borderRadius: BorderRadius.circular(C.radiusBase),
                    border: Border.all(color: C.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_outlined,
                          size: 16, color: C.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        _eventTime == null
                            ? 'Toute la journée'
                            : _eventTime!.format(context),
                        style: TextStyle(
                          fontSize: 14,
                          color: _eventTime == null
                              ? C.textPlaceholder
                              : C.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_families.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _familyId,
                decoration: InputDecoration(
                  hintText:
                      _type == 'task' ? 'Famille (optionnel)' : 'Famille *',
                ),
                items: _families
                    .map((f) => DropdownMenuItem<int>(
                          value: f['id'] as int,
                          child: Text(f['name'] ?? ''),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _familyId = v),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _type == 'task' ? C.primary : C.blue,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_type == 'task'
                      ? 'Ajouter la tâche'
                      : "Créer l'événement"),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const _TypeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : C.surfaceAlt,
          borderRadius: BorderRadius.circular(C.radiusBase),
          border: Border.all(
              color: isSelected ? color : C.border, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? color : C.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : C.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
