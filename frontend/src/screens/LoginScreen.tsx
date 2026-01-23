import React, { useState, useContext } from 'react';
import { View, TextInput, Button, Text, Alert, StyleSheet, TouchableOpacity } from 'react-native';
import { AuthContext } from '../context/AuthContext';
import { api } from '../api/axios';

export default function LoginScreen({ navigation }: any) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { login } = useContext(AuthContext);

  const handleLogin = async () => {
    try {
      const response = await api.post('/auth/login', { email, password });
      const token = response.data.access_token;
      login(token);
      Alert.alert('Success', 'Logged in successfully!');
    } catch (error: any) {
      Alert.alert('Error', error.response?.data?.detail || 'Login failed');
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Welcome Back 👋</Text>
      <Text style={styles.subtitle}>Login to your account</Text>
      <TextInput
        style={styles.input}
        value={email}
        onChangeText={setEmail}
        placeholder="Email"
        autoCapitalize="none"
        keyboardType="email-address"
        placeholderTextColor="#aaa"
      />
      <TextInput
        style={styles.input}
        value={password}
        onChangeText={setPassword}
        placeholder="Password"
        secureTextEntry={true}
        placeholderTextColor="#aaa"
      />
      <TouchableOpacity style={styles.button} onPress={handleLogin}>
        <Text style={styles.buttonText}>Login</Text>
      </TouchableOpacity>
      <TouchableOpacity onPress={() => navigation.navigate('Register')}>
        <Text style={styles.link}>Don't have an account? Register</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: '#f6f6f6' },
  title: { fontSize: 32, fontWeight: 'bold', color: '#222', marginBottom: 8, textAlign: 'center' },
  subtitle: { fontSize: 16, color: '#666', marginBottom: 32, textAlign: 'center' },
  input: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#eee',
    shadowColor: '#000',
    shadowOpacity: 0.03,
    shadowRadius: 4,
    elevation: 2,
  },
  button: {
    backgroundColor: '#4f8cff',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginBottom: 16,
    shadowColor: '#4f8cff',
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 2,
  },
  buttonText: { color: '#fff', fontWeight: 'bold', fontSize: 18 },
  link: { color: '#4f8cff', textAlign: 'center', marginTop: 8 },
});