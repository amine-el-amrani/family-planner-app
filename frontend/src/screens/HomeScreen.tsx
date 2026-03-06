import React, { useContext, useEffect, useState, useRef, useCallback } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, Animated,
  RefreshControl, TextInput as RNTextInput, Platform, Alert,
  Modal, KeyboardAvoidingView, Pressable, Keyboard,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { FAB } from 'react-native-paper';
import DateTimePicker from '@react-native-community/datetimepicker';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { C } from '../theme/colors';
import { useFocusEffect, useNavigation } from '@react-navigation/native';

// ─── Types ───────────────────────────────────────────────────────────────────

type Task = {
  id: number;
  title: string;
  description?: string;
  status: 'en_attente' | 'fait' | 'annule';
  priority: 'normale' | 'haute' | 'urgente';
  due_date?: string;
  visibility: 'prive' | 'famille';
  family_id?: number;
  family_name?: string;
  assigned_to_id?: number;
  assigned_to_name?: string;
  created_by_id: number;
  created_by_name: string;
};

type EventItem = {
  id: number;
  title: string;
  description?: string;
  date: string;
  time_from?: string;
  family_name?: string;
  family_id?: number;
  created_by_id?: number;
};

type KarmaData = {
  karma_total: number;
  daily_goal: number;
  daily_completed: number;
  weekly_completed: number;
};

type Family = { id: number; name: string };
type Member = { id: number; full_name: string; email: string };

// ─── Templates ───────────────────────────────────────────────────────────────

const TASK_TEMPLATES = [
  { icon: 'dog', label: 'Sortir le chien', title: 'Sortir le chien' },
  { icon: 'trash-can-outline', label: 'Poubelle', title: 'Sortir la poubelle' },
  { icon: 'cart-outline', label: 'Courses', title: 'Faire les courses' },
  { icon: 'broom', label: 'Ménage', title: 'Faire le ménage' },
  { icon: 'run', label: 'Sport', title: 'Faire du sport' },
  { icon: 'chef-hat', label: 'Cuisine', title: 'Préparer le repas' },
];

