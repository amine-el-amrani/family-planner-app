import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

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

  List<dynamic> _getMarkersForDay(DateTime day) {
    return _markerMap[_normalizeDate(day)] ?? [];
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
                      : ListView(
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
                                  )),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: C.textSecondary, size: 19),
                        onPressed: widget.onEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: C.textTertiary, size: 19),
                        onPressed: widget.onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
  const _TaskItem({
    required this.task,
    required this.isCreator,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task['status'] == 'fait';
    final priority = task['priority'] ?? 'normale';
    final borderColor = priority == 'urgente'
        ? const Color(0xFFef4444)
        : priority == 'haute'
            ? const Color(0xFFf97316)
            : C.borderLight;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.radiusBase),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
        subtitle: task['family_name'] != null
            ? Text(
                task['family_name'],
                style:
                    const TextStyle(fontSize: 12, color: C.textSecondary),
              )
            : null,
        trailing: isCreator
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: C.textSecondary, size: 19),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: C.textTertiary, size: 19),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              )
            : null,
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.task['title'] as String? ?? '');
    _priority = widget.task['priority'] as String? ?? 'normale';
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
