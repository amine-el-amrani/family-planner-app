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

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final newStatus = task['status'] == 'fait' ? 'en_attente' : 'fait';
    try {
      await _api.dio.patch('/tasks/${task['id']}', data: {'status': newStatus});
      _loadDayData(_selectedDay);
    } catch (_) {}
  }

  Future<void> _deleteTask(int id) async {
    final confirmed = await _confirmDelete('Supprimer cette tâche ?');
    if (!confirmed) return;
    try {
      await _api.dio.delete('/tasks/$id');
      _loadDayData(_selectedDay);
      _loadMonthData(_focusedDay);
    } catch (_) {}
  }

  Future<void> _deleteEvent(int id) async {
    final confirmed = await _confirmDelete('Supprimer cet événement ?');
    if (!confirmed) return;
    try {
      await _api.dio.delete('/events/$id');
      _loadDayData(_selectedDay);
      _loadMonthData(_focusedDay);
    } catch (_) {}
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
                                    onDelete: () =>
                                        _deleteEvent(e['id'] as int),
                                    onEdit: () => _showEditEvent(e),
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

class _EventItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isCreator;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _EventItem({
    required this.event,
    required this.isCreator,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.radiusBase),
        border: const Border(left: BorderSide(color: C.blue, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: C.blueLight,
            borderRadius: BorderRadius.circular(C.radiusSm),
          ),
          child: const Icon(Icons.event, color: C.blue, size: 18),
        ),
        title: Text(
          event['title'] ?? '',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: C.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event['time_from'] != null)
              Text(
                event['time_from'],
                style: const TextStyle(fontSize: 12, color: C.textSecondary),
              ),
            if (event['family_name'] != null)
              Text(
                event['family_name'],
                style: const TextStyle(fontSize: 12, color: C.textSecondary),
              ),
          ],
        ),
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
              autofocus: true,
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
              autofocus: true,
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
