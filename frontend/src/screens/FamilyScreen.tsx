import React, { useEffect, useState, useContext } from 'react';
import { View, FlatList, StyleSheet } from 'react-native';
import { Text, FAB, Card, Button, Portal, Modal, TextInput, Snackbar } from 'react-native-paper';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { SafeAreaView } from 'react-native-safe-area-context';


export default function FamilyScreen() {
  const [families, setFamilies] = useState([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [familyName, setFamilyName] = useState('');
  const [familyType, setFamilyType] = useState('core');
  const [loading, setLoading] = useState(false);
  const [snackbar, setSnackbar] = useState({ visible: false, message: '' });

  const { token } = useContext(AuthContext);

  useEffect(() => {
    fetchFamilies();
  }, []);

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
        params: { name: familyName, type: familyType },
        headers: { Authorization: `Bearer ${token}` }
      });
      setModalVisible(false);
      setFamilyName('');
      fetchFamilies();
      setSnackbar({ visible: true, message: "Famille créée !" });
    } catch {
      setSnackbar({ visible: true, message: "Erreur lors de la création" });
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: '#f6f6f6' }}>
      <View style={styles.container}>
        <Text variant="headlineMedium" style={styles.title}>Mes Familles</Text>
        <FlatList
          data={families}
          keyExtractor={item => item.id.toString()}
          refreshing={loading}
          onRefresh={fetchFamilies}
          renderItem={({ item }) => (
              <Card style={styles.card}>
              <Card.Title title={item.name} subtitle={item.type} />
              <Card.Content>
                  <Text>Id: {item.id}</Text>
              </Card.Content>
              </Card>
          )}
          ListEmptyComponent={
              <View style={{ alignItems: 'center', marginTop: 48 }}>
              <MaterialCommunityIcons name="account-group-outline" size={64} color="#bbb" />
              <Text style={{ fontSize: 18, color: '#888', marginTop: 16, textAlign: 'center' }}>
                  Vous n'appartenez à aucune famille pour l'instant.
              </Text>
              <Text style={{ fontSize: 16, color: '#aaa', marginTop: 8, textAlign: 'center' }}>
                  Appuyez sur "Créer" pour démarrer une nouvelle famille !
              </Text>
              </View>
          }
        />
        <FAB
          style={styles.fab}
          icon="plus"
          label="Créer"
          onPress={() => setModalVisible(true)}
        />
        <Portal>
          <Modal visible={modalVisible} onDismiss={() => setModalVisible(false)} contentContainerStyle={styles.modal}>
            <Text variant="titleLarge" style={{ marginBottom: 16 }}>Nouvelle Famille</Text>
            <TextInput
              label="Nom de la famille"
              value={familyName}
              onChangeText={setFamilyName}
              style={{ marginBottom: 12 }}
            />
            <TextInput
              label="Type (core/extended)"
              value={familyType}
              onChangeText={setFamilyType}
              style={{ marginBottom: 12 }}
            />
            <Button mode="contained" onPress={handleCreateFamily} style={{ marginBottom: 8 }}>
              Créer
            </Button>
            <Button onPress={() => setModalVisible(false)}>Annuler</Button>
          </Modal>
        </Portal>
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
  container: { flex: 1, padding: 16, backgroundColor: '#f6f6f6' },
  title: { marginBottom: 16, textAlign: 'center' },
  card: { marginBottom: 12 },
  fab: { position: 'absolute', right: 16, bottom: 32 },
  modal: { backgroundColor: 'white', padding: 24, margin: 24, borderRadius: 12 },
});