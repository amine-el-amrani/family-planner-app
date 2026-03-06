import React, { useEffect, useState, useContext } from 'react';
import { View, StyleSheet, Alert, Text, TouchableOpacity, ScrollView } from 'react-native';
import { Avatar, Snackbar, ActivityIndicator, TextInput } from 'react-native-paper';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as ImagePicker from 'expo-image-picker';
import * as MediaLibrary from 'expo-media-library';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { C } from '../theme/colors';

export default function ProfileScreen() {
  const { token, logout } = useContext(AuthContext);
  const [profile, setProfile] = useState<any>(null);
  const [fullName, setFullName] = useState('');
  const [editing, setEditing] = useState(false);
  const [snackbar, setSnackbar] = useState({ visible: false, message: '' });
  const [loading, setLoading] = useState(true);
  const [imageKey, setImageKey] = useState(0);

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    setLoading(true);
    try {
      const res = await api.get('/users/me', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setProfile(res.data);
      setFullName(res.data.full_name);
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors du chargement" });
    }
    setLoading(false);
  };

  const handleSave = async () => {
    try {
      await api.put('/users/me', { full_name: fullName }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setEditing(false);
      fetchProfile();
      setSnackbar({ visible: true, message: "Profil mis à jour !" });
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
      formData.append('file', { uri: localUri, name: 'profile.jpg', type: 'image/jpeg' } as any);
      try {
        await api.post('/users/me/profile-image', formData, {
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'multipart/form-data' },
        });
        setImageKey(Date.now());
        fetchProfile();
        setSnackbar({ visible: true, message: "Photo mise à jour !" });
      } catch {
        setSnackbar({ visible: true, message: "Erreur lors de l'upload" });
      }
    }
  };

  if (loading) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: C.background }}>
        <ActivityIndicator color={C.primary} />
      </View>
    );
  }

  const avatarUri = profile?.profile_image
    ? `${profile.profile_image.startsWith('http') ? profile.profile_image : api.defaults.baseURL + profile.profile_image}?t=${imageKey}`
    : null;

  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView showsVerticalScrollIndicator={false}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.pageTitle}>Mon Profil</Text>
        </View>

        {/* Avatar section */}
        <View style={styles.avatarSection}>
          <View style={styles.avatarWrap}>
            {avatarUri ? (
              <Avatar.Image size={96} source={{ uri: avatarUri }} />
            ) : (
              <View style={styles.avatarPlaceholder}>
                <MaterialCommunityIcons name="account" size={44} color={C.primary} />
              </View>
            )}
            <TouchableOpacity style={styles.cameraBtn} onPress={handlePickImage} activeOpacity={0.85}>
              <MaterialCommunityIcons name="camera" size={16} color={C.textOnPrimary} />
            </TouchableOpacity>
          </View>
          <Text style={styles.avatarName}>{profile?.full_name}</Text>
          <Text style={styles.avatarEmail}>{profile?.email}</Text>
        </View>

        {/* Info section */}
        <View style={styles.section}>
          <Text style={styles.sectionLabel}>INFORMATIONS</Text>

          <View style={styles.infoRow}>
            <View style={styles.infoIcon}>
              <MaterialCommunityIcons name="email-outline" size={18} color={C.primary} />
            </View>
            <View style={styles.infoContent}>
              <Text style={styles.infoLabel}>Email</Text>
              <Text style={styles.infoValue}>{profile?.email}</Text>
            </View>
          </View>

          <View style={styles.separator} />

          <View style={styles.infoRow}>
            <View style={styles.infoIcon}>
              <MaterialCommunityIcons name="account-outline" size={18} color={C.primary} />
            </View>
            <View style={styles.infoContent}>
              <Text style={styles.infoLabel}>Nom complet</Text>
              {editing ? (
                <TextInput
                  value={fullName}
                  onChangeText={setFullName}
                  style={styles.nameInput}
                  mode="outlined"
                  dense
                />
              ) : (
                <Text style={styles.infoValue}>{profile?.full_name}</Text>
              )}
            </View>
            {!editing && (
              <TouchableOpacity onPress={() => setEditing(true)} style={styles.editIcon}>
                <MaterialCommunityIcons name="pencil-outline" size={18} color={C.textTertiary} />
              </TouchableOpacity>
            )}
          </View>

          {editing && (
            <View style={styles.editActions}>
              <TouchableOpacity style={styles.cancelBtn} onPress={() => setEditing(false)}>
                <Text style={styles.cancelBtnText}>Annuler</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.saveBtn} onPress={handleSave}>
                <Text style={styles.saveBtnText}>Sauvegarder</Text>
              </TouchableOpacity>
            </View>
          )}
        </View>

        {/* Logout */}
        <TouchableOpacity style={styles.logoutBtn} onPress={logout} activeOpacity={0.8}>
          <MaterialCommunityIcons name="logout" size={18} color={C.destructive} />
          <Text style={styles.logoutText}>Déconnexion</Text>
        </TouchableOpacity>
      </ScrollView>

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
  header: {
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 8,
  },
  pageTitle: { fontSize: 24, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.3 },
  avatarSection: { alignItems: 'center', paddingVertical: 32 },
  avatarWrap: { position: 'relative', marginBottom: 16 },
  avatarPlaceholder: {
    width: 96,
    height: 96,
    borderRadius: C.radiusFull,
    backgroundColor: C.primaryLight,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cameraBtn: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 32,
    height: 32,
    borderRadius: C.radiusFull,
    backgroundColor: C.primary,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: C.background,
  },
  avatarName: { fontSize: 20, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.3 },
  avatarEmail: { fontSize: 14, color: C.textSecondary, marginTop: 4 },
  section: {
    backgroundColor: C.surface,
    marginHorizontal: 16,
    borderRadius: C.radiusLg,
    borderWidth: 1,
    borderColor: C.borderLight,
    paddingHorizontal: 20,
    paddingVertical: 16,
    marginBottom: 16,
    ...C.shadowSm,
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: C.textTertiary,
    letterSpacing: 0.8,
    marginBottom: 16,
    textTransform: 'uppercase',
  },
  infoRow: { flexDirection: 'row', alignItems: 'center', minHeight: 48 },
  infoIcon: {
    width: 36,
    height: 36,
    borderRadius: C.radiusSm,
    backgroundColor: C.primaryLight,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 14,
  },
  infoContent: { flex: 1 },
  infoLabel: { fontSize: 11, fontWeight: '600', color: C.textTertiary, marginBottom: 3, letterSpacing: 0.2 },
  infoValue: { fontSize: 15, color: C.textPrimary, fontWeight: '500' },
  nameInput: { backgroundColor: C.surface, marginTop: 4 },
  editIcon: { padding: 6 },
  separator: { height: 1, backgroundColor: C.borderLight, marginVertical: 12, marginLeft: 50 },
  editActions: { flexDirection: 'row', gap: 10, marginTop: 16 },
  cancelBtn: {
    flex: 1,
    borderRadius: C.radiusBase,
    paddingVertical: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.border,
  },
  cancelBtnText: { color: C.textSecondary, fontWeight: '500', fontSize: 15 },
  saveBtn: {
    flex: 1,
    backgroundColor: C.primary,
    borderRadius: C.radiusBase,
    paddingVertical: 12,
    alignItems: 'center',
  },
  saveBtnText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 15 },
  logoutBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    marginHorizontal: 16,
    marginBottom: 32,
    paddingVertical: 14,
    borderRadius: C.radiusBase,
    borderWidth: 1,
    borderColor: C.destructive,
    backgroundColor: C.destructiveLight,
  },
  logoutText: { fontSize: 15, color: C.destructive, fontWeight: '600' },
});
