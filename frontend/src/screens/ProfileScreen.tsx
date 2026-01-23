import React, { useEffect, useState, useContext } from 'react';
import { View, StyleSheet, Image } from 'react-native';
import { Text, TextInput, Button, Snackbar, Avatar, ActivityIndicator } from 'react-native-paper';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import * as ImagePicker from 'expo-image-picker';
import { SafeAreaView } from 'react-native-safe-area-context';


export default function ProfileScreen() {
  const { token, logout } = useContext(AuthContext);
  const [profile, setProfile] = useState<any>(null);
  const [fullName, setFullName] = useState('');
  const [editing, setEditing] = useState(false);
  const [snackbar, setSnackbar] = useState({ visible: false, message: '' });
  const [loading, setLoading] = useState(true);

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
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaType.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.7,
    });
    if (!result.canceled && result.assets && result.assets.length > 0) {
      const localUri = result.assets[0].uri;
      const formData = new FormData();
      formData.append('file', {
        uri: localUri,
        name: 'profile.jpg',
        type: 'image/jpeg',
      } as any);
      try {
        await api.post('/users/me/profile-image', formData, {
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'multipart/form-data',
          },
        });
        fetchProfile();
        setSnackbar({ visible: true, message: "Photo mise à jour !" });
      } catch {
        setSnackbar({ visible: true, message: "Erreur lors de l'upload" });
      }
    }
  };

  if (loading) {
    return <ActivityIndicator style={{ marginTop: 64 }} />;
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#f6f6f6' }}>
        <View style={styles.container}>
        <Text variant="headlineMedium" style={styles.title}>Mon Profil</Text>
        <View style={styles.avatarContainer}>
            {profile?.profile_image ? (
            <Avatar.Image size={100} source={{ uri: profile.profile_image.startsWith('http') ? profile.profile_image : api.defaults.baseURL + profile.profile_image }} />
            ) : (
            <Avatar.Icon size={100} icon="account" />
            )}
            <Button mode="outlined" style={{ marginTop: 8 }} onPress={handlePickImage}>
            Modifier la photo
            </Button>
        </View>
        <TextInput
            label="Nom complet"
            value={fullName}
            onChangeText={setFullName}
            style={styles.input}
            disabled={!editing}
        />
        <TextInput
            label="Email"
            value={profile?.email || ''}
            style={styles.input}
            disabled
        />
        <View style={styles.buttonRow}>
            {editing ? (
            <Button mode="contained" onPress={handleSave} style={styles.button}>Enregistrer</Button>
            ) : (
            <Button mode="contained" onPress={() => setEditing(true)} style={styles.button}>Modifier</Button>
            )}
            <Button mode="outlined" onPress={logout} style={styles.button}>Déconnexion</Button>
        </View>
        <Snackbar
            visible={snackbar.visible}
            onDismiss={() => setSnackbar({ visible: false, message: '' })}
            duration={2000}
        >
            {snackbar.message}
        </Snackbar>
        </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24, backgroundColor: '#f6f6f6' },
  title: { textAlign: 'center', marginBottom: 16 },
  avatarContainer: { alignItems: 'center', marginBottom: 24 },
  input: { marginBottom: 16, backgroundColor: '#fff' },
  buttonRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 16 },
  button: { flex: 1, marginHorizontal: 4 },
});