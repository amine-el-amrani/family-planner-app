import React, { useContext, useState, useEffect, useCallback } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  ActivityIndicator, Alert, Platform, TextInput as RNTextInput,
  Modal, KeyboardAvoidingView, Pressable, Keyboard,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Calendar } from 'react-native-calendars';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { FAB } from 'react-native-paper';
import DateTimePicker from '@react-native-community/datetimepicker';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { C } from '../theme/colors';
import { useFocusEffect } from '@react-navigation/native';

// ─── Types ───────────────────────────────────────────────────────────────────

type CalendarEvent = {
  id: number;
  title: string;
  description?: string;
  date: string;
  time_from?: string;
  time_to?: string;
  family_name?: string;
  family_id?: number;
  created_by_id?: number;
  created_by?: string;
};

type CalendarTask = {
  id: number;
  title: string;
  description?: string;
  status: 'en_attente' | 'fait' | 'annule';
  priority: 'normale' | 'haute' | 'urgente';
  due_date: string;
  visibility: 'prive' | 'famille';
  family_name?: string;
  family_id?: number;
  assigned_to_name?: string;
  assigned_to_id?: number;
  created_by_id: number;
  created_by_name: string;
};

type EventTask = {
  id: number;
  title: string;
  status: 'en_attente' | 'fait' | 'annule';
  assigned_to_name?: string;
  assigned_to_id?: number;
  created_by_id: number;
};

type MarkedDates = {
  [date: string]: {
    dots?: Array<{ key: string; color: string }>;
    selected?: boolean;
    selectedColor?: string;
  };
};

type Family = { id: number; name: string };
type Member = { id: number; full_name: string; email: string };

// ─── Templates ───────────────────────────────────────────────────────────────

const TASK_TEMPLATES: Array<{ icon: string; label: string; title: string }> = [
  { icon: 'dog', label: 'Chien', title: 'Sortir le chien' },
  { icon: 'delete-outline', label: 'Poubelle', title: 'Sortir la poubelle' },
  { icon: 'cart-outline', label: 'Courses', title: 'Faire les courses' },
  { icon: 'broom', label: 'Ménage', title: 'Faire le ménage' },
  { icon: 'dumbbell', label: 'Sport', title: 'Faire du sport' },
  { icon: 'pot-steam-outline', label: 'Cuisine', title: 'Préparer le repas' },
  { icon: 'washing-machine', label: 'Lessive', title: 'Faire la lessive' },
  { icon: 'car-wash', label: 'Voiture', title: 'Laver la voiture' },
];

