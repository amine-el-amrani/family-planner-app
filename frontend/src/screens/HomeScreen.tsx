import React, { useContext } from 'react';
import { View, Text, Button, StyleSheet, Image } from 'react-native';
import { AuthContext } from '../context/AuthContext';

export default function HomeScreen({ navigation }: any) {
  const { logout } = useContext(AuthContext);

  return (
    <View style={styles.container}>
      <Image
        source={{ uri: 'https://img.icons8.com/color/96/000000/home--v2.png' }}
        style={styles.image}
      />
      <Text style={styles.title}>Welcome Home!</Text>
      <Text style={styles.subtitle}>You are logged in 🎉</Text>
      <View style={styles.buttonContainer}>
        <Button title="Logout" onPress={logout} color="#4f8cff" />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24, backgroundColor: '#f6f6f6' },
  image: { width: 96, height: 96, marginBottom: 24 },
  title: { fontSize: 32, fontWeight: 'bold', color: '#222', marginBottom: 8, textAlign: 'center' },
  subtitle: { fontSize: 16, color: '#666', marginBottom: 32, textAlign: 'center' },
  buttonContainer: { width: '100%', marginTop: 16 },
});