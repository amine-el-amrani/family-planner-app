import React, { useEffect, useState, useContext } from 'react';
import { View, FlatList, StyleSheet, Alert, Dimensions, Image, Text, TouchableOpacity, ScrollView } from 'react-native';
import { Portal, Modal, TextInput, Snackbar, ActivityIndicator, Avatar } from 'react-native-paper';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRoute, useNavigation } from '@react-navigation/native';
import * as ImagePicker from 'expo-image-picker';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { C } from '../theme/colors';

const { width } = Dimensions.get('window');

export default function FamilyDetailsScreen() {
  const route = useRoute();
  const navigation = useNavigation<any>();
  const { familyId } = route.params as { familyId: number };
  const { token } = useContext(AuthContext);
  const [family, setFamily] = useState<any>(null);
  const [members, setMembers] = useState<any[]>([]);
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [snackbar, setSnackbar] = useState({ visible: false, message: '' });
  const [editingDescription, setEditingDescription] = useState(false);
  const [editDescription, setEditDescription] = useState('');
  const [isMember, setIsMember] = useState(false);
  const [isCreator, setIsCreator] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<number | null>(null);
  const [activeTab, setActiveTab] = useState<'about' | 'members' | 'events' | 'notes'>('about');
  const [imageKey, setImageKey] = useState(Date.now());
  const [inviteModalVisible, setInviteModalVisible] = useState(false);
  const [inviteEmail, setInviteEmail] = useState('');

  // Notes
  const [notes, setNotes] = useState<any[]>([]);
  const [newNoteContent, setNewNoteContent] = useState('');
  const [newNoteTitle, setNewNoteTitle] = useState('');
  const [selectedNoteColor, setSelectedNoteColor] = useState('#fff9c4');
  const [savingNote, setSavingNote] = useState(false);

  // Event creation modal
  const [createEventVisible, setCreateEventVisible] = useState(false);
  const [newEventTitle, setNewEventTitle] = useState('');
  const [newEventDate, setNewEventDate] = useState('');
  const [newEventTime, setNewEventTime] = useState('');
  const [newEventDesc, setNewEventDesc] = useState('');
  const [savingEvent, setSavingEvent] = useState(false);

  const headers = { Authorization: `Bearer ${token}` };

  useEffect(() => {
    fetchFamilyDetails();
  }, []);

  useEffect(() => {
    if (activeTab === 'events') fetchEvents();
    if (activeTab === 'notes') fetchNotes();
  }, [activeTab]);

  const fetchFamilyDetails = async () => {
    setLoading(true);
    try {
      const [membersRes, familiesRes, userRes] = await Promise.all([
        api.get(`/families/${familyId}/members`, { headers }),
        api.get('/families/', { headers }),
        api.get('/users/me', { headers }),
      ]);
      setMembers(membersRes.data);
      const fam = familiesRes.data.find((f: any) => f.id === familyId);
      setFamily(fam);
      setEditDescription(fam?.description || '');
      setIsMember(true);
      setCurrentUserId(userRes.data.id);
      setIsCreator(fam?.created_by_id === userRes.data.id);
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors du chargement" });
    }
    setLoading(false);
  };

  const fetchEvents = async () => {
    try {
      const res = await api.get('/events/my-events', {
        params: { family_id: familyId },
        headers,
      });
      setEvents(res.data);
    } catch {}
  };

  const handleSaveDescription = async () => {
    try {
      await api.put(`/families/${familyId}`, { description: editDescription }, { headers });
      setEditingDescription(false);
      fetchFamilyDetails();
      setSnackbar({ visible: true, message: "Description mise à jour !" });
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors de la mise à jour" });
    }
  };

  const handleInvite = async () => {
    try {
      await api.post(`/families/${familyId}/invite-member`, null, {
        params: { email: inviteEmail },
        headers,
      });
      setInviteModalVisible(false);
      setInviteEmail('');
      setSnackbar({ visible: true, message: "Invitation envoyée !" });
      fetchFamilyDetails();
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors de l'invitation" });
    }
  };

  const handlePickImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [4, 3],
      quality: 0.7,
    });
    if (!result.canceled && result.assets && result.assets.length > 0) {
      const localUri = result.assets[0].uri;
      const formData = new FormData();
      formData.append('file', { uri: localUri, name: 'family.jpg', type: 'image/jpeg' } as any);
      try {
        await api.post(`/families/${familyId}/family-image`, formData, {
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'multipart/form-data' },
        });
        setImageKey(Date.now());
        fetchFamilyDetails();
        setSnackbar({ visible: true, message: "Image mise à jour !" });
      } catch {
        setSnackbar({ visible: true, message: "Erreur lors de l'upload" });
      }
    }
  };

  const handleRemoveMember = async (userId: number, userName: string) => {
    Alert.alert("Supprimer le membre", `Êtes-vous sûr de supprimer ${userName} ?`, [
      { text: "Annuler" },
      {
        text: "Supprimer",
        onPress: async () => {
          try {
            await api.post(`/families/${familyId}/remove-member`, { user_id: userId }, { headers });
            fetchFamilyDetails();
            setSnackbar({ visible: true, message: "Membre supprimé !" });
          } catch {
            setSnackbar({ visible: true, message: "Erreur" });
          }
        }
      }
    ]);
  };

  const handleLeave = () => {
    Alert.alert("Quitter la famille", "Êtes-vous sûr ?", [
      { text: "Annuler" },
      {
        text: "Quitter",
        style: "destructive",
        onPress: async () => {
          try {
            await api.post(`/families/${familyId}/leave`, {}, { headers });
            navigation.goBack();
          } catch {
            setSnackbar({ visible: true, message: "Erreur lors du départ" });
          }
        }
      }
    ]);
  };

  const handleCreateEvent = async () => {
    if (!newEventTitle.trim() || !newEventDate.trim()) {
      setSnackbar({ visible: true, message: "Titre et date obligatoires" });
      return;
    }
    setSavingEvent(true);
    try {
      await api.post('/events/', {
        title: newEventTitle.trim(),
        description: newEventDesc.trim() || undefined,
        event_date: newEventDate,
        time_from: newEventTime || undefined,
        family_id: familyId,
      }, { headers });
      setCreateEventVisible(false);
      setNewEventTitle('');
      setNewEventDate('');
      setNewEventTime('');
      setNewEventDesc('');
      fetchEvents();
      setSnackbar({ visible: true, message: "Événement créé !" });
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors de la création" });
    }
    setSavingEvent(false);
  };

  const NOTE_COLORS = ['#fff9c4', '#c8e6c9', '#bbdefb', '#f8bbd0', '#ffe0b2', '#e1bee7'];

  const fetchNotes = async () => {
    try {
      const res = await api.get(`/notes/${familyId}`, { headers });
      setNotes(res.data);
    } catch {}
  };

  const handleCreateNote = async () => {
    if (!newNoteContent.trim()) return;
    setSavingNote(true);
    try {
      const res = await api.post(`/notes/${familyId}`, {
        content: newNoteContent.trim(),
        title: newNoteTitle.trim() || undefined,
        color: selectedNoteColor,
      }, { headers });
      setNotes(prev => [res.data, ...prev]);
      setNewNoteContent('');
      setNewNoteTitle('');
    } catch {
      setSnackbar({ visible: true, message: 'Erreur lors de la création' });
    }
    setSavingNote(false);
  };

  const handleDeleteNote = (note: any) => {
    Alert.alert('Supprimer la note', 'Confirmer ?', [
      { text: 'Annuler' },
      {
        text: 'Supprimer', style: 'destructive',
        onPress: async () => {
          try {
            await api.delete(`/notes/${note.id}`, { headers });
            setNotes(prev => prev.filter(n => n.id !== note.id));
          } catch {}
        },
      },
    ]);
  };

  const handleDeleteEvent = (event: any) => {
    if (event.created_by_id !== currentUserId) return;
    Alert.alert("Supprimer l'événement", `Supprimer "${event.title}" ?`, [
      { text: "Annuler" },
      {
        text: "Supprimer",
        style: "destructive",
        onPress: async () => {
          try {
            await api.delete(`/events/${event.id}`, { headers });
            fetchEvents();
            setSnackbar({ visible: true, message: "Événement supprimé" });
          } catch {
            setSnackbar({ visible: true, message: "Erreur" });
          }
        }
      }
    ]);
  };

  const TABS: { key: 'about' | 'members' | 'events' | 'notes'; label: string; icon: string }[] = [
    { key: 'about', label: 'À propos', icon: 'information-outline' },
    { key: 'members', label: 'Membres', icon: 'account-group-outline' },
    { key: 'events', label: 'Événements', icon: 'calendar-outline' },
    { key: 'notes', label: 'Notes', icon: 'note-text-outline' },
  ];

  const renderEventCard = (event: any) => {
    const isOwner = event.created_by_id === currentUserId;
    return (
      <View key={event.id} style={styles.eventCard}>
        <View style={styles.eventLeft}>
          <View style={styles.eventDot} />
        </View>
        <View style={styles.eventBody}>
          <Text style={styles.eventTitle}>{event.title}</Text>
          <Text style={styles.eventMeta}>
            {event.date}{event.time_from ? ` · ${event.time_from.substring(0, 5)}` : ''}
          </Text>
          {event.description ? (
            <Text style={styles.eventDesc}>{event.description}</Text>
          ) : null}
          <Text style={styles.eventCreator}>Par {event.created_by}</Text>
        </View>
        {isOwner && (
          <TouchableOpacity style={styles.deleteEventBtn} onPress={() => handleDeleteEvent(event)}>
            <MaterialCommunityIcons name="trash-can-outline" size={18} color={C.destructive} />
          </TouchableOpacity>
        )}
      </View>
    );
  };

  const renderTabContent = () => {
    if (activeTab === 'about') {
      return (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>À propos</Text>
          {editingDescription ? (
            <>
              <TextInput
                value={editDescription}
                onChangeText={setEditDescription}
                multiline
                style={styles.descInput}
                mode="outlined"
              />
              <View style={styles.rowBtns}>
                <TouchableOpacity style={styles.cancelBtn} onPress={() => setEditingDescription(false)}>
                  <Text style={styles.cancelBtnText}>Annuler</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.primaryBtn} onPress={handleSaveDescription}>
                  <Text style={styles.primaryBtnText}>Sauvegarder</Text>
                </TouchableOpacity>
              </View>
            </>
          ) : (
            <>
              <Text style={styles.descText}>{family?.description || "Aucune description"}</Text>
              {isMember && (
                <TouchableOpacity style={styles.textBtn} onPress={() => setEditingDescription(true)}>
                  <MaterialCommunityIcons name="pencil-outline" size={15} color={C.primary} />
                  <Text style={styles.textBtnLabel}>Modifier</Text>
                </TouchableOpacity>
              )}
            </>
          )}
        </View>
      );
    }

    if (activeTab === 'members') {
      return (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Membres · {members.length}</Text>
          {members.map((item: any) => (
            <View key={item.id} style={styles.memberRow}>
              {item.profile_image ? (
                <Avatar.Image size={40} source={{ uri: api.defaults.baseURL + item.profile_image }} />
              ) : (
                <View style={styles.memberAvatar}>
                  <MaterialCommunityIcons name="account" size={20} color={C.textTertiary} />
                </View>
              )}
              <View style={styles.memberInfo}>
                <Text style={styles.memberName}>{item.full_name}</Text>
                <Text style={styles.memberEmail}>{item.email}</Text>
              </View>
              {isCreator && item.id !== family?.created_by_id && (
                <TouchableOpacity
                  style={styles.removeBtn}
                  onPress={() => handleRemoveMember(item.id, item.full_name)}
                >
                  <MaterialCommunityIcons name="close" size={16} color={C.destructive} />
                </TouchableOpacity>
              )}
            </View>
          ))}
          {members.length === 0 && <Text style={styles.emptyText}>Aucun membre</Text>}

          <TouchableOpacity style={styles.inviteBtn} onPress={() => setInviteModalVisible(true)}>
            <MaterialCommunityIcons name="account-plus-outline" size={18} color={C.textOnPrimary} />
            <Text style={styles.inviteBtnText}>Inviter un membre</Text>
          </TouchableOpacity>

          {isMember && !isCreator && (
            <TouchableOpacity style={styles.leaveBtn} onPress={handleLeave}>
              <MaterialCommunityIcons name="logout" size={16} color={C.destructive} />
              <Text style={styles.leaveBtnText}>Quitter la famille</Text>
            </TouchableOpacity>
          )}
        </View>
      );
    }

    if (activeTab === 'events') {
      return (
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Événements · {events.length}</Text>
            <TouchableOpacity style={styles.addEventBtn} onPress={() => setCreateEventVisible(true)}>
              <MaterialCommunityIcons name="plus" size={16} color={C.textOnPrimary} />
              <Text style={styles.addEventBtnText}>Créer</Text>
            </TouchableOpacity>
          </View>
          {events.length === 0 ? (
            <View style={styles.emptyEvents}>
              <MaterialCommunityIcons name="calendar-blank-outline" size={40} color={C.textTertiary} />
              <Text style={styles.emptyText}>Aucun événement</Text>
            </View>
          ) : (
            events.map(renderEventCard)
          )}
        </View>
      );
    }
    if (activeTab === 'notes') {
      return (
        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { marginBottom: 16 }]}>Notes · {notes.length}</Text>

          {/* Create note form */}
          <View style={[styles.noteCreateCard, { backgroundColor: selectedNoteColor }]}>
            <TextInput
              value={newNoteTitle}
              onChangeText={setNewNoteTitle}
              placeholder="Titre (optionnel)"
              style={[styles.noteCreateInput, { fontWeight: '700', marginBottom: 6 }]}
              mode="flat"
              underlineColor="transparent"
              activeUnderlineColor="transparent"
              placeholderTextColor="rgba(0,0,0,0.35)"
            />
            <TextInput
              value={newNoteContent}
              onChangeText={setNewNoteContent}
              placeholder="Écrire une note..."
              multiline
              style={[styles.noteCreateInput, { minHeight: 68 }]}
              mode="flat"
              underlineColor="transparent"
              activeUnderlineColor="transparent"
              placeholderTextColor="rgba(0,0,0,0.35)"
            />
            {/* Color picker */}
            <View style={styles.noteColorRow}>
              {NOTE_COLORS.map(c => (
                <TouchableOpacity
                  key={c}
                  style={[styles.noteColorDot, { backgroundColor: c, borderWidth: selectedNoteColor === c ? 2 : 0, borderColor: '#333' }]}
                  onPress={() => setSelectedNoteColor(c)}
                />
              ))}
              <TouchableOpacity
                style={[styles.noteSaveBtn, !newNoteContent.trim() && { opacity: 0.4 }]}
                onPress={handleCreateNote}
                disabled={!newNoteContent.trim() || savingNote}
              >
                <MaterialCommunityIcons name={savingNote ? 'loading' : 'check'} size={18} color="#fff" />
              </TouchableOpacity>
            </View>
          </View>

          {/* Notes grid */}
          {notes.length === 0 ? (
            <View style={styles.emptyEvents}>
              <MaterialCommunityIcons name="note-outline" size={40} color={C.textTertiary} />
              <Text style={styles.emptyText}>Aucune note partagée</Text>
            </View>
          ) : (
            <View style={styles.notesGrid}>
              {notes.map((note: any) => (
                <View key={note.id} style={[styles.noteCard, { backgroundColor: note.color || '#fff9c4' }]}>
                  {note.title ? <Text style={styles.noteCardTitle}>{note.title}</Text> : null}
                  <Text style={styles.noteCardContent}>{note.content}</Text>
                  <View style={styles.noteCardFooter}>
                    <Text style={styles.noteCardAuthor}>{note.created_by}</Text>
                    {note.created_by_id === currentUserId && (
                      <TouchableOpacity onPress={() => handleDeleteNote(note)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
                        <MaterialCommunityIcons name="trash-can-outline" size={14} color="rgba(0,0,0,0.4)" />
                      </TouchableOpacity>
                    )}
                  </View>
                </View>
              ))}
            </View>
          )}
        </View>
      );
    }

    return null;
  };

  if (loading) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: C.background }}>
        <ActivityIndicator color={C.primary} />
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView showsVerticalScrollIndicator={false}>
        {/* Banner image */}
        <View style={styles.banner}>
          {family?.family_image ? (
            <Image source={{ uri: `${api.defaults.baseURL + family.family_image}?t=${imageKey}` }} style={styles.bannerImg} />
          ) : (
            <View style={[styles.bannerImg, styles.bannerPlaceholder]}>
              <MaterialCommunityIcons name="image-outline" size={48} color={C.textTertiary} />
            </View>
          )}
          {isMember && (
            <TouchableOpacity style={styles.cameraBtn} onPress={handlePickImage}>
              <MaterialCommunityIcons name="camera" size={18} color={C.textOnPrimary} />
            </TouchableOpacity>
          )}
        </View>

        {/* Family name */}
        <View style={styles.nameRow}>
          <Text style={styles.familyName}>{family?.name}</Text>
          <Text style={styles.memberCount}>{members.length} membre{members.length !== 1 ? 's' : ''}</Text>
        </View>

        {/* Tabs */}
        <View style={styles.tabs}>
          {TABS.map(tab => (
            <TouchableOpacity
              key={tab.key}
              style={[styles.tab, activeTab === tab.key && styles.tabActive]}
              onPress={() => setActiveTab(tab.key)}
              activeOpacity={0.7}
            >
              <MaterialCommunityIcons
                name={tab.icon as any}
                size={16}
                color={activeTab === tab.key ? C.primary : C.textTertiary}
              />
              <Text style={[styles.tabLabel, activeTab === tab.key && styles.tabLabelActive]}>
                {tab.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {renderTabContent()}
        <View style={{ height: 24 }} />
      </ScrollView>

      {/* Invite modal */}
      <Portal>
        <Modal visible={inviteModalVisible} onDismiss={() => setInviteModalVisible(false)} contentContainerStyle={styles.modal}>
          <Text style={styles.modalTitle}>Inviter un membre</Text>
          <TextInput
            label="Email"
            value={inviteEmail}
            onChangeText={setInviteEmail}
            style={{ marginBottom: 16, backgroundColor: C.surface }}
            mode="outlined"
            keyboardType="email-address"
            autoCapitalize="none"
          />
          <TouchableOpacity style={styles.primaryBtn} onPress={handleInvite}>
            <Text style={styles.primaryBtnText}>Inviter</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.cancelBtn, { marginTop: 8 }]} onPress={() => setInviteModalVisible(false)}>
            <Text style={styles.cancelBtnText}>Annuler</Text>
          </TouchableOpacity>
        </Modal>

        {/* Create event modal */}
        <Modal visible={createEventVisible} onDismiss={() => setCreateEventVisible(false)} contentContainerStyle={styles.modal}>
          <Text style={styles.modalTitle}>Créer un événement</Text>
          <TextInput
            label="Titre *"
            value={newEventTitle}
            onChangeText={setNewEventTitle}
            style={styles.modalInput}
            mode="outlined"
          />
          <TextInput
            label="Date * (YYYY-MM-DD)"
            value={newEventDate}
            onChangeText={setNewEventDate}
            style={styles.modalInput}
            mode="outlined"
            placeholder="2026-03-10"
          />
          <TextInput
            label="Heure (HH:MM)"
            value={newEventTime}
            onChangeText={setNewEventTime}
            style={styles.modalInput}
            mode="outlined"
            placeholder="14:30"
          />
          <TextInput
            label="Description"
            value={newEventDesc}
            onChangeText={setNewEventDesc}
            style={styles.modalInput}
            mode="outlined"
            multiline
          />
          <TouchableOpacity
            style={[styles.primaryBtn, savingEvent && { opacity: 0.6 }]}
            onPress={handleCreateEvent}
            disabled={savingEvent}
          >
            <Text style={styles.primaryBtnText}>{savingEvent ? 'Création...' : 'Créer'}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.cancelBtn, { marginTop: 8 }]} onPress={() => setCreateEventVisible(false)}>
            <Text style={styles.cancelBtnText}>Annuler</Text>
          </TouchableOpacity>
        </Modal>
      </Portal>

      <Snackbar
        visible={snackbar.visible}
        onDismiss={() => setSnackbar({ visible: false, message: '' })}
        duration={2000}
        style={{ backgroundColor: C.textPrimary }}
      >
        {snackbar.message}
      </Snackbar>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: C.background },
  banner: { height: 220, position: 'relative' },
  bannerImg: { width: '100%', height: '100%', resizeMode: 'cover' },
  bannerPlaceholder: { backgroundColor: C.surfaceHover, alignItems: 'center', justifyContent: 'center' },
  cameraBtn: {
    position: 'absolute',
    bottom: 14,
    right: 14,
    width: 40,
    height: 40,
    borderRadius: C.radiusFull,
    backgroundColor: C.primary,
    alignItems: 'center',
    justifyContent: 'center',
    ...C.shadowMd,
  },
  nameRow: { paddingHorizontal: 20, paddingTop: 20, paddingBottom: 12 },
  familyName: { fontSize: 26, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.4, marginBottom: 4 },
  memberCount: { fontSize: 13, color: C.textSecondary },
  tabs: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: C.borderLight,
    paddingHorizontal: 12,
    marginBottom: 4,
    backgroundColor: C.surface,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 5,
    paddingVertical: 14,
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabActive: { borderBottomColor: C.primary },
  tabLabel: { fontSize: 13, fontWeight: '500', color: C.textTertiary },
  tabLabelActive: { color: C.primary, fontWeight: '700' },
  section: {
    backgroundColor: C.surface,
    marginHorizontal: 16,
    marginTop: 16,
    borderRadius: C.radiusLg,
    borderWidth: 1,
    borderColor: C.borderLight,
    padding: 20,
    ...C.shadowSm,
  },
  sectionHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 },
  sectionTitle: { fontSize: 14, fontWeight: '700', color: C.textSecondary, letterSpacing: 0.5, textTransform: 'uppercase' },
  addEventBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: C.primary,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: C.radiusBase,
  },
  addEventBtnText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 13 },
  descText: { fontSize: 15, color: C.textPrimary, lineHeight: 22 },
  descInput: { marginBottom: 12, backgroundColor: C.surface },
  textBtn: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 14, alignSelf: 'flex-start' },
  textBtnLabel: { fontSize: 14, color: C.primary, fontWeight: '600' },
  rowBtns: { flexDirection: 'row', gap: 10 },
  primaryBtn: {
    backgroundColor: C.primary,
    borderRadius: C.radiusBase,
    paddingVertical: 13,
    alignItems: 'center',
  },
  primaryBtnText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 15 },
  cancelBtn: {
    borderRadius: C.radiusBase,
    paddingVertical: 13,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.border,
  },
  cancelBtnText: { color: C.textSecondary, fontWeight: '500', fontSize: 15 },
  memberRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 14 },
  memberAvatar: {
    width: 40,
    height: 40,
    borderRadius: C.radiusFull,
    backgroundColor: C.surfaceHover,
    alignItems: 'center',
    justifyContent: 'center',
  },
  memberInfo: { flex: 1, marginLeft: 12 },
  memberName: { fontSize: 15, fontWeight: '600', color: C.textPrimary },
  memberEmail: { fontSize: 12, color: C.textSecondary, marginTop: 2 },
  removeBtn: {
    width: 32,
    height: 32,
    borderRadius: C.radiusFull,
    backgroundColor: C.destructiveLight,
    alignItems: 'center',
    justifyContent: 'center',
  },
  inviteBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: C.primary,
    borderRadius: C.radiusBase,
    paddingVertical: 13,
    marginTop: 8,
    marginBottom: 12,
  },
  inviteBtnText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 15 },
  leaveBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    borderRadius: C.radiusBase,
    paddingVertical: 13,
    borderWidth: 1,
    borderColor: C.destructive,
  },
  leaveBtnText: { color: C.destructive, fontWeight: '600', fontSize: 15 },
  eventCard: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 14,
    paddingBottom: 14,
    borderBottomWidth: 1,
    borderBottomColor: C.borderLight,
  },
  eventLeft: { alignItems: 'center', paddingTop: 5, marginRight: 12 },
  eventDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: C.primary },
  eventBody: { flex: 1 },
  eventTitle: { fontSize: 15, fontWeight: '600', color: C.textPrimary, marginBottom: 3 },
  eventMeta: { fontSize: 12, color: C.primary, fontWeight: '600', marginBottom: 3 },
  eventDesc: { fontSize: 13, color: C.textSecondary, marginBottom: 3 },
  eventCreator: { fontSize: 11, color: C.textTertiary },
  deleteEventBtn: {
    padding: 6,
    borderRadius: C.radiusFull,
  },
  emptyText: { fontSize: 14, color: C.textSecondary, textAlign: 'center', marginTop: 8 },
  emptyEvents: { alignItems: 'center', paddingVertical: 32 },
  modal: {
    backgroundColor: C.surface,
    padding: 24,
    margin: 20,
    borderRadius: C.radiusXl,
    ...C.shadowMd,
  },
  modalTitle: { fontSize: 18, fontWeight: '700', color: C.textPrimary, marginBottom: 20 },
  modalInput: { marginBottom: 12, backgroundColor: C.surface },

  // Notes
  noteCreateCard: {
    borderRadius: C.radiusLg, padding: 14, marginBottom: 16,
    ...C.shadowSm,
  },
  noteCreateInput: {
    backgroundColor: 'transparent', fontSize: 14, color: '#1a1a1a',
    paddingHorizontal: 0, paddingVertical: 0,
  },
  noteColorRow: {
    flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 10,
  },
  noteColorDot: {
    width: 22, height: 22, borderRadius: 11,
  },
  noteSaveBtn: {
    marginLeft: 'auto' as any,
    backgroundColor: 'rgba(0,0,0,0.4)', borderRadius: C.radiusFull,
    padding: 6,
  },
  notesGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  noteCard: {
    width: '47%', borderRadius: C.radiusLg, padding: 12,
    ...C.shadowSm, minHeight: 100,
  },
  noteCardTitle: { fontSize: 13, fontWeight: '700', color: '#1a1a1a', marginBottom: 4 },
  noteCardContent: { fontSize: 13, color: '#1a1a1a', lineHeight: 18, flex: 1 },
  noteCardFooter: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    marginTop: 8, borderTopWidth: 1, borderTopColor: 'rgba(0,0,0,0.1)', paddingTop: 6,
  },
  noteCardAuthor: { fontSize: 11, color: 'rgba(0,0,0,0.45)', fontStyle: 'italic' },
});