const EVENT_TEMPLATES = [
  { icon: 'cake-variant', label: 'Anniversaire', title: 'Anniversaire' },
  { icon: 'party-popper', label: 'Fête', title: 'Fête en famille' },
  { icon: 'car-outline', label: 'Sortie', title: 'Sortie en famille' },
  { icon: 'walk', label: 'Balade', title: 'Balade en famille' },
  { icon: 'tent', label: 'Camping', title: 'Weekend camping' },
  { icon: 'silverware-fork-knife', label: 'Repas', title: 'Repas en famille' },
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

const JOURS = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
const MOIS = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

function getGreeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Bonjour';
  if (h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

function getDateLabel(): string {
  const d = new Date();
  return `${JOURS[d.getDay()]} ${d.getDate()} ${MOIS[d.getMonth()]}`;
}

function formatDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function formatTime(date: Date): string {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

const PRIORITY_BORDER: Record<string, string> = {
  urgente: '#ef4444',
  haute: '#f97316',
  normale: C.borderLight,
};

const PRIORITY_LABELS: Record<string, string> = {
  normale: 'Normale',
  haute: 'Haute',
  urgente: 'Urgente',
};

const PRIORITY_ACTIVE: Record<string, string> = {
  urgente: '#ef4444',
  haute: '#f97316',
  normale: C.primary,
};

// ─── DatePickerField ──────────────────────────────────────────────────────────
// Cross-platform date/time picker: Android = native dialog, iOS = white spinner

function DatePickerField({
  value, onChange, mode = 'date', placeholder, clearable, onClear,
}: {
  value: Date | null;
  onChange: (d: Date) => void;
  mode?: 'date' | 'time';
  placeholder: string;
  clearable?: boolean;
  onClear?: () => void;
}) {
  const [show, setShow] = useState(false);
  const [iosTemp, setIosTemp] = useState<Date>(value || new Date());
  const icon = mode === 'time' ? 'clock-outline' : 'calendar-outline';
  const label = value
    ? mode === 'time' ? formatTime(value) : formatDate(value)
    : placeholder;

  return (
    <>
      <TouchableOpacity style={styles.dateBtn} onPress={() => { setIosTemp(value || new Date()); setShow(true); }}>
        <MaterialCommunityIcons name={icon as any} size={18} color={C.primary} />
        <Text style={[styles.dateBtnText, { flex: 1, color: value ? C.primary : C.textPlaceholder }]}>{label}</Text>
        {clearable && value && (
          <TouchableOpacity onPress={onClear} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
            <MaterialCommunityIcons name="close-circle" size={16} color={C.textTertiary} />
          </TouchableOpacity>
        )}
      </TouchableOpacity>

      {/* Android: native dialog */}
      {show && Platform.OS === 'android' && (
        <DateTimePicker
          value={value || new Date()}
          mode={mode}
          display="default"
          onChange={(event, selected) => {
            setShow(false);
            if (event.type !== 'dismissed' && selected) onChange(selected);
          }}
        />
      )}

      {/* iOS: white spinner with Confirm button */}
      {show && Platform.OS === 'ios' && (
        <View style={styles.iosPickerWrap}>
          <DateTimePicker
            value={iosTemp}
            mode={mode}
            display="spinner"
            textColor="#1a1a1a"
            onChange={(_, selected) => { if (selected) setIosTemp(selected); }}
            style={{ height: 150 }}
          />
          <TouchableOpacity
            style={styles.iosPickerConfirm}
            onPress={() => { setShow(false); onChange(iosTemp); }}
          >
            <Text style={styles.iosPickerConfirmText}>Confirmer</Text>
          </TouchableOpacity>
        </View>
      )}
    </>
  );
}

// ─── TaskItem ─────────────────────────────────────────────────────────────────

function TaskItem({
  task, onToggle, onLongPress,
}: {
  task: Task;
  onToggle: (task: Task) => void;
  onLongPress: (task: Task) => void;
}) {
  const anim = useRef(new Animated.Value(task.status === 'fait' ? 1 : 0)).current;

  useEffect(() => {
    Animated.spring(anim, { toValue: task.status === 'fait' ? 1 : 0, useNativeDriver: false, friction: 6 }).start();
  }, [task.status]);

  const bgColor = anim.interpolate({ inputRange: [0, 1], outputRange: ['transparent', C.primary] });
  const borderColor = anim.interpolate({ inputRange: [0, 1], outputRange: [C.border as string, C.primary] });
  const priorityBorderColor = PRIORITY_BORDER[task.priority] || C.borderLight;

  return (
    <TouchableOpacity
      style={[styles.taskRow, { borderLeftColor: priorityBorderColor }]}
      onPress={() => onToggle(task)}
      onLongPress={() => onLongPress(task)}
      activeOpacity={0.7}
      delayLongPress={400}
    >
      <Animated.View style={[styles.checkbox, { backgroundColor: bgColor, borderColor }]}>
        {task.status === 'fait' && <MaterialCommunityIcons name="check" size={12} color="#fff" />}
      </Animated.View>
      <View style={styles.taskContent}>
        <Text style={[styles.taskTitle, task.status === 'fait' && styles.taskDone]} numberOfLines={1}>
          {task.title}
        </Text>
        <View style={styles.taskMeta}>
          {task.due_date && (
            <View style={styles.metaChip}>
              <MaterialCommunityIcons name="calendar-outline" size={11} color={C.textTertiary} />
              <Text style={styles.metaText}>{task.due_date}</Text>
            </View>
          )}
          {task.family_name && (
            <View style={[styles.metaChip, styles.familyChip]}>
              <MaterialCommunityIcons name="account-group-outline" size={11} color="#3b82f6" />
              <Text style={[styles.metaText, { color: '#3b82f6' }]}>{task.family_name}</Text>
            </View>
          )}
          {task.assigned_to_name && (
            <View style={styles.metaChip}>
              <MaterialCommunityIcons name="account-outline" size={11} color={C.textTertiary} />
              <Text style={styles.metaText}>{task.assigned_to_name}</Text>
            </View>
          )}
        </View>
      </View>
    </TouchableOpacity>
  );
}

// ─── EventCard ────────────────────────────────────────────────────────────────

function EventCard({ event }: { event: EventItem }) {
  return (
    <View style={styles.eventCard}>
      <View style={styles.eventLeft}>
        {event.time_from ? (
          <Text style={styles.eventTime}>{event.time_from.slice(0, 5)}</Text>
        ) : (
          <Text style={styles.eventTimeAll}>Journée</Text>
        )}
        <Text style={styles.eventDate}>{event.date}</Text>
      </View>
      <View style={styles.eventContent}>
        <Text style={styles.eventTitle} numberOfLines={1}>{event.title}</Text>
        {event.family_name && (
          <View style={styles.eventFamilyTag}>
            <MaterialCommunityIcons name="account-group-outline" size={11} color="#3b82f6" />
            <Text style={styles.eventFamilyText}>{event.family_name}</Text>
          </View>
        )}
      </View>
    </View>
  );
}

// ─── KarmaWidget ──────────────────────────────────────────────────────────────

function KarmaWidget({ karma }: { karma: KarmaData }) {
  const progress = Math.min(karma.daily_completed / Math.max(karma.daily_goal, 1), 1);
  return (
    <View style={styles.karmaCard}>
      <View style={styles.karmaTop}>
        <View style={styles.karmaTrophyWrap}>
          <MaterialCommunityIcons name="trophy" size={22} color={C.primary} />
        </View>
        <View style={{ flex: 1, marginLeft: 12 }}>
          <Text style={styles.karmaPoints}>{karma.karma_total} pts karma</Text>
          <Text style={styles.karmaSub}>{karma.daily_completed}/{karma.daily_goal} tâches aujourd'hui</Text>
        </View>
        <View style={styles.weeklyWrap}>
          <Text style={styles.weeklyNum}>{karma.weekly_completed}</Text>
          <Text style={styles.weeklyLabel}>cette semaine</Text>
        </View>
      </View>
      <View style={styles.progressBg}>
        <View style={[styles.progressFill, { width: `${Math.round(progress * 100)}%` }]} />
      </View>
      {progress >= 1 && <Text style={styles.goalDone}>🎉 Objectif du jour atteint !</Text>}
    </View>
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

export default function HomeScreen() {
  const { token } = useContext(AuthContext);
  const navigation = useNavigation<any>();
  const headers = { Authorization: `Bearer ${token}` };

  const [userName, setUserName] = useState('');
  const [personalTasks, setPersonalTasks] = useState<Task[]>([]);
  const [assignedToMe, setAssignedToMe] = useState<Task[]>([]);
  const [familyTasks, setFamilyTasks] = useState<Task[]>([]);
  const [tomorrowUrgent, setTomorrowUrgent] = useState<Task[]>([]);
  const [weekEvents, setWeekEvents] = useState<EventItem[]>([]);
  const [karma, setKarma] = useState<KarmaData>({ karma_total: 0, daily_goal: 5, daily_completed: 0, weekly_completed: 0 });
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [unreadCount, setUnreadCount] = useState(0);

  // Bottom sheet (long press)
  const [sheet, setSheet] = useState<Task | null>(null);
  const [rescheduleMode, setRescheduleMode] = useState(false);
  const [rescheduleDate, setRescheduleDate] = useState<Date>(new Date());

  // FAB choice
  const [fabChoiceVisible, setFabChoiceVisible] = useState(false);

  // Create task
  const [createTaskVisible, setCreateTaskVisible] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newVisibility, setNewVisibility] = useState<'prive' | 'famille'>('prive');
  const [newPriority, setNewPriority] = useState<'normale' | 'haute' | 'urgente'>('normale');
  const [newFamilyId, setNewFamilyId] = useState<number | null>(null);
  const [newAssigneeId, setNewAssigneeId] = useState<number | null>(null);
  const [newDueDate, setNewDueDate] = useState<Date | null>(null);
  const [families, setFamilies] = useState<Family[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [creating, setCreating] = useState(false);

  // Create event
  const [createEventVisible, setCreateEventVisible] = useState(false);
  const [evTitle, setEvTitle] = useState('');
  const [evDesc, setEvDesc] = useState('');
  const [evFamilyId, setEvFamilyId] = useState<number | null>(null);
  const [evDate, setEvDate] = useState<Date>(new Date());
  const [evTime, setEvTime] = useState<Date | null>(null);
  const [creatingEvent, setCreatingEvent] = useState(false);

  const fetchUnread = useCallback(async () => {
    try {
      const res = await api.get('/notifications/unread-count', { headers });
      setUnreadCount(res.data.count || 0);
    } catch {}
  }, [token]);

  const fetchAll = useCallback(async () => {
    try {
      const [todayRes, karmaRes, userRes, weekRes] = await Promise.all([
        api.get('/tasks/today', { headers }),
        api.get('/users/me/karma', { headers }),
        api.get('/users/me', { headers }),
        api.get('/events/this-week', { headers }),
      ]);
      setPersonalTasks(todayRes.data.personal || []);
      setAssignedToMe(todayRes.data.assigned_to_me || []);
      setFamilyTasks(todayRes.data.famille || []);
      setTomorrowUrgent(todayRes.data.tomorrow_urgent || []);
      setWeekEvents(weekRes.data || []);
      setKarma(karmaRes.data);
      setUserName((userRes.data.full_name || '').split(' ')[0]);
    } catch {}
  }, [token]);

  useFocusEffect(
    useCallback(() => {
      fetchAll();
      fetchUnread();
    }, [fetchAll, fetchUnread])
  );

  const onRefresh = async () => {
    setRefreshing(true);
    await Promise.all([fetchAll(), fetchUnread()]);
    setRefreshing(false);
  };

  const handleToggle = async (task: Task) => {
    const newStatus = task.status === 'fait' ? 'en_attente' : 'fait';
    const update = (list: Task[]) => list.map(t => t.id === task.id ? { ...t, status: newStatus as Task['status'] } : t);
    setPersonalTasks(update);
    setAssignedToMe(update);
    setFamilyTasks(update);
    setTomorrowUrgent(update);
    try {
      await api.patch(`/tasks/${task.id}`, { status: newStatus }, { headers });
      const karmaRes = await api.get('/users/me/karma', { headers });
      setKarma(karmaRes.data);
    } catch {
      const rb = (list: Task[]) => list.map(t => t.id === task.id ? { ...t, status: task.status } : t);
      setPersonalTasks(rb); setAssignedToMe(rb); setFamilyTasks(rb); setTomorrowUrgent(rb);
    }
  };

  const handleCancel = async (task: Task) => {
    try {
      await api.patch(`/tasks/${task.id}`, { status: 'annule' }, { headers });
      setSheet(null);
      await fetchAll();
    } catch { Alert.alert('Erreur', "Impossible d'annuler cette tâche"); }
  };

  const handleDelete = (task: Task) => {
    Alert.alert('Supprimer', 'Confirmer la suppression ?', [
      { text: 'Non' },
      {
        text: 'Supprimer', style: 'destructive',
        onPress: async () => {
          try {
            await api.delete(`/tasks/${task.id}`, { headers });
            setSheet(null);
            await fetchAll();
          } catch { Alert.alert('Erreur', 'Impossible de supprimer cette tâche'); }
        },
      },
    ]);
  };

  const handleReschedule = async () => {
    if (!sheet) return;
    try {
      await api.patch(`/tasks/${sheet.id}`, { due_date: formatDate(rescheduleDate) }, { headers });
      setSheet(null);
      setRescheduleMode(false);
      await fetchAll();
    } catch { Alert.alert('Erreur', 'Impossible de déplacer cette tâche'); }
  };

  const openFabChoice = async () => {
    try {
      const res = await api.get('/events/my-families', { headers });
      setFamilies(res.data);
    } catch {}
    setFabChoiceVisible(true);
  };

  const openCreateTask = () => {
    setFabChoiceVisible(false);
    setNewTitle(''); setNewVisibility('prive'); setNewPriority('normale');
    setNewFamilyId(null); setNewAssigneeId(null); setNewDueDate(null); setMembers([]);
    setCreateTaskVisible(true);
  };

  const openCreateEvent = () => {
    setFabChoiceVisible(false);
    setEvTitle(''); setEvDesc(''); setEvFamilyId(null);
    setEvDate(new Date()); setEvTime(null);
    setCreateEventVisible(true);
  };

  const handleSelectFamily = async (fid: number) => {
    setNewFamilyId(fid); setNewAssigneeId(null);
    try {
      const res = await api.get(`/families/${fid}/members`, { headers });
      setMembers(res.data);
    } catch {}
  };

  const handleCreateTask = async () => {
    if (!newTitle.trim()) return;
    setCreating(true);
    try {
      await api.post('/tasks/', {
        title: newTitle.trim(),
        visibility: newVisibility,
        priority: newPriority,
        family_id: newFamilyId || null,
        assigned_to_id: newAssigneeId || null,
        due_date: newDueDate ? formatDate(newDueDate) : null,
      }, { headers });
      setCreateTaskVisible(false);
      await fetchAll();
    } catch { Alert.alert('Erreur', 'Impossible de créer la tâche'); }
    setCreating(false);
  };

  const handleCreateEvent = async () => {
    if (!evTitle.trim() || !evFamilyId) {
      Alert.alert('Erreur', 'Titre et famille obligatoires');
      return;
    }
    setCreatingEvent(true);
    try {
      await api.post('/events/', {
        title: evTitle.trim(),
        description: evDesc.trim() || undefined,
        event_date: formatDate(evDate),
        time_from: evTime ? formatTime(evTime) : undefined,
        family_id: evFamilyId,
      }, { headers });
      setCreateEventVisible(false);
      await fetchAll();
    } catch { Alert.alert('Erreur', "Impossible de créer l'événement"); }
    setCreatingEvent(false);
  };

  const filterTasks = (tasks: Task[]) => {
    if (!searchQuery.trim()) return tasks;
    const q = searchQuery.toLowerCase();
    return tasks.filter(t => t.title.toLowerCase().includes(q));
  };

  // Merge private tasks + tasks assigned to me into one "my tasks" list
  const myTasks = [...personalTasks, ...assignedToMe];

  const filteredMy = filterTasks(myTasks);
  const filteredFamily = filterTasks(familyTasks);
  const filteredTomorrow = filterTasks(tomorrowUrgent);

  const pendingMy = filteredMy.filter(t => t.status === 'en_attente');
  const doneMy = filteredMy.filter(t => t.status === 'fait');
  const pendingFamily = filteredFamily.filter(t => t.status === 'en_attente');
  const doneFamily = filteredFamily.filter(t => t.status === 'fait');

  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: 100 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={C.primary} />}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        {/* ── En-tête ── */}
        <View style={styles.header}>
          <View style={{ flex: 1 }}>
            <Text style={styles.dateLabel}>{getDateLabel()}</Text>
            <Text style={styles.greeting}>{getGreeting()}{userName ? `, ${userName}` : ''} 👋</Text>
          </View>
          <TouchableOpacity style={styles.bellBtn} onPress={() => navigation.navigate('Notifications')}>
            <MaterialCommunityIcons name="bell-outline" size={24} color={C.textPrimary} />
            {unreadCount > 0 && (
              <View style={styles.bellBadge}>
                <Text style={styles.bellBadgeText}>{unreadCount > 9 ? '9+' : unreadCount}</Text>
              </View>
            )}
          </TouchableOpacity>
        </View>

        {/* ── Recherche ── */}
        <View style={styles.searchWrap}>
          <MaterialCommunityIcons name="magnify" size={18} color={C.textTertiary} style={{ marginRight: 8 }} />
          <RNTextInput
            style={styles.searchInput}
            placeholder="Rechercher une tâche..."
            placeholderTextColor={C.textPlaceholder}
            value={searchQuery}
            onChangeText={setSearchQuery}
          />
          {searchQuery.length > 0 && (
            <TouchableOpacity onPress={() => setSearchQuery('')}>
              <MaterialCommunityIcons name="close-circle" size={16} color={C.textTertiary} />
            </TouchableOpacity>
          )}
        </View>

        {/* ── Widget Karma ── */}
        <View style={{ paddingHorizontal: 20, marginBottom: 24 }}>
          <KarmaWidget karma={karma} />
        </View>

        {/* ── Mes tâches (privées + assignées) ── */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Mes tâches</Text>
            {filteredMy.length > 0 && (
              <View style={styles.badge}><Text style={styles.badgeText}>{filteredMy.length}</Text></View>
            )}
          </View>
          {pendingMy.length === 0 && doneMy.length === 0 ? (
            <View style={styles.emptySection}>
              <MaterialCommunityIcons name="check-circle-outline" size={32} color={C.borderLight} />
              <Text style={styles.emptyText}>{searchQuery ? 'Aucun résultat' : "Aucune tâche pour aujourd'hui"}</Text>
            </View>
          ) : (
            <>
              {pendingMy.map(t => (
                <TaskItem key={t.id} task={t} onToggle={handleToggle}
                  onLongPress={tk => { setSheet(tk); setRescheduleMode(false); }} />
              ))}
              {doneMy.map(t => (
                <TaskItem key={t.id} task={t} onToggle={handleToggle}
                  onLongPress={tk => { setSheet(tk); setRescheduleMode(false); }} />
              ))}
            </>
          )}
        </View>

        {/* ── Famille ── */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Famille</Text>
            {filteredFamily.length > 0 && (
              <View style={[styles.badge, { backgroundColor: '#3b82f6' }]}>
                <Text style={styles.badgeText}>{filteredFamily.length}</Text>
              </View>
            )}
          </View>
          {pendingFamily.length === 0 && doneFamily.length === 0 ? (
            <View style={styles.emptySection}>
              <MaterialCommunityIcons name="account-group-outline" size={32} color={C.borderLight} />
              <Text style={styles.emptyText}>{searchQuery ? 'Aucun résultat' : "Aucune tâche familiale pour aujourd'hui"}</Text>
            </View>
          ) : (
            <>
              {pendingFamily.map(t => (
                <TaskItem key={t.id} task={t} onToggle={handleToggle}
                  onLongPress={tk => { setSheet(tk); setRescheduleMode(false); }} />
              ))}
              {doneFamily.map(t => (
                <TaskItem key={t.id} task={t} onToggle={handleToggle}
                  onLongPress={tk => { setSheet(tk); setRescheduleMode(false); }} />
              ))}
            </>
          )}
        </View>

        {/* ── Urgent demain ── */}
        {filteredTomorrow.length > 0 && (
          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <MaterialCommunityIcons name="alert-circle-outline" size={17} color="#f97316" style={{ marginRight: 6 }} />
              <Text style={[styles.sectionTitle, { color: '#f97316', flex: 0 }]}>Urgent demain</Text>
              <View style={[styles.badge, { backgroundColor: '#f97316', marginLeft: 8 }]}>
                <Text style={styles.badgeText}>{filteredTomorrow.length}</Text>
              </View>
            </View>
            {filteredTomorrow.map(t => (
              <TaskItem key={t.id} task={t} onToggle={handleToggle}
                onLongPress={tk => { setSheet(tk); setRescheduleMode(false); }} />
            ))}
          </View>
        )}

        {/* ── Événements cette semaine ── */}
        {weekEvents.length > 0 && (
          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <MaterialCommunityIcons name="calendar-week" size={17} color="#3b82f6" style={{ marginRight: 6 }} />
              <Text style={[styles.sectionTitle, { color: '#3b82f6', flex: 0 }]}>Cette semaine</Text>
              <View style={[styles.badge, { backgroundColor: '#3b82f6', marginLeft: 8 }]}>
                <Text style={styles.badgeText}>{weekEvents.length}</Text>
              </View>
            </View>
            {weekEvents.map(e => <EventCard key={e.id} event={e} />)}
          </View>
        )}
      </ScrollView>

      <FAB icon="plus" style={styles.fab} color={C.textOnPrimary} onPress={openFabChoice} />

      {/* ── FAB Choice Modal ── */}
      <Modal visible={fabChoiceVisible} transparent animationType="fade" onRequestClose={() => setFabChoiceVisible(false)}>
        <Pressable style={styles.overlayCenter} onPress={() => { Keyboard.dismiss(); setFabChoiceVisible(false); }}>
          <Pressable style={styles.choiceBox} onPress={() => {}}>
            <Text style={styles.choiceTitle}>Que voulez-vous créer ?</Text>
            <TouchableOpacity style={styles.choiceBtn} onPress={openCreateTask}>
              <View style={[styles.choiceIcon, { backgroundColor: C.primaryLight }]}>
                <MaterialCommunityIcons name="format-list-checks" size={22} color={C.primary} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.choiceBtnTitle}>Tâche</Text>
                <Text style={styles.choiceBtnSub}>Personnelle ou familiale</Text>
              </View>
              <MaterialCommunityIcons name="chevron-right" size={20} color={C.textTertiary} />
            </TouchableOpacity>
            <TouchableOpacity style={[styles.choiceBtn, { borderBottomWidth: 0 }]} onPress={openCreateEvent}>
              <View style={[styles.choiceIcon, { backgroundColor: '#eff6ff' }]}>
                <MaterialCommunityIcons name="calendar-plus" size={22} color="#3b82f6" />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.choiceBtnTitle}>Événement</Text>
                <Text style={styles.choiceBtnSub}>Pour une famille</Text>
              </View>
              <MaterialCommunityIcons name="chevron-right" size={20} color={C.textTertiary} />
            </TouchableOpacity>
          </Pressable>
        </Pressable>
      </Modal>

      {/* ── Bottom Sheet (long press) ── */}
      <Modal visible={!!sheet} transparent animationType="slide" onRequestClose={() => { setSheet(null); setRescheduleMode(false); }}>
        <Pressable style={styles.overlayBottom} onPress={() => { Keyboard.dismiss(); setSheet(null); setRescheduleMode(false); }} />
        <View style={styles.sheet}>
          {sheet && !rescheduleMode && (
            <>
              <View style={styles.sheetHandle} />
              <Text style={styles.sheetTitle} numberOfLines={1}>{sheet.title}</Text>
              <TouchableOpacity style={styles.sheetItem} onPress={() => setRescheduleMode(true)}>
                <MaterialCommunityIcons name="calendar-edit" size={20} color={C.textPrimary} />
                <Text style={styles.sheetItemText}>Déplacer à une autre date</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.sheetItem} onPress={() => handleCancel(sheet)}>
                <MaterialCommunityIcons name="close-circle-outline" size={20} color={C.textSecondary} />
                <Text style={styles.sheetItemText}>Annuler la tâche</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.sheetItem} onPress={() => handleDelete(sheet)}>
                <MaterialCommunityIcons name="delete-outline" size={20} color={C.destructive} />
                <Text style={[styles.sheetItemText, { color: C.destructive }]}>Supprimer</Text>
              </TouchableOpacity>
            </>
          )}
          {sheet && rescheduleMode && (
            <>
              <View style={styles.sheetHandle} />
              <Text style={styles.sheetTitle}>Choisir une nouvelle date</Text>
              <DatePickerField
                value={rescheduleDate}
                onChange={d => setRescheduleDate(d)}
                mode="date"
                placeholder="Date"
              />
              <TouchableOpacity style={styles.sheetPrimary} onPress={handleReschedule}>
                <Text style={styles.sheetPrimaryText}>Confirmer</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => setRescheduleMode(false)} style={{ alignItems: 'center', marginTop: 8 }}>
                <Text style={{ color: C.textSecondary, fontSize: 14 }}>Retour</Text>
              </TouchableOpacity>
            </>
          )}
        </View>
      </Modal>

      {/* ── Modal Créer Tâche ── */}
      <Modal visible={createTaskVisible} transparent animationType="fade" onRequestClose={() => setCreateTaskVisible(false)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={styles.kavContainer}>
          <Pressable style={{ flex: 1 }} onPress={() => { Keyboard.dismiss(); setCreateTaskVisible(false); }} />
          <View style={styles.centeredModal}>
            <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              <Text style={styles.modalTitle}>Nouvelle tâche</Text>

              {/* Templates */}
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 14 }}>
                {TASK_TEMPLATES.map(tpl => (
                  <TouchableOpacity
                    key={tpl.label}
                    style={styles.tplChip}
                    onPress={() => setNewTitle(tpl.title)}
                  >
                    <MaterialCommunityIcons name={tpl.icon as any} size={15} color={C.primary} />
                    <Text style={styles.tplChipText}>{tpl.label}</Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>

              <RNTextInput
                style={styles.textInput}
                placeholder="Titre de la tâche"
                placeholderTextColor={C.textPlaceholder}
                value={newTitle}
                onChangeText={setNewTitle}
                autoFocus
              />
              <Text style={styles.fieldLabel}>Visibilité</Text>
              <View style={styles.toggleRow}>
                {(['prive', 'famille'] as const).map(v => (
                  <TouchableOpacity
                    key={v}
                    style={[styles.toggleBtn, newVisibility === v && styles.toggleActive]}
                    onPress={() => { setNewVisibility(v); if (v === 'prive') { setNewFamilyId(null); setNewAssigneeId(null); } }}
                  >
                    <Text style={[styles.toggleText, newVisibility === v && styles.toggleTextActive]}>
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
                    style={[styles.priorityBtn, newPriority === p && { backgroundColor: PRIORITY_ACTIVE[p], borderColor: PRIORITY_ACTIVE[p] }]}
                    onPress={() => setNewPriority(p)}
                  >
                    <Text style={[styles.priorityBtnText, newPriority === p && { color: '#fff' }]}>{PRIORITY_LABELS[p]}</Text>
                  </TouchableOpacity>
                ))}
              </View>
              {newVisibility === 'famille' && families.length > 0 && (
                <>
                  <Text style={styles.fieldLabel}>Famille</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 12 }}>
                    {families.map((f: Family) => (
                      <TouchableOpacity
                        key={f.id}
                        style={[styles.chipBtn, newFamilyId === f.id && styles.chipActive]}
                        onPress={() => handleSelectFamily(f.id)}
                      >
                        <Text style={[styles.chipText, newFamilyId === f.id && styles.chipTextActive]}>{f.name}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </>
              )}
              {newFamilyId !== null && members.length > 0 && (
                <>
                  <Text style={styles.fieldLabel}>Assigner à</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 12 }}>
                    <TouchableOpacity
                      style={[styles.chipBtn, newAssigneeId === null && styles.chipActive]}
                      onPress={() => setNewAssigneeId(null)}
                    >
                      <Text style={[styles.chipText, newAssigneeId === null && styles.chipTextActive]}>Personne</Text>
                    </TouchableOpacity>
                    {members.map((m: Member) => (
                      <TouchableOpacity
                        key={m.id}
                        style={[styles.chipBtn, newAssigneeId === m.id && styles.chipActive]}
                        onPress={() => setNewAssigneeId(m.id)}
                      >
                        <Text style={[styles.chipText, newAssigneeId === m.id && styles.chipTextActive]}>{m.full_name}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </>
              )}
              <DatePickerField
                value={newDueDate}
                onChange={d => setNewDueDate(d)}
                mode="date"
                placeholder="Choisir une date (optionnel)"
                clearable
                onClear={() => setNewDueDate(null)}
              />
              <TouchableOpacity
                style={[styles.createBtn, (!newTitle.trim() || creating) && styles.createBtnDisabled]}
                onPress={handleCreateTask}
                disabled={!newTitle.trim() || creating}
              >
                <Text style={styles.createBtnText}>{creating ? 'Création...' : 'Créer la tâche'}</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => setCreateTaskVisible(false)} style={{ alignItems: 'center', marginTop: 8 }}>
                <Text style={{ color: C.textSecondary, fontSize: 14 }}>Annuler</Text>
              </TouchableOpacity>
            </ScrollView>
          </View>
          <View style={{ flex: 0.3 }} />
        </KeyboardAvoidingView>
      </Modal>

      {/* ── Modal Créer Événement ── */}
      <Modal visible={createEventVisible} transparent animationType="fade" onRequestClose={() => setCreateEventVisible(false)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={styles.kavContainer}>
          <Pressable style={{ flex: 1 }} onPress={() => { Keyboard.dismiss(); setCreateEventVisible(false); }} />
          <View style={styles.centeredModal}>
            <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              <Text style={styles.modalTitle}>Nouvel événement</Text>

              {/* Templates */}
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 14 }}>
                {EVENT_TEMPLATES.map(tpl => (
                  <TouchableOpacity
                    key={tpl.label}
                    style={styles.tplChip}
                    onPress={() => setEvTitle(tpl.title)}
                  >
                    <MaterialCommunityIcons name={tpl.icon as any} size={15} color="#3b82f6" />
                    <Text style={[styles.tplChipText, { color: '#3b82f6' }]}>{tpl.label}</Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>

              <RNTextInput
                style={styles.textInput}
                placeholder="Titre de l'événement"
                placeholderTextColor={C.textPlaceholder}
                value={evTitle}
                onChangeText={setEvTitle}
                autoFocus
              />
              <RNTextInput
                style={[styles.textInput, { height: 68 }]}
                placeholder="Description (optionnel)"
                placeholderTextColor={C.textPlaceholder}
                value={evDesc}
                onChangeText={setEvDesc}
                multiline
              />
              <DatePickerField
                value={evDate}
                onChange={d => setEvDate(d)}
                mode="date"
                placeholder="Date de l'événement"
              />
              <DatePickerField
                value={evTime}
                onChange={d => setEvTime(d)}
                mode="time"
                placeholder="Heure (optionnel)"
                clearable
                onClear={() => setEvTime(null)}
              />
              {families.length > 0 && (
                <>
                  <Text style={styles.fieldLabel}>Famille *</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 14 }}>
                    {families.map(f => (
                      <TouchableOpacity
                        key={f.id}
                        style={[styles.chipBtn, evFamilyId === f.id && styles.chipActive]}
                        onPress={() => setEvFamilyId(f.id)}
                      >
                        <Text style={[styles.chipText, evFamilyId === f.id && styles.chipTextActive]}>{f.name}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </>
              )}
              <TouchableOpacity
                style={[styles.createBtn, (!evTitle.trim() || !evFamilyId || creatingEvent) && styles.createBtnDisabled]}
                onPress={handleCreateEvent}
                disabled={!evTitle.trim() || !evFamilyId || creatingEvent}
              >
                <Text style={styles.createBtnText}>{creatingEvent ? 'Création...' : "Créer l'événement"}</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => setCreateEventVisible(false)} style={{ alignItems: 'center', marginTop: 8 }}>
                <Text style={{ color: C.textSecondary, fontSize: 14 }}>Annuler</Text>
              </TouchableOpacity>
            </ScrollView>
          </View>
          <View style={{ flex: 0.3 }} />
        </KeyboardAvoidingView>
      </Modal>
    </SafeAreaView>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: C.background },

  header: { paddingHorizontal: 20, paddingTop: 16, paddingBottom: 12, flexDirection: 'row', alignItems: 'center' },
  dateLabel: { fontSize: 13, color: C.textTertiary, fontWeight: '500', marginBottom: 2 },
  greeting: { fontSize: 22, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.3 },

  bellBtn: {
    width: 44, height: 44, borderRadius: C.radiusFull,
    backgroundColor: C.surface, alignItems: 'center', justifyContent: 'center',
    borderWidth: 1, borderColor: C.borderLight, position: 'relative',
  },
  bellBadge: {
    position: 'absolute', top: -2, right: -2,
    backgroundColor: C.primary, borderRadius: C.radiusFull,
    minWidth: 18, height: 18, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 3,
  },
  bellBadgeText: { fontSize: 10, fontWeight: '700', color: C.textOnPrimary },

  searchWrap: {
    flexDirection: 'row', alignItems: 'center',
    marginHorizontal: 20, marginBottom: 20,
    backgroundColor: C.surface, borderRadius: C.radiusBase,
    borderWidth: 1, borderColor: C.borderLight,
    paddingHorizontal: 12, paddingVertical: 10,
  },
  searchInput: { flex: 1, fontSize: 14, color: C.textPrimary },

  karmaCard: { backgroundColor: C.surface, borderRadius: C.radiusXl, padding: 16, ...C.shadowMd },
  karmaTop: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  karmaTrophyWrap: { width: 40, height: 40, borderRadius: C.radiusBase, backgroundColor: C.primaryLight, alignItems: 'center', justifyContent: 'center' },
  karmaPoints: { fontSize: 16, fontWeight: '700', color: C.textPrimary },
  karmaSub: { fontSize: 12, color: C.textSecondary, marginTop: 2 },
  weeklyWrap: { alignItems: 'center' },
  weeklyNum: { fontSize: 20, fontWeight: '800', color: C.primary },
  weeklyLabel: { fontSize: 10, color: C.textTertiary, marginTop: 1 },
  progressBg: { height: 6, borderRadius: C.radiusFull, backgroundColor: C.surfaceHover, overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: C.radiusFull, backgroundColor: C.primary },
  goalDone: { fontSize: 12, color: C.primary, fontWeight: '600', marginTop: 8, textAlign: 'center' },

  section: { marginBottom: 24, paddingHorizontal: 20 },
  sectionHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  sectionTitle: { fontSize: 17, fontWeight: '700', color: C.textPrimary, flex: 1 },
  badge: { backgroundColor: C.primary, borderRadius: C.radiusFull, paddingHorizontal: 8, paddingVertical: 2 },
  badgeText: { fontSize: 12, fontWeight: '700', color: C.textOnPrimary },
  emptySection: { alignItems: 'center', paddingVertical: 24, gap: 8 },
  emptyText: { fontSize: 13, color: C.textTertiary },

  taskRow: {
    flexDirection: 'row', alignItems: 'flex-start',
    paddingVertical: 10, paddingLeft: 8, paddingRight: 4,
    borderBottomWidth: 1, borderBottomColor: C.borderLight,
    marginBottom: 2, borderLeftWidth: 3,
  },
  checkbox: { width: 20, height: 20, borderRadius: C.radiusFull, borderWidth: 2, marginRight: 12, marginTop: 2, alignItems: 'center', justifyContent: 'center' },
  taskContent: { flex: 1 },
  taskTitle: { fontSize: 15, color: C.textPrimary, fontWeight: '500', marginBottom: 4 },
  taskDone: { textDecorationLine: 'line-through', color: C.textTertiary },
  taskMeta: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  metaChip: { flexDirection: 'row', alignItems: 'center', gap: 3, backgroundColor: C.surfaceAlt, borderRadius: C.radiusFull, paddingHorizontal: 6, paddingVertical: 2 },
  familyChip: { backgroundColor: '#eff6ff' },
  metaText: { fontSize: 11, color: C.textTertiary },

  eventCard: { flexDirection: 'row', backgroundColor: C.surface, borderRadius: C.radiusBase, padding: 12, marginBottom: 8, borderLeftWidth: 3, borderLeftColor: '#3b82f6', ...C.shadowSm },
  eventLeft: { width: 64, marginRight: 12, justifyContent: 'center' },
  eventTime: { fontSize: 12, fontWeight: '700', color: '#3b82f6' },
  eventTimeAll: { fontSize: 11, color: C.textTertiary, fontStyle: 'italic' },
  eventDate: { fontSize: 11, color: C.textTertiary, marginTop: 2 },
  eventContent: { flex: 1 },
  eventTitle: { fontSize: 14, fontWeight: '600', color: C.textPrimary, marginBottom: 4 },
  eventFamilyTag: { flexDirection: 'row', alignItems: 'center', gap: 4, backgroundColor: '#eff6ff', borderRadius: C.radiusFull, paddingHorizontal: 6, paddingVertical: 2, alignSelf: 'flex-start' },
  eventFamilyText: { fontSize: 11, color: '#3b82f6', fontWeight: '500' },

  fab: { position: 'absolute', right: 20, bottom: 28, backgroundColor: C.primary },

  overlayCenter: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'center', paddingHorizontal: 24 },
  overlayBottom: { flex: 1, backgroundColor: 'rgba(0,0,0,0.35)' },

  choiceBox: { backgroundColor: C.surface, borderRadius: C.radiusXl, padding: 20, ...C.shadowMd },
  choiceTitle: { fontSize: 16, fontWeight: '700', color: C.textPrimary, marginBottom: 16 },
  choiceBtn: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: C.borderLight },
  choiceIcon: { width: 44, height: 44, borderRadius: C.radiusBase, alignItems: 'center', justifyContent: 'center' },
  choiceBtnTitle: { fontSize: 15, fontWeight: '600', color: C.textPrimary },
  choiceBtnSub: { fontSize: 12, color: C.textTertiary, marginTop: 2 },

  sheet: { position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: C.surface, borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 20, paddingBottom: 36 },
  sheetHandle: { width: 36, height: 4, borderRadius: 2, backgroundColor: C.borderLight, alignSelf: 'center', marginBottom: 16 },
  sheetTitle: { fontSize: 16, fontWeight: '700', color: C.textPrimary, marginBottom: 16, paddingHorizontal: 4 },
  sheetItem: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: C.borderLight },
  sheetItemText: { fontSize: 15, color: C.textPrimary, fontWeight: '500' },
  sheetPrimary: { backgroundColor: C.primary, borderRadius: C.radiusBase, paddingVertical: 13, alignItems: 'center', marginTop: 12 },
  sheetPrimaryText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 15 },

  kavContainer: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)' },
  centeredModal: { backgroundColor: C.surface, marginHorizontal: 16, borderRadius: C.radiusXl, padding: 20, maxHeight: '80%' },
  modalTitle: { fontSize: 18, fontWeight: '700', color: C.textPrimary, marginBottom: 12 },
  textInput: {
    borderWidth: 1, borderColor: C.border, borderRadius: C.radiusBase,
    paddingHorizontal: 14, paddingVertical: 11,
    fontSize: 15, color: C.textPrimary,
    backgroundColor: C.surfaceAlt, marginBottom: 14,
  },
  fieldLabel: { fontSize: 13, fontWeight: '600', color: C.textSecondary, marginBottom: 8 },
  toggleRow: { flexDirection: 'row', gap: 10, marginBottom: 14 },
  toggleBtn: { flex: 1, paddingVertical: 10, borderRadius: C.radiusBase, borderWidth: 1, borderColor: C.border, alignItems: 'center' },
  toggleActive: { backgroundColor: C.primaryLight, borderColor: C.primary },
  toggleText: { fontSize: 13, fontWeight: '600', color: C.textSecondary },
  toggleTextActive: { color: C.primary },
  priorityBtn: { flex: 1, paddingVertical: 10, borderRadius: C.radiusBase, borderWidth: 1, borderColor: C.border, alignItems: 'center' },
  priorityBtnText: { fontSize: 12, fontWeight: '600', color: C.textSecondary },
  chipBtn: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: C.radiusFull, borderWidth: 1, borderColor: C.border, marginRight: 8 },
  chipActive: { backgroundColor: C.primary, borderColor: C.primary },
  chipText: { fontSize: 13, color: C.textSecondary, fontWeight: '500' },
  chipTextActive: { color: C.textOnPrimary },

  // Date picker
  dateBtn: { flexDirection: 'row', alignItems: 'center', gap: 8, borderWidth: 1, borderColor: C.border, borderRadius: C.radiusBase, paddingHorizontal: 14, paddingVertical: 11, marginBottom: 14 },
  dateBtnText: { fontSize: 14, color: C.primary, fontWeight: '500' },
  iosPickerWrap: { backgroundColor: '#fff', borderRadius: 12, overflow: 'hidden', marginBottom: 14, borderWidth: 1, borderColor: C.borderLight },
  iosPickerConfirm: { backgroundColor: C.primary, paddingVertical: 11, alignItems: 'center' },
  iosPickerConfirmText: { color: '#fff', fontWeight: '700', fontSize: 14 },

  // Templates
  tplChip: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 12, paddingVertical: 7, borderRadius: C.radiusFull, borderWidth: 1, borderColor: C.primaryLight, backgroundColor: C.primaryLight, marginRight: 8 },
  tplChipText: { fontSize: 12, fontWeight: '600', color: C.primary },

  createBtn: { backgroundColor: C.primary, borderRadius: C.radiusBase, paddingVertical: 13, alignItems: 'center', marginTop: 4 },
  createBtnDisabled: { opacity: 0.5 },
  createBtnText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 15 },
});
