import React, { useEffect, useState, useContext, useCallback } from 'react';
import { View, FlatList, StyleSheet, Alert, TouchableOpacity, Text } from 'react-native';
import { FAB, Portal, Modal, TextInput, Snackbar, Avatar } from 'react-native-paper';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as ImagePicker from 'expo-image-picker';
import * as MediaLibrary from 'expo-media-library';
import { useFocusEffect } from '@react-navigation/native';
import { useNavigation } from '@react-navigation/native';
import { C } from '../theme/colors';

export default function FamilyScreen() {
  const navigation = useNavigation<any>();
  const [families, setFamilies] = useState<any[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [familyName, setFamilyName] = useState('');
  const [familyDescription, setFamilyDescription] = useState('');
  const [loading, setLoading] = useState(false);
  const [snackbar, setSnackbar] = useState({ visible: false, message: '' });
  const [selectedFamily, setSelectedFamily] = useState<any>(null);
  const [inviteModalVisible, setInviteModalVisible] = useState(false);
  const [inviteEmail, setInviteEmail] = useState('');
  const [membersModalVisible, setMembersModalVisible] = useState(false);
  const [members, setMembers] = useState<any[]>([]);
  const [editModalVisible, setEditModalVisible] = useState(false);
  const [editDescription, setEditDescription] = useState('');
  const [editName, setEditName] = useState('');
  const [imageKey, setImageKey] = useState(0);

  const { token } = useContext(AuthContext);

  useEffect(() => {
    fetchFamilies();
  }, []);

  useFocusEffect(
    useCallback(() => {
      fetchFamilies();
      setImageKey(prev => prev + 1);
    }, [])
  );

  const fetchFamilies = async () => {
    setLoading(true);
    try {
      const res = await api.get('/families/', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setFamilies(res.data);
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors du chargement" });
    }
    setLoading(false);
  };

  const handleCreateFamily = async () => {
    try {
      await api.post('/families/', null, {
        params: { name: familyName },
        headers: { Authorization: `Bearer ${token}` }
      });
      setModalVisible(false);
      setFamilyName('');
      setFamilyDescription('');
      fetchFamilies();
      setSnackbar({ visible: true, message: "Famille créée !" });
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors de la création" });
    }
  };

  const handleLeave = async (familyId: number) => {
    Alert.alert("Quitter la famille", "Êtes-vous sûr ?", [
      { text: "Annuler" },
      {
        text: "Quitter",
        onPress: async () => {
          try {
            await api.post(`/families/${familyId}/leave`, {}, {
              headers: { Authorization: `Bearer ${token}` }
            });
            fetchFamilies();
            setSnackbar({ visible: true, message: "Famille quittée !" });
          } catch {
            setSnackbar({ visible: true, message: "Erreur" });
          }
        }
      }
    ]);
  };

  const handleViewMembers = async (family: any) => {
    setSelectedFamily(family);
    try {
      const res = await api.get(`/families/${family.id}/members`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setMembers(res.data);
      setMembersModalVisible(true);
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors du chargement des membres" });
    }
  };

  const handleEditFamily = (family: any) => {
    setSelectedFamily(family);
    setEditName(family.name || '');
    setEditDescription(family.description || '');
    setEditModalVisible(true);
  };

  const handleSaveEdit = async () => {
    try {
      await api.put(`/families/${selectedFamily.id}`, { name: editName, description: editDescription }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setEditModalVisible(false);
      fetchFamilies();
      setSnackbar({ visible: true, message: "Famille mise à jour !" });
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors de la mise à jour" });
    }
  };

  const handlePickImage = async () => {
    const { status } = await MediaLibrary.requestPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Permission refusée', "La permission d'accéder à la bibliothèque de médias est requise.");
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.7,
    });
    if (!result.canceled && result.assets && result.assets.length > 0) {
      const localUri = result.assets[0].uri;
      const formData = new FormData();
      formData.append('file', { uri: localUri, name: 'family.jpg', type: 'image/jpeg' } as any);
      try {
        await api.post(`/families/${selectedFamily.id}/family-image`, formData, {
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'multipart/form-data' },
        });
        setEditModalVisible(false);
        fetchFamilies();
        setSnackbar({ visible: true, message: "Image mise à jour !" });
      } catch {
        setSnackbar({ visible: true, message: "Erreur lors de l'upload" });
      }
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Mes Familles</Text>
          {families.length > 0 && (
            <Text style={styles.count}>{families.length}</Text>
          )}
          <TouchableOpacity
            onPress={() => navigation.navigate('Invitations')}
            style={styles.invitationsBtn}
          >
            <MaterialCommunityIcons name="email-outline" size={22} color={C.textSecondary} />
          </TouchableOpacity>
        </View>

        <FlatList
          data={families}
          keyExtractor={item => item.id.toString()}
          refreshing={loading}
          onRefresh={fetchFamilies}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: 100 }}
          ItemSeparatorComponent={() => <View style={{ height: 1, backgroundColor: C.borderLight, marginLeft: 72 }} />}
          renderItem={({ item }) => (
            <TouchableOpacity
              onPress={() => navigation.navigate('FamilyDetails', { familyId: item.id })}
              style={styles.row}
              activeOpacity={0.7}
            >
              {item.family_image ? (
                <Avatar.Image size={44} source={{ uri: `${api.defaults.baseURL + item.family_image}?t=${imageKey}` }} style={styles.avatar} />
              ) : (
                <View style={styles.avatarPlaceholder}>
                  <MaterialCommunityIcons name="account-group" size={22} color={C.primary} />
                </View>
              )}
              <View style={styles.rowContent}>
                <Text style={styles.rowTitle}>{item.name}</Text>
                {item.description ? (
                  <Text style={styles.rowSub} numberOfLines={1}>{item.description}</Text>
                ) : null}
              </View>
              <MaterialCommunityIcons name="chevron-right" size={20} color={C.textTertiary} />
            </TouchableOpacity>
          )}
          ListEmptyComponent={
            <View style={styles.empty}>
              <View style={styles.emptyIcon}>
                <MaterialCommunityIcons name="account-group-outline" size={40} color={C.primary} />
              </View>
              <Text style={styles.emptyTitle}>Aucune famille</Text>
              <Text style={styles.emptySub}>Appuyez sur "+" pour créer votre première famille.</Text>
            </View>
          }
        />

        <FAB
          style={styles.fab}
          icon="plus"
          label="Créer"
          onPress={() => setModalVisible(true)}
          color={C.textOnPrimary}
        />

        {/* Create modal */}
        <Portal>
          <Modal visible={modalVisible} onDismiss={() => setModalVisible(false)} contentContainerStyle={styles.modal}>
            <Text style={styles.modalTitle}>Nouvelle Famille</Text>
            <TextInput
              label="Nom de la famille"
              value={familyName}
              onChangeText={setFamilyName}
              style={styles.modalInput}
              mode="outlined"
            />
            <TouchableOpacity style={styles.modalPrimary} onPress={handleCreateFamily}>
              <Text style={styles.modalPrimaryText}>Créer</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.modalSecondary} onPress={() => setModalVisible(false)}>
              <Text style={styles.modalSecondaryText}>Annuler</Text>
            </TouchableOpacity>
          </Modal>
        </Portal>

        {/* Members modal */}
        <Portal>
          <Modal visible={membersModalVisible} onDismiss={() => setMembersModalVisible(false)} contentContainerStyle={styles.modal}>
            <Text style={styles.modalTitle}>Membres</Text>
            <FlatList
              data={members}
              keyExtractor={item => item.id.toString()}
              renderItem={({ item }) => (
                <View style={styles.memberRow}>
                  <MaterialCommunityIcons name="account-circle" size={36} color={C.textTertiary} />
                  <View style={{ marginLeft: 12 }}>
                    <Text style={styles.memberName}>{item.full_name}</Text>
                    <Text style={styles.memberEmail}>{item.email}</Text>
                  </View>
                </View>
              )}
              ListEmptyComponent={<Text style={styles.emptySub}>Aucun membre</Text>}
            />
            <TouchableOpacity style={styles.modalSecondary} onPress={() => setMembersModalVisible(false)}>
              <Text style={styles.modalSecondaryText}>Fermer</Text>
            </TouchableOpacity>
          </Modal>
        </Portal>

        {/* Edit modal */}
        <Portal>
          <Modal visible={editModalVisible} onDismiss={() => setEditModalVisible(false)} contentContainerStyle={styles.modal}>
            <Text style={styles.modalTitle}>Modifier la famille</Text>
            {selectedFamily?.family_image && (
              <Avatar.Image size={80} source={{ uri: api.defaults.baseURL + selectedFamily.family_image }} style={{ alignSelf: 'center', marginBottom: 16 }} />
            )}
            <TextInput label="Nom" value={editName} onChangeText={setEditName} style={styles.modalInput} mode="outlined" />
            <TextInput label="Description" value={editDescription} onChangeText={setEditDescription} style={styles.modalInput} mode="outlined" />
            <TouchableOpacity style={styles.modalOutline} onPress={handlePickImage}>
              <MaterialCommunityIcons name="image" size={18} color={C.primary} />
              <Text style={styles.modalOutlineText}>Changer l'image</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.modalPrimary} onPress={handleSaveEdit}>
              <Text style={styles.modalPrimaryText}>Sauvegarder</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.modalSecondary} onPress={() => setEditModalVisible(false)}>
              <Text style={styles.modalSecondaryText}>Annuler</Text>
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
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: C.background },
  container: { flex: 1, backgroundColor: C.background },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 12,
  },
  title: { fontSize: 24, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.3, flex: 1 },
  count: {
    fontSize: 13,
    fontWeight: '600',
    color: C.textOnPrimary,
    backgroundColor: C.primary,
    borderRadius: C.radiusFull,
    paddingHorizontal: 8,
    paddingVertical: 2,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 14,
    backgroundColor: C.surface,
  },
  avatar: { marginRight: 14 },
  avatarPlaceholder: {
    width: 44,
    height: 44,
    borderRadius: C.radiusFull,
    backgroundColor: C.primaryLight,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 14,
  },
  rowContent: { flex: 1 },
  rowTitle: { fontSize: 16, fontWeight: '600', color: C.textPrimary, marginBottom: 2 },
  rowSub: { fontSize: 13, color: C.textSecondary },
  empty: { alignItems: 'center', paddingTop: 80, paddingHorizontal: 40 },
  emptyIcon: {
    width: 80,
    height: 80,
    borderRadius: C.radius2xl,
    backgroundColor: C.primaryLight,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 20,
  },
  emptyTitle: { fontSize: 18, fontWeight: '700', color: C.textPrimary, marginBottom: 8 },
  emptySub: { fontSize: 14, color: C.textSecondary, textAlign: 'center', lineHeight: 20 },
  fab: { position: 'absolute', right: 20, bottom: 28, backgroundColor: C.primary },
  modal: {
    backgroundColor: C.surface,
    padding: 24,
    margin: 20,
    borderRadius: C.radiusXl,
    ...C.shadowMd,
  },
  modalTitle: { fontSize: 18, fontWeight: '700', color: C.textPrimary, marginBottom: 20 },
  modalInput: { marginBottom: 12, backgroundColor: C.surface },
  modalPrimary: {
    backgroundColor: C.primary,
    borderRadius: C.radiusBase,
    paddingVertical: 13,
    alignItems: 'center',
    marginBottom: 10,
  },
  modalPrimaryText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 15 },
  modalOutline: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    borderRadius: C.radiusBase,
    paddingVertical: 13,
    borderWidth: 1,
    borderColor: C.primary,
    marginBottom: 10,
  },
  modalOutlineText: { color: C.primary, fontWeight: '600', fontSize: 15 },
  modalSecondary: {
    borderRadius: C.radiusBase,
    paddingVertical: 13,
    alignItems: 'center',
  },
  modalSecondaryText: { color: C.textSecondary, fontWeight: '500', fontSize: 15 },
  invitationsBtn: { marginLeft: 12, padding: 4 },
  memberRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10 },
  memberName: { fontSize: 15, fontWeight: '600', color: C.textPrimary },
  memberEmail: { fontSize: 12, color: C.textSecondary, marginTop: 2 },
});