const EVENT_TEMPLATES: Array<{ icon: string; label: string; title: string }> = [
  { icon: 'cake-variant', label: 'Anniversaire', title: 'Anniversaire' },
  { icon: 'map-marker-outline', label: 'Sortie', title: 'Sortie en famille' },
  { icon: 'walk', label: 'Balade', title: 'Balade' },
  { icon: 'tent', label: 'Camping', title: 'Weekend camping' },
  { icon: 'party-popper', label: 'Fête', title: 'Fête' },
  { icon: 'silverware-fork-knife', label: 'Repas', title: 'Repas en famille' },
  { icon: 'movie-outline', label: 'Cinéma', title: 'Cinéma' },
  { icon: 'airplane', label: 'Voyage', title: 'Voyage' },
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatMonth(year: number, month: number): { start: string; end: string } {
  const pad = (n: number) => String(n).padStart(2, '0');
  const start = `${year}-${pad(month)}-01`;
  const lastDay = new Date(year, month, 0).getDate();
  const end = `${year}-${pad(month)}-${lastDay}`;
  return { start, end };
}

function todayString(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const MOIS_FR = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

function parseDateLabel(dateStr: string): string {
  const [y, m, d] = dateStr.split('-');
  return `${parseInt(d)} ${MOIS_FR[parseInt(m) - 1]} ${y}`;
}

function statusLabel(status: string): { label: string; color: string } {
  if (status === 'fait') return { label: 'Fait', color: '#22c55e' };
  if (status === 'annule') return { label: 'Annulé', color: C.textTertiary };
  return { label: 'À faire', color: C.primary };
}

const PRIORITY_COLORS: Record<string, string> = {
  urgente: '#ef4444', haute: '#f97316', normale: C.borderLight,
};

const PRIORITY_ACTIVE: Record<string, string> = {
  urgente: '#ef4444', haute: '#f97316', normale: C.primary,
};

function parseDateToObj(dateStr: string): Date {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function formatDateFromObj(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function formatTimeFromObj(d: Date): string {
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function parseTimeStr(timeStr: string): Date {
  const [h, m] = timeStr.split(':').map(Number);
  const d = new Date();
  d.setHours(h, m, 0, 0);
  return d;
}

// ─── DatePickerField ──────────────────────────────────────────────────────────

type DatePickerFieldProps = {
  value: Date | null;
  onChange: (d: Date) => void;
  mode: 'date' | 'time';
  placeholder: string;
  clearable?: boolean;
  onClear?: () => void;
  iconName?: string;
};

function DatePickerField({ value, onChange, mode, placeholder, clearable, onClear, iconName }: DatePickerFieldProps) {
  const [show, setShow] = useState(false);
  const [iosTemp, setIosTemp] = useState<Date>(value || new Date());

  const displayValue = value
    ? mode === 'date'
      ? formatDateFromObj(value)
      : formatTimeFromObj(value)
    : null;

  const icon = iconName || (mode === 'date' ? 'calendar-outline' : 'clock-outline');

  return (
    <>
      <TouchableOpacity style={styles.dateBtn} onPress={() => { setIosTemp(value || new Date()); setShow(true); }}>
        <MaterialCommunityIcons name={icon as any} size={18} color={C.primary} />
        <Text style={[styles.dateBtnText, { flex: 1, color: displayValue ? C.primary : C.textPlaceholder }]}>
          {displayValue || placeholder}
        </Text>
        {clearable && value && onClear && (
          <TouchableOpacity onPress={onClear} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
            <MaterialCommunityIcons name="close-circle" size={16} color={C.textTertiary} />
          </TouchableOpacity>
        )}
      </TouchableOpacity>
      {show && Platform.OS === 'ios' && (
        <View style={styles.iosPickerWrap}>
          <DateTimePicker
            value={iosTemp}
            mode={mode}
            display="spinner"
            textColor="#1a1a1a"
            onChange={(_, d) => { if (d) setIosTemp(d); }}
          />
          <TouchableOpacity style={styles.iosPickerConfirm} onPress={() => { onChange(iosTemp); setShow(false); }}>
            <Text style={styles.iosPickerConfirmText}>Confirmer</Text>
          </TouchableOpacity>
        </View>
      )}
      {show && Platform.OS === 'android' && (
        <DateTimePicker
          value={value || new Date()}
          mode={mode}
          display="default"
          onChange={(_, d) => { setShow(false); if (d) onChange(d); }}
        />
      )}
    </>
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

export default function AgendaScreen() {
  const { token } = useContext(AuthContext);
  const headers = { Authorization: `Bearer ${token}` };

  const today = todayString();
  const [selectedDate, setSelectedDate] = useState(today);
  const [markedDates, setMarkedDates] = useState<MarkedDates>({});
  const [currentMonth, setCurrentMonth] = useState({
    year: new Date().getFullYear(),
    month: new Date().getMonth() + 1,
  });

  const [dayEvents, setDayEvents] = useState<CalendarEvent[]>([]);
  const [dayTasks, setDayTasks] = useState<CalendarTask[]>([]);
  const [loadingMonth, setLoadingMonth] = useState(false);
  const [loadingDay, setLoadingDay] = useState(false);

  const [currentUserId, setCurrentUserId] = useState<number | null>(null);
  useEffect(() => {
    api.get('/users/me', { headers }).then(r => setCurrentUserId(r.data.id)).catch(() => {});
  }, [token]);

  // Detail modal (single click)
  const [detailItem, setDetailItem] = useState<{ type: 'task' | 'event'; item: any } | null>(null);

  // Event tasks (inside event detail)
  const [eventTasks, setEventTasks] = useState<EventTask[]>([]);
  const [eventTaskMembers, setEventTaskMembers] = useState<Member[]>([]);
  const [newEventTaskTitle, setNewEventTaskTitle] = useState('');
  const [newEventTaskAssigneeId, setNewEventTaskAssigneeId] = useState<number | null>(null);
  const [creatingEventTask, setCreatingEventTask] = useState(false);
  const [loadingEventTasks, setLoadingEventTasks] = useState(false);

  // Action sheet (3-dot / long press)
  const [actionItem, setActionItem] = useState<{ type: 'task' | 'event'; item: any } | null>(null);
  const [editMode, setEditMode] = useState(false);

  // Edit task
  const [editTaskTitle, setEditTaskTitle] = useState('');
  const [editTaskDueDateObj, setEditTaskDueDateObj] = useState<Date>(new Date());
  const [editTaskPriority, setEditTaskPriority] = useState<'normale' | 'haute' | 'urgente'>('normale');
  const [savingEdit, setSavingEdit] = useState(false);

  // Edit event
  const [editEventTitle, setEditEventTitle] = useState('');
  const [editEventDateObj, setEditEventDateObj] = useState<Date>(new Date());
  const [editEventTimeObj, setEditEventTimeObj] = useState<Date | null>(null);
  const [editEventDesc, setEditEventDesc] = useState('');
  const [editEventFamilyId, setEditEventFamilyId] = useState<number | null>(null);

  // Create choice
  const [createChoiceVisible, setCreateChoiceVisible] = useState(false);

  // Create task
  const [createTaskVisible, setCreateTaskVisible] = useState(false);
  const [newTaskTitle, setNewTaskTitle] = useState('');
  const [newTaskVisibility, setNewTaskVisibility] = useState<'prive' | 'famille'>('prive');
  const [newTaskPriority, setNewTaskPriority] = useState<'normale' | 'haute' | 'urgente'>('normale');
  const [newTaskFamilyId, setNewTaskFamilyId] = useState<number | null>(null);
  const [newTaskAssigneeId, setNewTaskAssigneeId] = useState<number | null>(null);
  const [creatingTask, setCreatingTask] = useState(false);

  // Create event
  const [createEventVisible, setCreateEventVisible] = useState(false);
  const [newEventTitle, setNewEventTitle] = useState('');
  const [newEventTimeObj, setNewEventTimeObj] = useState<Date | null>(null);
  const [newEventDesc, setNewEventDesc] = useState('');
  const [newEventFamilyId, setNewEventFamilyId] = useState<number | null>(null);
  const [creatingEvent, setCreatingEvent] = useState(false);

  // Shared
  const [families, setFamilies] = useState<Family[]>([]);
  const [members, setMembers] = useState<Member[]>([]);

  const fetchFamilies = async () => {
    try {
      const res = await api.get('/events/my-families', { headers });
      setFamilies(res.data);
    } catch {}
  };

  const fetchMembers = async (fid: number) => {
    try {
      const res = await api.get(`/families/${fid}/members`, { headers });
      setMembers(res.data);
    } catch {}
  };

  // ── Event tasks ──

  const fetchEventTasks = async (eventId: number) => {
    setLoadingEventTasks(true);
    try {
      const res = await api.get('/tasks/my-tasks', { params: { event_id: eventId }, headers });
      setEventTasks(res.data);
    } catch {}
    setLoadingEventTasks(false);
  };

  const openEventDetail = async (event: CalendarEvent) => {
    setDetailItem({ type: 'event', item: event });
    setNewEventTaskTitle('');
    setNewEventTaskAssigneeId(null);
    setEventTasks([]);
    await fetchEventTasks(event.id);
    if (event.family_id) {
      try {
        const res = await api.get(`/families/${event.family_id}/members`, { headers });
        setEventTaskMembers(res.data);
      } catch { setEventTaskMembers([]); }
    }
  };

  const handleCreateEventTask = async () => {
    if (!newEventTaskTitle.trim() || !detailItem) return;
    setCreatingEventTask(true);
    try {
      const event = detailItem.item as CalendarEvent;
      await api.post('/tasks/', {
        title: newEventTaskTitle.trim(),
        visibility: 'famille',
        priority: 'normale',
        family_id: event.family_id,
        assigned_to_id: newEventTaskAssigneeId || null,
        event_id: event.id,
        due_date: event.date,
      }, { headers });
      setNewEventTaskTitle('');
      setNewEventTaskAssigneeId(null);
      await fetchEventTasks(event.id);
    } catch { Alert.alert('Erreur', 'Impossible de créer la tâche'); }
    setCreatingEventTask(false);
  };

  const handleToggleEventTask = async (task: EventTask) => {
    const newStatus = task.status === 'fait' ? 'en_attente' : 'fait';
    try {
      await api.patch(`/tasks/${task.id}`, { status: newStatus }, { headers });
      setEventTasks(prev => prev.map(t => t.id === task.id ? { ...t, status: newStatus } : t));
    } catch {}
  };

  // ── Marked dates ──

  const buildMarkedDates = (
    events: CalendarEvent[], tasks: CalendarTask[], selected: string
  ): MarkedDates => {
    const marks: MarkedDates = {};
    events.forEach(e => {
      if (!marks[e.date]) marks[e.date] = { dots: [] };
      marks[e.date].dots!.push({ key: `event-${e.id}`, color: '#3b82f6' });
    });
    tasks.forEach(t => {
      if (!t.due_date) return;
      if (!marks[t.due_date]) marks[t.due_date] = { dots: [] };
      marks[t.due_date].dots!.push({ key: `task-${t.id}`, color: t.visibility === 'famille' ? '#3b82f6' : C.primary });
    });
    marks[selected] = { ...(marks[selected] || {}), selected: true, selectedColor: C.primary };
    return marks;
  };

  const fetchMonthData = useCallback(async (year: number, month: number, sel?: string) => {
    setLoadingMonth(true);
    const { start, end } = formatMonth(year, month);
    try {
      const [eventsRes, tasksRes] = await Promise.all([
        api.get('/events/my-events', { params: { start_date: start, end_date: end }, headers }),
        api.get('/tasks/agenda', { params: { start_date: start, end_date: end }, headers }),
      ]);
      setMarkedDates(buildMarkedDates(eventsRes.data, tasksRes.data, sel || selectedDate));
    } catch {}
    setLoadingMonth(false);
  }, [token]);

  const fetchDayData = useCallback(async (date: string) => {
    setLoadingDay(true);
    try {
      const [eventsRes, tasksRes] = await Promise.all([
        api.get('/events/my-events', { params: { start_date: date, end_date: date }, headers }),
        api.get('/tasks/agenda', { params: { start_date: date, end_date: date }, headers }),
      ]);
      setDayEvents(eventsRes.data);
      setDayTasks(tasksRes.data);
    } catch {}
    setLoadingDay(false);
  }, [token]);

  useFocusEffect(
    useCallback(() => {
      fetchMonthData(currentMonth.year, currentMonth.month);
      fetchDayData(selectedDate);
    }, [])
  );

  const handleDayPress = (day: { dateString: string }) => {
    setSelectedDate(day.dateString);
    setMarkedDates(prev => {
      const updated = { ...prev };
      Object.keys(updated).forEach(k => {
        if (updated[k].selected) updated[k] = { ...updated[k], selected: false, selectedColor: undefined };
      });
      updated[day.dateString] = { ...(updated[day.dateString] || {}), selected: true, selectedColor: C.primary };
      return updated;
    });
    fetchDayData(day.dateString);
  };

  const handleMonthChange = (month: { year: number; month: number }) => {
    setCurrentMonth(month);
    fetchMonthData(month.year, month.month);
  };

  // ── FAB / Create ──

  const openCreateChoice = () => {
    fetchFamilies();
    setCreateChoiceVisible(true);
  };

  const openCreateTask = () => {
    setCreateChoiceVisible(false);
    setNewTaskTitle(''); setNewTaskVisibility('prive'); setNewTaskPriority('normale');
    setNewTaskFamilyId(null); setNewTaskAssigneeId(null); setMembers([]);
    setCreateTaskVisible(true);
  };

  const openCreateEvent = () => {
    setCreateChoiceVisible(false);
    setNewEventTitle(''); setNewEventTimeObj(null); setNewEventDesc(''); setNewEventFamilyId(null);
    setCreateEventVisible(true);
  };

  const handleCreateTask = async () => {
    if (!newTaskTitle.trim()) return;
    setCreatingTask(true);
    try {
      await api.post('/tasks/', {
        title: newTaskTitle.trim(),
        visibility: newTaskVisibility,
        priority: newTaskPriority,
        family_id: newTaskFamilyId || null,
        assigned_to_id: newTaskAssigneeId || null,
        due_date: selectedDate,
      }, { headers });
      setCreateTaskVisible(false);
      await Promise.all([fetchDayData(selectedDate), fetchMonthData(currentMonth.year, currentMonth.month)]);
    } catch { Alert.alert('Erreur', 'Impossible de créer la tâche'); }
    setCreatingTask(false);
  };

  const handleCreateEvent = async () => {
    if (!newEventTitle.trim() || !newEventFamilyId) {
      Alert.alert('Erreur', 'Titre et famille obligatoires');
      return;
    }
    setCreatingEvent(true);
    try {
      await api.post('/events/', {
        title: newEventTitle.trim(),
        description: newEventDesc.trim() || undefined,
        event_date: selectedDate,
        time_from: newEventTimeObj ? formatTimeFromObj(newEventTimeObj) : undefined,
        family_id: newEventFamilyId,
      }, { headers });
      setCreateEventVisible(false);
      await Promise.all([fetchDayData(selectedDate), fetchMonthData(currentMonth.year, currentMonth.month)]);
    } catch { Alert.alert('Erreur', "Impossible de créer l'événement"); }
    setCreatingEvent(false);
  };

  // ── Action sheet ──

  const openActionSheet = (type: 'task' | 'event', item: any) => {
    setDetailItem(null);
    setActionItem({ type, item });
    setEditMode(false);
    if (type === 'task') {
      setEditTaskTitle(item.title);
      setEditTaskDueDateObj(parseDateToObj(item.due_date || selectedDate));
      setEditTaskPriority(item.priority || 'normale');
    } else {
      setEditEventTitle(item.title);
      setEditEventDateObj(parseDateToObj(item.date || selectedDate));
      setEditEventTimeObj(item.time_from ? parseTimeStr(item.time_from) : null);
      setEditEventDesc(item.description || '');
      setEditEventFamilyId(item.family_id || null);
      if (!families.length) fetchFamilies();
    }
  };

  const handleSaveEditTask = async () => {
    if (!actionItem) return;
    setSavingEdit(true);
    try {
      await api.patch(`/tasks/${actionItem.item.id}`, {
        title: editTaskTitle,
        due_date: formatDateFromObj(editTaskDueDateObj),
        priority: editTaskPriority,
      }, { headers });
      setActionItem(null);
      setEditMode(false);
      await Promise.all([fetchDayData(selectedDate), fetchMonthData(currentMonth.year, currentMonth.month)]);
    } catch { Alert.alert('Erreur', 'Impossible de modifier la tâche'); }
    setSavingEdit(false);
  };

  const handleSaveEditEvent = async () => {
    if (!actionItem) return;
    setSavingEdit(true);
    try {
      await api.put(`/events/${actionItem.item.id}`, {
        title: editEventTitle,
        event_date: formatDateFromObj(editEventDateObj),
        time_from: editEventTimeObj ? formatTimeFromObj(editEventTimeObj) : undefined,
        description: editEventDesc || undefined,
        family_id: editEventFamilyId || undefined,
      }, { headers });
      setActionItem(null);
      setEditMode(false);
      await Promise.all([fetchDayData(selectedDate), fetchMonthData(currentMonth.year, currentMonth.month)]);
    } catch { Alert.alert('Erreur', "Impossible de modifier l'événement"); }
    setSavingEdit(false);
  };

  const handleDeleteTask = () => {
    if (!actionItem) return;
    Alert.alert('Supprimer', 'Confirmer la suppression ?', [
      { text: 'Non' },
      {
        text: 'Supprimer', style: 'destructive',
        onPress: async () => {
          try {
            await api.delete(`/tasks/${actionItem.item.id}`, { headers });
            setActionItem(null);
            await Promise.all([fetchDayData(selectedDate), fetchMonthData(currentMonth.year, currentMonth.month)]);
          } catch { Alert.alert('Erreur', 'Impossible de supprimer'); }
        },
      },
    ]);
  };

  const handleDeleteEvent = () => {
    if (!actionItem) return;
    Alert.alert("Supprimer l'événement", 'Confirmer la suppression ?', [
      { text: 'Non' },
      {
        text: 'Supprimer', style: 'destructive',
        onPress: async () => {
          try {
            await api.delete(`/events/${actionItem.item.id}`, { headers });
            setActionItem(null);
            await Promise.all([fetchDayData(selectedDate), fetchMonthData(currentMonth.year, currentMonth.month)]);
          } catch { Alert.alert('Erreur', 'Impossible de supprimer'); }
        },
      },
    ]);
  };

  const isOwner = (item: any) => currentUserId !== null && item.created_by_id === currentUserId;

  const hasItems = dayEvents.length > 0 || dayTasks.length > 0;

  // ── Render ──────────────────────────────────────────────────────────────────

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>À venir</Text>
        <TouchableOpacity style={styles.todayBtn} onPress={() => handleDayPress({ dateString: today })}>
          <MaterialCommunityIcons name="calendar-today" size={16} color={C.primary} />
          <Text style={styles.todayBtnText}>Aujourd'hui</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.legend}>
        <View style={styles.legendItem}>
          <View style={[styles.legendDot, { backgroundColor: C.primary }]} />
          <Text style={styles.legendText}>Mes tâches</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.legendDot, { backgroundColor: '#3b82f6' }]} />
          <Text style={styles.legendText}>Famille / Événements</Text>
        </View>
      </View>

      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 100 }}>
        <Calendar
          markingType="multi-dot"
          markedDates={markedDates}
          onDayPress={handleDayPress}
          onMonthChange={handleMonthChange}
          firstDay={1}
          theme={{
            backgroundColor: C.background, calendarBackground: C.surface,
            selectedDayBackgroundColor: C.primary, selectedDayTextColor: C.textOnPrimary,
            todayTextColor: C.primary, dayTextColor: C.textPrimary,
            textDisabledColor: C.textTertiary, dotColor: C.primary,
            arrowColor: C.primary, monthTextColor: C.textPrimary,
            textMonthFontWeight: '700', textMonthFontSize: 16, textDayFontSize: 14,
          }}
          style={styles.calendar}
        />

        <View style={styles.dayDetail}>
          <Text style={styles.dayDetailTitle}>{parseDateLabel(selectedDate)}</Text>

          {loadingDay ? (
            <ActivityIndicator color={C.primary} style={{ marginTop: 24 }} />
          ) : !hasItems ? (
            <View style={styles.emptyDay}>
              <MaterialCommunityIcons name="calendar-check-outline" size={40} color={C.borderLight} />
              <Text style={styles.emptyDayText}>Aucun événement ni tâche ce jour</Text>
              <TouchableOpacity style={styles.emptyAddBtn} onPress={openCreateChoice}>
                <MaterialCommunityIcons name="plus" size={16} color={C.primary} />
                <Text style={styles.emptyAddBtnText}>Ajouter quelque chose</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <>
              {dayEvents.length > 0 && (
                <View style={styles.daySection}>
                  <View style={styles.daySectionHeader}>
                    <MaterialCommunityIcons name="calendar-clock" size={16} color="#3b82f6" />
                    <Text style={[styles.daySectionTitle, { color: '#3b82f6' }]}>
                      Événements ({dayEvents.length})
                    </Text>
                  </View>
                  {dayEvents.map(e => (
                    <TouchableOpacity
                      key={e.id}
                      style={styles.eventCard}
                      onPress={() => openEventDetail(e)}
                      onLongPress={() => openActionSheet('event', e)}
                      delayLongPress={400}
                      activeOpacity={0.85}
                    >
                      <View style={styles.eventTimeLine}>
                        {e.time_from ? (
                          <>
                            <Text style={styles.eventTime}>{e.time_from.slice(0, 5)}</Text>
                            {e.time_to && <Text style={styles.eventTimeTo}>→ {e.time_to.slice(0, 5)}</Text>}
                          </>
                        ) : (
                          <Text style={styles.eventTimeAll}>Toute la journée</Text>
                        )}
                      </View>
                      <View style={styles.eventInfo}>
                        <Text style={styles.eventTitle} numberOfLines={1}>{e.title}</Text>
                        {e.family_name && (
                          <View style={styles.eventFamilyTag}>
                            <MaterialCommunityIcons name="account-group-outline" size={11} color="#3b82f6" />
                            <Text style={styles.eventFamilyText}>{e.family_name}</Text>
                          </View>
                        )}
                        {e.description ? (
                          <Text style={styles.eventDesc} numberOfLines={2}>{e.description}</Text>
                        ) : null}
                      </View>
                      {isOwner(e) && (
                        <TouchableOpacity onPress={() => openActionSheet('event', e)} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
                          <MaterialCommunityIcons name="dots-vertical" size={18} color={C.textTertiary} />
                        </TouchableOpacity>
                      )}
                    </TouchableOpacity>
                  ))}
                </View>
              )}

              {dayTasks.length > 0 && (
                <View style={styles.daySection}>
                  <View style={styles.daySectionHeader}>
                    <MaterialCommunityIcons name="format-list-checks" size={16} color={C.primary} />
                    <Text style={[styles.daySectionTitle, { color: C.primary }]}>
                      Tâches ({dayTasks.length})
                    </Text>
                  </View>
                  {dayTasks.map(t => {
                    const s = statusLabel(t.status);
                    const priorityBorder = PRIORITY_COLORS[t.priority] || C.borderLight;
                    return (
                      <TouchableOpacity
                        key={t.id}
                        style={[styles.taskCard, { borderLeftColor: priorityBorder }]}
                        onPress={() => setDetailItem({ type: 'task', item: t })}
                        onLongPress={() => openActionSheet('task', t)}
                        delayLongPress={400}
                        activeOpacity={0.85}
                      >
                        <View style={[styles.taskStatusDot, { backgroundColor: s.color }]} />
                        <View style={styles.taskInfo}>
                          <Text style={[styles.taskTitle, t.status === 'fait' && styles.taskDone]} numberOfLines={1}>
                            {t.title}
                          </Text>
                          <View style={styles.taskTags}>
                            <View style={[styles.statusBadge, { backgroundColor: s.color + '20' }]}>
                              <Text style={[styles.statusBadgeText, { color: s.color }]}>{s.label}</Text>
                            </View>
                            {t.family_name && (
                              <View style={styles.familyTag}>
                                <Text style={styles.familyTagText}>{t.family_name}</Text>
                              </View>
                            )}
                            {t.assigned_to_name && (
                              <View style={styles.assigneeTag}>
                                <MaterialCommunityIcons name="account-outline" size={11} color={C.textTertiary} />
                                <Text style={styles.assigneeText}>{t.assigned_to_name}</Text>
                              </View>
                            )}
                          </View>
                        </View>
                        <TouchableOpacity onPress={() => openActionSheet('task', t)} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
                          <MaterialCommunityIcons name="dots-vertical" size={18} color={C.textTertiary} />
                        </TouchableOpacity>
                      </TouchableOpacity>
                    );
                  })}
                </View>
              )}
            </>
          )}
        </View>
      </ScrollView>

      <FAB icon="plus" style={styles.fab} color={C.textOnPrimary} onPress={openCreateChoice} />

      {/* ── Detail Modal (Task) ── */}
      <Modal
        visible={!!detailItem && detailItem.type === 'task'}
        transparent
        animationType="fade"
        onRequestClose={() => setDetailItem(null)}
      >
        <Pressable style={styles.overlayCenter} onPress={() => { Keyboard.dismiss(); setDetailItem(null); }}>
          <Pressable style={styles.detailBox} onPress={() => {}}>
            {detailItem?.type === 'task' && (
              <>
                <View style={styles.detailHeader}>
                  <MaterialCommunityIcons name="format-list-checks" size={20} color={C.primary} />
                  <Text style={styles.detailTitle} numberOfLines={2}>{detailItem.item.title}</Text>
                </View>
                {detailItem.item.description ? <Text style={styles.detailDesc}>{detailItem.item.description}</Text> : null}
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>Statut</Text>
                  <Text style={[styles.detailValue, { color: statusLabel(detailItem.item.status).color }]}>
                    {statusLabel(detailItem.item.status).label}
                  </Text>
                </View>
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>Priorité</Text>
                  <Text style={[styles.detailValue, { color: PRIORITY_ACTIVE[detailItem.item.priority] }]}>
                    {{ normale: 'Normale', haute: 'Haute', urgente: 'Urgente' }[detailItem.item.priority as string]}
                  </Text>
                </View>
                {detailItem.item.due_date && (
                  <View style={styles.detailRow}>
                    <Text style={styles.detailLabel}>Date</Text>
                    <Text style={styles.detailValue}>{detailItem.item.due_date}</Text>
                  </View>
                )}
                {detailItem.item.family_name && (
                  <View style={styles.detailRow}>
                    <Text style={styles.detailLabel}>Famille</Text>
                    <Text style={styles.detailValue}>{detailItem.item.family_name}</Text>
                  </View>
                )}
                {detailItem.item.assigned_to_name && (
                  <View style={styles.detailRow}>
                    <Text style={styles.detailLabel}>Assigné à</Text>
                    <Text style={styles.detailValue}>{detailItem.item.assigned_to_name}</Text>
                  </View>
                )}
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>Créé par</Text>
                  <Text style={styles.detailValue}>{detailItem.item.created_by_name}</Text>
                </View>
                {isOwner(detailItem.item) && (
                  <TouchableOpacity
                    style={styles.detailActionBtn}
                    onPress={() => { openActionSheet('task', detailItem.item); setDetailItem(null); }}
                  >
                    <Text style={styles.detailActionText}>Modifier / Supprimer</Text>
                  </TouchableOpacity>
                )}
                <TouchableOpacity onPress={() => setDetailItem(null)} style={{ alignItems: 'center', marginTop: 12 }}>
                  <Text style={{ color: C.textSecondary, fontSize: 14 }}>Fermer</Text>
                </TouchableOpacity>
              </>
            )}
          </Pressable>
        </Pressable>
      </Modal>

      {/* ── Detail Modal (Event) ── */}
      <Modal
        visible={!!detailItem && detailItem.type === 'event'}
        transparent
        animationType="fade"
        onRequestClose={() => setDetailItem(null)}
      >
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={{ flex: 1, justifyContent: 'center', backgroundColor: 'rgba(0,0,0,0.4)', paddingHorizontal: 24 }}>
          <Pressable style={{ flex: 1 }} onPress={() => { Keyboard.dismiss(); setDetailItem(null); }} />
          <View style={[styles.detailBox, { maxHeight: '85%' }]}>
            {detailItem?.type === 'event' && (
              <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
                <View style={styles.detailHeader}>
                  <MaterialCommunityIcons name="calendar-clock" size={20} color="#3b82f6" />
                  <Text style={styles.detailTitle} numberOfLines={2}>{detailItem.item.title}</Text>
                </View>
                {detailItem.item.description ? <Text style={styles.detailDesc}>{detailItem.item.description}</Text> : null}
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>Date</Text>
                  <Text style={styles.detailValue}>{detailItem.item.date}</Text>
                </View>
                {detailItem.item.time_from && (
                  <View style={styles.detailRow}>
                    <Text style={styles.detailLabel}>Heure</Text>
                    <Text style={styles.detailValue}>{detailItem.item.time_from.slice(0, 5)}</Text>
                  </View>
                )}
                {detailItem.item.family_name && (
                  <View style={styles.detailRow}>
                    <Text style={styles.detailLabel}>Famille</Text>
                    <Text style={styles.detailValue}>{detailItem.item.family_name}</Text>
                  </View>
                )}
                {detailItem.item.created_by && (
                  <View style={[styles.detailRow, { marginBottom: 16 }]}>
                    <Text style={styles.detailLabel}>Créé par</Text>
                    <Text style={styles.detailValue}>{detailItem.item.created_by}</Text>
                  </View>
                )}

                {/* Event Tasks Section */}
                <View style={styles.eventTasksSection}>
                  <View style={styles.eventTasksHeader}>
                    <MaterialCommunityIcons name="clipboard-list-outline" size={16} color="#3b82f6" />
                    <Text style={styles.eventTasksTitle}>Tâches de l'événement</Text>
                    {loadingEventTasks && <ActivityIndicator size="small" color="#3b82f6" style={{ marginLeft: 8 }} />}
                  </View>

                  {eventTasks.length === 0 && !loadingEventTasks && (
                    <Text style={styles.eventTasksEmpty}>Aucune tâche pour cet événement</Text>
                  )}

                  {eventTasks.map(t => (
                    <TouchableOpacity
                      key={t.id}
                      style={styles.eventTaskRow}
                      onPress={() => handleToggleEventTask(t)}
                      activeOpacity={0.7}
                    >
                      <MaterialCommunityIcons
                        name={t.status === 'fait' ? 'check-circle' : 'circle-outline'}
                        size={20}
                        color={t.status === 'fait' ? '#22c55e' : C.textTertiary}
                      />
                      <View style={{ flex: 1, marginLeft: 10 }}>
                        <Text style={[styles.eventTaskTitle, t.status === 'fait' && styles.taskDone]}>{t.title}</Text>
                        {t.assigned_to_name && (
                          <Text style={styles.eventTaskAssignee}>{t.assigned_to_name}</Text>
                        )}
                      </View>
                    </TouchableOpacity>
                  ))}

                  {/* Add task inline form */}
                  <View style={styles.eventTaskAddRow}>
                    <RNTextInput
                      style={styles.eventTaskInput}
                      placeholder="Ajouter une tâche..."
                      placeholderTextColor={C.textPlaceholder}
                      value={newEventTaskTitle}
                      onChangeText={setNewEventTaskTitle}
                      returnKeyType="done"
                      onSubmitEditing={handleCreateEventTask}
                    />
                    <TouchableOpacity
                      style={[styles.eventTaskAddBtn, !newEventTaskTitle.trim() && { opacity: 0.4 }]}
                      onPress={handleCreateEventTask}
                      disabled={!newEventTaskTitle.trim() || creatingEventTask}
                    >
                      <MaterialCommunityIcons name={creatingEventTask ? 'loading' : 'plus'} size={18} color="#fff" />
                    </TouchableOpacity>
                  </View>

                  {eventTaskMembers.length > 0 && (
                    <>
                      <Text style={[styles.fieldLabel, { marginTop: 8 }]}>Assigner à</Text>
                      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 8 }}>
                        <TouchableOpacity
                          style={[styles.chipBtn, newEventTaskAssigneeId === null && styles.chipActive]}
                          onPress={() => setNewEventTaskAssigneeId(null)}
                        >
                          <Text style={[styles.chipText, newEventTaskAssigneeId === null && styles.chipTextActive]}>Personne</Text>
                        </TouchableOpacity>
                        {eventTaskMembers.map(m => (
                          <TouchableOpacity
                            key={m.id}
                            style={[styles.chipBtn, newEventTaskAssigneeId === m.id && styles.chipActive]}
                            onPress={() => setNewEventTaskAssigneeId(m.id)}
                          >
                            <Text style={[styles.chipText, newEventTaskAssigneeId === m.id && styles.chipTextActive]}>{m.full_name}</Text>
                          </TouchableOpacity>
                        ))}
                      </ScrollView>
                    </>
                  )}
                </View>

                {isOwner(detailItem.item) && (
                  <TouchableOpacity
                    style={[styles.detailActionBtn, { borderColor: '#3b82f6', marginTop: 12 }]}
                    onPress={() => { openActionSheet('event', detailItem.item); setDetailItem(null); }}
                  >
                    <Text style={[styles.detailActionText, { color: '#3b82f6' }]}>Modifier / Supprimer</Text>
                  </TouchableOpacity>
                )}
                <TouchableOpacity onPress={() => setDetailItem(null)} style={{ alignItems: 'center', marginTop: 12 }}>
                  <Text style={{ color: C.textSecondary, fontSize: 14 }}>Fermer</Text>
                </TouchableOpacity>
              </ScrollView>
            )}
          </View>
          <View style={{ flex: 1 }} />
        </KeyboardAvoidingView>
      </Modal>

      {/* ── Create Choice Modal ── */}
      <Modal visible={createChoiceVisible} transparent animationType="fade" onRequestClose={() => setCreateChoiceVisible(false)}>
        <Pressable style={styles.overlayCenter} onPress={() => { Keyboard.dismiss(); setCreateChoiceVisible(false); }}>
          <Pressable style={styles.choiceBox} onPress={() => {}}>
            <Text style={styles.choiceTitle}>Ajouter pour le {parseDateLabel(selectedDate)}</Text>
            <TouchableOpacity style={styles.choiceBtn} onPress={openCreateTask}>
              <View style={[styles.choiceIcon, { backgroundColor: C.primaryLight }]}>
                <MaterialCommunityIcons name="format-list-checks" size={22} color={C.primary} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.choiceBtnTitle}>Tâche</Text>
                <Text style={styles.choiceBtnSub}>Ajouter une tâche personnelle ou famille</Text>
              </View>
              <MaterialCommunityIcons name="chevron-right" size={20} color={C.textTertiary} />
            </TouchableOpacity>
            <TouchableOpacity style={[styles.choiceBtn, { borderBottomWidth: 0 }]} onPress={openCreateEvent}>
              <View style={[styles.choiceIcon, { backgroundColor: '#eff6ff' }]}>
                <MaterialCommunityIcons name="calendar-plus" size={22} color="#3b82f6" />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.choiceBtnTitle}>Événement</Text>
                <Text style={styles.choiceBtnSub}>Créer un événement pour une famille</Text>
              </View>
              <MaterialCommunityIcons name="chevron-right" size={20} color={C.textTertiary} />
            </TouchableOpacity>
          </Pressable>
        </Pressable>
      </Modal>

      {/* ── Create Task Modal ── */}
      <Modal visible={createTaskVisible} transparent animationType="fade" onRequestClose={() => setCreateTaskVisible(false)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={styles.kavContainer}>
          <Pressable style={{ flex: 1 }} onPress={() => { Keyboard.dismiss(); setCreateTaskVisible(false); }} />
          <View style={styles.formBox}>
            <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              <Text style={styles.formTitle}>Nouvelle tâche · {parseDateLabel(selectedDate)}</Text>

              {/* Templates */}
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 14 }}>
                {TASK_TEMPLATES.map(tpl => (
                  <TouchableOpacity
                    key={tpl.label}
                    style={styles.tplChip}
                    onPress={() => setNewTaskTitle(tpl.title)}
                  >
                    <MaterialCommunityIcons name={tpl.icon as any} size={16} color={C.primary} />
                    <Text style={styles.tplChipText}>{tpl.label}</Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>

              <RNTextInput
                style={styles.textInput}
                placeholder="Titre de la tâche"
                placeholderTextColor={C.textPlaceholder}
                value={newTaskTitle}
                onChangeText={setNewTaskTitle}
                autoFocus
              />
              <Text style={styles.fieldLabel}>Visibilité</Text>
              <View style={styles.toggleRow}>
                {(['prive', 'famille'] as const).map(v => (
                  <TouchableOpacity
                    key={v}
                    style={[styles.toggleBtn, newTaskVisibility === v && styles.toggleActive]}
                    onPress={() => {
                      setNewTaskVisibility(v);
                      if (v === 'prive') { setNewTaskFamilyId(null); setNewTaskAssigneeId(null); }
                    }}
                  >
                    <Text style={[styles.toggleText, newTaskVisibility === v && styles.toggleTextActive]}>
                      {v === 'prive' ? '🔒 Privé' : '👨‍👩‍👧 Famille'}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
              <Text style={styles.fieldLabel}>Priorité</Text>
              <View style={styles.toggleRow}>
                {(['normale', 'haute', 'urgente'] as const).map(p => (
                  <TouchableOpacity
                    key={p}
                    style={[styles.priorityBtn, newTaskPriority === p && { backgroundColor: PRIORITY_ACTIVE[p], borderColor: PRIORITY_ACTIVE[p] }]}
                    onPress={() => setNewTaskPriority(p)}
                  >
                    <Text style={[styles.priorityBtnText, newTaskPriority === p && { color: '#fff' }]}>
                      {{ normale: 'Normale', haute: 'Haute', urgente: 'Urgente' }[p]}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
              {newTaskVisibility === 'famille' && families.length > 0 && (
                <>
                  <Text style={styles.fieldLabel}>Famille</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 12 }}>
                    {families.map(f => (
                      <TouchableOpacity
                        key={f.id}
                        style={[styles.chipBtn, newTaskFamilyId === f.id && styles.chipActive]}
                        onPress={async () => { setNewTaskFamilyId(f.id); await fetchMembers(f.id); }}
                      >
                        <Text style={[styles.chipText, newTaskFamilyId === f.id && styles.chipTextActive]}>{f.name}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </>
              )}
              {newTaskFamilyId !== null && members.length > 0 && (
                <>
                  <Text style={styles.fieldLabel}>Assigner à</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 12 }}>
                    <TouchableOpacity
                      style={[styles.chipBtn, newTaskAssigneeId === null && styles.chipActive]}
                      onPress={() => setNewTaskAssigneeId(null)}
                    >
                      <Text style={[styles.chipText, newTaskAssigneeId === null && styles.chipTextActive]}>Personne</Text>
                    </TouchableOpacity>
                    {members.map(m => (
                      <TouchableOpacity
                        key={m.id}
                        style={[styles.chipBtn, newTaskAssigneeId === m.id && styles.chipActive]}
                        onPress={() => setNewTaskAssigneeId(m.id)}
                      >
                        <Text style={[styles.chipText, newTaskAssigneeId === m.id && styles.chipTextActive]}>{m.full_name}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </>
              )}
              <TouchableOpacity
                style={[styles.primaryBtn, (!newTaskTitle.trim() || creatingTask) && styles.btnDisabled]}
                onPress={handleCreateTask}
                disabled={!newTaskTitle.trim() || creatingTask}
              >
                <Text style={styles.primaryBtnText}>{creatingTask ? 'Création...' : 'Créer la tâche'}</Text>
              </TouchableOpacity>
              <TouchableOpacity style={{ alignItems: 'center', marginTop: 10 }} onPress={() => setCreateTaskVisible(false)}>
                <Text style={{ color: C.textSecondary, fontSize: 14 }}>Annuler</Text>
              </TouchableOpacity>
            </ScrollView>
          </View>
          <View style={{ flex: 0.3 }} />
        </KeyboardAvoidingView>
      </Modal>

      {/* ── Create Event Modal ── */}
      <Modal visible={createEventVisible} transparent animationType="fade" onRequestClose={() => setCreateEventVisible(false)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={styles.kavContainer}>
          <Pressable style={{ flex: 1 }} onPress={() => { Keyboard.dismiss(); setCreateEventVisible(false); }} />
          <View style={styles.formBox}>
            <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              <Text style={styles.formTitle}>Nouvel événement · {parseDateLabel(selectedDate)}</Text>

              {/* Templates */}
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 14 }}>
                {EVENT_TEMPLATES.map(tpl => (
                  <TouchableOpacity
                    key={tpl.label}
                    style={styles.tplChip}
                    onPress={() => setNewEventTitle(tpl.title)}
                  >
                    <MaterialCommunityIcons name={tpl.icon as any} size={16} color="#3b82f6" />
                    <Text style={[styles.tplChipText, { color: '#3b82f6' }]}>{tpl.label}</Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>

              <RNTextInput
                style={styles.textInput}
                placeholder="Titre de l'événement"
                placeholderTextColor={C.textPlaceholder}
                value={newEventTitle}
                onChangeText={setNewEventTitle}
                autoFocus
              />
              <RNTextInput
                style={[styles.textInput, { height: 68 }]}
                placeholder="Description (optionnel)"
                placeholderTextColor={C.textPlaceholder}
                value={newEventDesc}
                onChangeText={setNewEventDesc}
                multiline
              />

              <DatePickerField
                value={newEventTimeObj}
                onChange={d => setNewEventTimeObj(d)}
                mode="time"
                placeholder="Heure (optionnel)"
                clearable
                onClear={() => setNewEventTimeObj(null)}
              />

              {families.length > 0 && (
                <>
                  <Text style={styles.fieldLabel}>Famille *</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 16 }}>
                    {families.map(f => (
                      <TouchableOpacity
                        key={f.id}
                        style={[styles.chipBtn, newEventFamilyId === f.id && styles.chipActive]}
                        onPress={() => setNewEventFamilyId(f.id)}
                      >
                        <Text style={[styles.chipText, newEventFamilyId === f.id && styles.chipTextActive]}>{f.name}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </>
              )}
              <TouchableOpacity
                style={[styles.primaryBtn, (!newEventTitle.trim() || !newEventFamilyId || creatingEvent) && styles.btnDisabled]}
                onPress={handleCreateEvent}
                disabled={!newEventTitle.trim() || !newEventFamilyId || creatingEvent}
              >
                <Text style={styles.primaryBtnText}>{creatingEvent ? 'Création...' : "Créer l'événement"}</Text>
              </TouchableOpacity>
              <TouchableOpacity style={{ alignItems: 'center', marginTop: 10 }} onPress={() => setCreateEventVisible(false)}>
                <Text style={{ color: C.textSecondary, fontSize: 14 }}>Annuler</Text>
              </TouchableOpacity>
            </ScrollView>
          </View>
          <View style={{ flex: 0.3 }} />
        </KeyboardAvoidingView>
      </Modal>

      {/* ── Action Sheet (long press / 3-dot) ── */}
      <Modal visible={!!actionItem} transparent animationType="slide" onRequestClose={() => { setActionItem(null); setEditMode(false); }}>
        <Pressable style={styles.overlayBottom} onPress={() => { Keyboard.dismiss(); setActionItem(null); setEditMode(false); }} />
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
          <View style={styles.formSheet}>
            {actionItem && !editMode && (
              <>
                <View style={styles.sheetHandle} />
                <Text style={styles.formTitle} numberOfLines={1}>{actionItem.item.title}</Text>
                {isOwner(actionItem.item) && (
                  <TouchableOpacity style={styles.actionRow} onPress={() => setEditMode(true)}>
                    <MaterialCommunityIcons name="pencil-outline" size={20} color={C.textPrimary} />
                    <Text style={styles.actionText}>Modifier</Text>
                  </TouchableOpacity>
                )}
                {!isOwner(actionItem.item) && actionItem.type === 'task' && (
                  <TouchableOpacity style={styles.actionRow} onPress={() => setEditMode(true)}>
                    <MaterialCommunityIcons name="calendar-edit" size={20} color={C.textPrimary} />
                    <Text style={styles.actionText}>Modifier la date</Text>
                  </TouchableOpacity>
                )}
                {isOwner(actionItem.item) && (
                  <TouchableOpacity
                    style={styles.actionRow}
                    onPress={actionItem.type === 'task' ? handleDeleteTask : handleDeleteEvent}
                  >
                    <MaterialCommunityIcons name="delete-outline" size={20} color={C.destructive} />
                    <Text style={[styles.actionText, { color: C.destructive }]}>Supprimer</Text>
                  </TouchableOpacity>
                )}
                <TouchableOpacity style={[styles.actionRow, { borderBottomWidth: 0 }]} onPress={() => setActionItem(null)}>
                  <MaterialCommunityIcons name="close" size={20} color={C.textSecondary} />
                  <Text style={[styles.actionText, { color: C.textSecondary }]}>Fermer</Text>
                </TouchableOpacity>
              </>
            )}

            {actionItem && editMode && actionItem.type === 'task' && (
              <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
                <View style={styles.sheetHandle} />
                <Text style={styles.formTitle}>Modifier la tâche</Text>
                {isOwner(actionItem.item) && (
                  <>
                    <RNTextInput
                      style={styles.textInput}
                      value={editTaskTitle}
                      onChangeText={setEditTaskTitle}
                      placeholder="Titre"
                      placeholderTextColor={C.textPlaceholder}
                    />
                    <Text style={styles.fieldLabel}>Priorité</Text>
                    <View style={styles.toggleRow}>
                      {(['normale', 'haute', 'urgente'] as const).map(p => (
                        <TouchableOpacity
                          key={p}
                          style={[styles.priorityBtn, editTaskPriority === p && { backgroundColor: PRIORITY_ACTIVE[p], borderColor: PRIORITY_ACTIVE[p] }]}
                          onPress={() => setEditTaskPriority(p)}
                        >
                          <Text style={[styles.priorityBtnText, editTaskPriority === p && { color: '#fff' }]}>
                            {{ normale: 'Normale', haute: 'Haute', urgente: 'Urgente' }[p]}
                          </Text>
                        </TouchableOpacity>
                      ))}
                    </View>
                  </>
                )}
                <DatePickerField
                  value={editTaskDueDateObj}
                  onChange={d => setEditTaskDueDateObj(d)}
                  mode="date"
                  placeholder="Date"
                />
                <TouchableOpacity
                  style={[styles.primaryBtn, savingEdit && styles.btnDisabled]}
                  onPress={handleSaveEditTask}
                  disabled={savingEdit}
                >
                  <Text style={styles.primaryBtnText}>{savingEdit ? 'Enregistrement...' : 'Enregistrer'}</Text>
                </TouchableOpacity>
                <TouchableOpacity style={{ alignItems: 'center', marginTop: 10 }} onPress={() => setEditMode(false)}>
                  <Text style={{ color: C.textSecondary, fontSize: 14 }}>Retour</Text>
                </TouchableOpacity>
              </ScrollView>
            )}

            {actionItem && editMode && actionItem.type === 'event' && (
              <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
                <View style={styles.sheetHandle} />
                <Text style={styles.formTitle}>Modifier l'événement</Text>
                <RNTextInput
                  style={styles.textInput}
                  value={editEventTitle}
                  onChangeText={setEditEventTitle}
                  placeholder="Titre"
                  placeholderTextColor={C.textPlaceholder}
                />
                <RNTextInput
                  style={[styles.textInput, { height: 68 }]}
                  value={editEventDesc}
                  onChangeText={setEditEventDesc}
                  placeholder="Description"
                  placeholderTextColor={C.textPlaceholder}
                  multiline
                />
                <DatePickerField
                  value={editEventDateObj}
                  onChange={d => setEditEventDateObj(d)}
                  mode="date"
                  placeholder="Date"
                />
                <DatePickerField
                  value={editEventTimeObj}
                  onChange={d => setEditEventTimeObj(d)}
                  mode="time"
                  placeholder="Heure (optionnel)"
                  clearable
                  onClear={() => setEditEventTimeObj(null)}
                />
                {families.length > 0 && (
                  <>
                    <Text style={styles.fieldLabel}>Famille</Text>
                    <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 14 }}>
                      {families.map(f => (
                        <TouchableOpacity
                          key={f.id}
                          style={[styles.chipBtn, editEventFamilyId === f.id && styles.chipActive]}
                          onPress={() => setEditEventFamilyId(f.id)}
                        >
                          <Text style={[styles.chipText, editEventFamilyId === f.id && styles.chipTextActive]}>{f.name}</Text>
                        </TouchableOpacity>
                      ))}
                    </ScrollView>
                  </>
                )}
                <TouchableOpacity
                  style={[styles.primaryBtn, savingEdit && styles.btnDisabled]}
                  onPress={handleSaveEditEvent}
                  disabled={savingEdit}
                >
                  <Text style={styles.primaryBtnText}>{savingEdit ? 'Enregistrement...' : 'Enregistrer'}</Text>
                </TouchableOpacity>
                <TouchableOpacity style={{ alignItems: 'center', marginTop: 10 }} onPress={() => setEditMode(false)}>
                  <Text style={{ color: C.textSecondary, fontSize: 14 }}>Retour</Text>
                </TouchableOpacity>
              </ScrollView>
            )}
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </SafeAreaView>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: C.background },

  header: {
    flexDirection: 'row', alignItems: 'center',
    paddingHorizontal: 20, paddingTop: 16, paddingBottom: 12,
    justifyContent: 'space-between',
  },
  headerTitle: { fontSize: 24, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.3 },
  todayBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    borderWidth: 1, borderColor: C.primary, borderRadius: C.radiusFull,
    paddingHorizontal: 12, paddingVertical: 6,
  },
  todayBtnText: { fontSize: 13, fontWeight: '600', color: C.primary },
  legend: { flexDirection: 'row', gap: 16, paddingHorizontal: 20, paddingBottom: 8 },
  legendItem: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  legendDot: { width: 8, height: 8, borderRadius: 4 },
  legendText: { fontSize: 12, color: C.textSecondary },
  calendar: { borderRadius: C.radiusLg, marginHorizontal: 12, overflow: 'hidden', ...C.shadowSm },
  dayDetail: { padding: 20, paddingBottom: 40 },
  dayDetailTitle: { fontSize: 17, fontWeight: '700', color: C.textPrimary, marginBottom: 16, textTransform: 'capitalize' },
  emptyDay: { alignItems: 'center', paddingTop: 32, gap: 12 },
  emptyDayText: { fontSize: 14, color: C.textTertiary },
  emptyAddBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    borderWidth: 1, borderColor: C.primary, borderRadius: C.radiusFull,
    paddingHorizontal: 14, paddingVertical: 8, marginTop: 4,
  },
  emptyAddBtnText: { fontSize: 13, color: C.primary, fontWeight: '600' },
  daySection: { marginBottom: 20 },
  daySectionHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 10 },
  daySectionTitle: { fontSize: 14, fontWeight: '700' },

  eventCard: {
    flexDirection: 'row', backgroundColor: C.surface,
    borderRadius: C.radiusBase, padding: 12, marginBottom: 8,
    borderLeftWidth: 3, borderLeftColor: '#3b82f6', ...C.shadowSm, alignItems: 'center',
  },
  eventTimeLine: { width: 60, marginRight: 12, justifyContent: 'center' },
  eventTime: { fontSize: 12, fontWeight: '700', color: '#3b82f6' },
  eventTimeTo: { fontSize: 11, color: C.textTertiary, marginTop: 2 },
  eventTimeAll: { fontSize: 11, color: C.textTertiary, fontStyle: 'italic' },
  eventInfo: { flex: 1 },
  eventTitle: { fontSize: 14, fontWeight: '600', color: C.textPrimary, marginBottom: 4 },
  eventFamilyTag: {
    flexDirection: 'row', alignItems: 'center', gap: 4,
    backgroundColor: '#eff6ff', borderRadius: C.radiusFull,
    paddingHorizontal: 6, paddingVertical: 2, alignSelf: 'flex-start', marginBottom: 4,
  },
  eventFamilyText: { fontSize: 11, color: '#3b82f6', fontWeight: '500' },
  eventDesc: { fontSize: 12, color: C.textSecondary, lineHeight: 16 },

  taskCard: {
    flexDirection: 'row', alignItems: 'flex-start',
    backgroundColor: C.surface, borderRadius: C.radiusBase,
    padding: 12, marginBottom: 8, ...C.shadowSm, borderLeftWidth: 3,
  },
  taskStatusDot: { width: 8, height: 8, borderRadius: 4, marginTop: 5, marginRight: 10 },
  taskInfo: { flex: 1 },
  taskTitle: { fontSize: 14, fontWeight: '600', color: C.textPrimary, marginBottom: 6 },
  taskDone: { textDecorationLine: 'line-through', color: C.textTertiary },
  taskTags: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  statusBadge: { borderRadius: C.radiusFull, paddingHorizontal: 8, paddingVertical: 2 },
  statusBadgeText: { fontSize: 11, fontWeight: '600' },
  familyTag: { backgroundColor: '#eff6ff', borderRadius: C.radiusFull, paddingHorizontal: 8, paddingVertical: 2 },
  familyTagText: { fontSize: 11, color: '#3b82f6', fontWeight: '500' },
  assigneeTag: { flexDirection: 'row', alignItems: 'center', gap: 3, backgroundColor: C.surfaceAlt, borderRadius: C.radiusFull, paddingHorizontal: 6, paddingVertical: 2 },
  assigneeText: { fontSize: 11, color: C.textTertiary },

  fab: { position: 'absolute', right: 20, bottom: 28, backgroundColor: C.primary },

  overlayCenter: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'center', paddingHorizontal: 24 },
  overlayBottom: { flex: 1, backgroundColor: 'rgba(0,0,0,0.35)' },

  detailBox: { backgroundColor: C.surface, borderRadius: C.radiusXl, padding: 20, ...C.shadowMd },
  detailHeader: { flexDirection: 'row', alignItems: 'flex-start', gap: 10, marginBottom: 12 },
  detailTitle: { fontSize: 17, fontWeight: '700', color: C.textPrimary, flex: 1 },
  detailDesc: { fontSize: 14, color: C.textSecondary, marginBottom: 12, lineHeight: 20 },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: C.borderLight },
  detailLabel: { fontSize: 13, color: C.textTertiary, fontWeight: '500' },
  detailValue: { fontSize: 13, color: C.textPrimary, fontWeight: '600' },
  detailActionBtn: {
    borderWidth: 1, borderColor: C.primary, borderRadius: C.radiusBase,
    paddingVertical: 10, alignItems: 'center', marginTop: 16,
  },
  detailActionText: { fontSize: 14, fontWeight: '600', color: C.primary },

  // Event tasks
  eventTasksSection: {
    marginTop: 4, borderTopWidth: 1, borderTopColor: C.borderLight, paddingTop: 14,
  },
  eventTasksHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 },
  eventTasksTitle: { fontSize: 14, fontWeight: '700', color: '#3b82f6', flex: 1 },
  eventTasksEmpty: { fontSize: 13, color: C.textTertiary, marginBottom: 10, fontStyle: 'italic' },
  eventTaskRow: {
    flexDirection: 'row', alignItems: 'center',
    paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: C.borderLight,
  },
  eventTaskTitle: { fontSize: 14, color: C.textPrimary, fontWeight: '500' },
  eventTaskAssignee: { fontSize: 12, color: C.textTertiary, marginTop: 2 },
  eventTaskAddRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 10 },
  eventTaskInput: {
    flex: 1, borderWidth: 1, borderColor: C.border, borderRadius: C.radiusBase,
    paddingHorizontal: 12, paddingVertical: 8,
    fontSize: 14, color: C.textPrimary, backgroundColor: C.surfaceAlt,
  },
  eventTaskAddBtn: {
    backgroundColor: '#3b82f6', borderRadius: C.radiusBase,
    padding: 10, alignItems: 'center', justifyContent: 'center',
  },

  choiceBox: { backgroundColor: C.surface, borderRadius: C.radiusXl, padding: 20, ...C.shadowMd },
  choiceTitle: { fontSize: 16, fontWeight: '700', color: C.textPrimary, marginBottom: 16 },
  choiceBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 14,
    paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: C.borderLight,
  },
  choiceIcon: { width: 44, height: 44, borderRadius: C.radiusBase, alignItems: 'center', justifyContent: 'center' },
  choiceBtnTitle: { fontSize: 15, fontWeight: '600', color: C.textPrimary },
  choiceBtnSub: { fontSize: 12, color: C.textTertiary, marginTop: 2 },

  kavContainer: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)' },
  formBox: {
    backgroundColor: C.surface, marginHorizontal: 16,
    borderRadius: C.radiusXl, padding: 20, maxHeight: '80%',
  },
  formSheet: {
    backgroundColor: C.surface,
    borderTopLeftRadius: C.radius2xl, borderTopRightRadius: C.radius2xl,
    padding: 20, paddingBottom: 36, maxHeight: '80%',
  },
  sheetHandle: {
    width: 36, height: 4, borderRadius: 2,
    backgroundColor: C.borderLight, alignSelf: 'center', marginBottom: 16,
  },
  formTitle: { fontSize: 17, fontWeight: '700', color: C.textPrimary, marginBottom: 16 },
  actionRow: {
    flexDirection: 'row', alignItems: 'center', gap: 14,
    paddingVertical: 16, borderBottomWidth: 1, borderBottomColor: C.borderLight,
  },
  actionText: { fontSize: 15, fontWeight: '500', color: C.textPrimary },
  textInput: {
    borderWidth: 1, borderColor: C.border, borderRadius: C.radiusBase,
    paddingHorizontal: 14, paddingVertical: 11,
    fontSize: 15, color: C.textPrimary, backgroundColor: C.surfaceAlt, marginBottom: 12,
  },
  fieldLabel: { fontSize: 13, fontWeight: '600', color: C.textSecondary, marginBottom: 8 },
  toggleRow: { flexDirection: 'row', gap: 10, marginBottom: 14 },
  toggleBtn: {
    flex: 1, paddingVertical: 10, borderRadius: C.radiusBase,
    borderWidth: 1, borderColor: C.border, alignItems: 'center',
  },
  toggleActive: { backgroundColor: C.primaryLight, borderColor: C.primary },
  toggleText: { fontSize: 13, fontWeight: '600', color: C.textSecondary },
  toggleTextActive: { color: C.primary },
  priorityBtn: {
    flex: 1, paddingVertical: 10, borderRadius: C.radiusBase,
    borderWidth: 1, borderColor: C.border, alignItems: 'center',
  },
  priorityBtnText: { fontSize: 12, fontWeight: '600', color: C.textSecondary },
  chipBtn: {
    paddingHorizontal: 14, paddingVertical: 8,
    borderRadius: C.radiusFull, borderWidth: 1, borderColor: C.border, marginRight: 8,
  },
  chipActive: { backgroundColor: C.primary, borderColor: C.primary },
  chipText: { fontSize: 13, color: C.textSecondary, fontWeight: '500' },
  chipTextActive: { color: C.textOnPrimary },
  dateBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    borderWidth: 1, borderColor: C.border, borderRadius: C.radiusBase,
    paddingHorizontal: 14, paddingVertical: 11, marginBottom: 12,
  },
  dateBtnText: { fontSize: 14, color: C.primary, fontWeight: '500' },
  primaryBtn: {
    backgroundColor: C.primary, borderRadius: C.radiusBase,
    paddingVertical: 13, alignItems: 'center', marginTop: 4,
  },
  btnDisabled: { opacity: 0.5 },
  primaryBtnText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 15 },

  // DatePickerField
  iosPickerWrap: {
    backgroundColor: '#fff', borderRadius: C.radiusBase,
    marginBottom: 12, overflow: 'hidden',
    borderWidth: 1, borderColor: C.border,
  },
  iosPickerConfirm: {
    backgroundColor: C.primary, paddingVertical: 10, alignItems: 'center',
  },
  iosPickerConfirmText: { color: '#fff', fontWeight: '700', fontSize: 15 },

  // Templates
  tplChip: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    paddingHorizontal: 12, paddingVertical: 7,
    borderRadius: C.radiusFull, borderWidth: 1, borderColor: C.border,
    backgroundColor: C.surfaceAlt, marginRight: 8,
  },
  tplChipText: { fontSize: 12, fontWeight: '600', color: C.primary },
});
