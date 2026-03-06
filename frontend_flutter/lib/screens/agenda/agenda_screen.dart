import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
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

  Map<DateTime, List<dynamic>> _events = {};
  List<Map<String, dynamic>> _dayTasks = [];
  List<Map<String, dynamic>> _dayEvents = [];
  bool _loadingDay = false;

  @override
  void initState() {
    super.initState();
    _loadMonthData(_focusedDay);
    _loadDayData(_selectedDay);
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadMonthData(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    try {
      final res = await _api.dio.get('/tasks/agenda', queryParameters: {
        'start_date': DateFormat('yyyy-MM-dd').format(start),
        'end_date': DateFormat('yyyy-MM-dd').format(end),
      });
      final Map<DateTime, List<dynamic>> map = {};
      for (final item in (res.data as List? ?? [])) {
        try {
          final d = _normalizeDate(DateTime.parse(item['date']));
          map[d] = [...(map[d] ?? []), item];
        } catch (_) {}
      }
      if (mounted) setState(() => _events = map);
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
        _api.dio.get('/events/', queryParameters: {'date': dateStr}),
      ]);
      setState(() {
        _dayTasks = List<Map<String, dynamic>>.from(
          (results[0].data as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e)),
        );
        _dayEvents = List<Map<String, dynamic>>.from(
          (results[1].data as List? ?? [])
              .where((e) => e['date'] == dateStr)
              .map((e) => Map<String, dynamic>.from(e)),
        );
        _loadingDay = false;
      });
    } catch (_) {
      setState(() => _loadingDay = false);
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final newStatus = task['status'] == 'fait' ? 'en_attente' : 'fait';
    try {
      await _api.dio.patch('/tasks/${task['id']}', data: {'status': newStatus});
      _loadDayData(_selectedDay);
    } catch (_) {}
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
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
              eventLoader: _getEventsForDay,
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
                leftChevronIcon: Icon(Icons.chevron_left, color: C.textSecondary),
                rightChevronIcon: Icon(Icons.chevron_right, color: C.textSecondary),
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
                            // Events
                            if (_dayEvents.isNotEmpty) ...[
                              _DaySection(label: 'ÉVÉNEMENTS'),
                              ..._dayEvents.map(
                                (e) => _EventItem(event: e),
                              ),
                            ],
                            // Tasks
                            if (_dayTasks.isNotEmpty) ...[
                              _DaySection(label: 'TÂCHES'),
                              ..._dayTasks.map(
                                (t) => _TaskItem(
                                  task: t,
                                  onToggle: () => _toggleTask(t),
                                ),
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

class _EventItem extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventItem({required this.event});

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
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        subtitle: event['time_from'] != null
            ? Text(
                event['time_from'],
                style: const TextStyle(fontSize: 12, color: C.textSecondary),
              )
            : null,
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onToggle;
  const _TaskItem({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDone = task['status'] == 'fait';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(C.radiusBase),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
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
        subtitle: task['family_name'] != null
            ? Text(
                task['family_name'],
                style:
                    const TextStyle(fontSize: 12, color: C.textSecondary),
              )
            : null,
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.calendar_today_outlined, size: 40, color: C.textTertiary),
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
