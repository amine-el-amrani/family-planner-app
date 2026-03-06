import React, { useState, useContext } from 'react';
import { View, TextInput, Text, Alert, StyleSheet, TouchableOpacity, KeyboardAvoidingView, Platform, ScrollView } from 'react-native';
import { AuthContext } from '../context/AuthContext';
import { api } from '../api/axios';
import { C } from '../theme/colors';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function LoginScreen({ navigation }: any) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useContext(AuthContext);

  const handleLogin = async () => {
    setLoading(true);
    try {
      const response = await api.post('/auth/login', { email, password });
      const token = response.data.access_token;
      login(token);
    } catch (error: any) {
      Alert.alert('Erreur', error.response?.data?.detail || 'Connexion échouée');
    }
    setLoading(false);
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <View style={styles.container}>
          {/* Logo mark */}
          <View style={styles.logoWrap}>
            <MaterialCommunityIcons name="home-heart" size={40} color={C.primary} />
          </View>

          <Text style={styles.title}>Bon retour</Text>
          <Text style={styles.subtitle}>Connectez-vous à votre compte</Text>

          <View style={styles.fieldWrap}>
            <Text style={styles.fieldLabel}>Email</Text>
            <TextInput
              style={styles.input}
              value={email}
              onChangeText={setEmail}
              placeholder="vous@example.com"
              autoCapitalize="none"
              keyboardType="email-address"
              placeholderTextColor={C.textPlaceholder}
            />
          </View>

          <View style={styles.fieldWrap}>
            <Text style={styles.fieldLabel}>Mot de passe</Text>
            <TextInput
              style={styles.input}
              value={password}
              onChangeText={setPassword}
              placeholder="Votre mot de passe"
              secureTextEntry
              placeholderTextColor={C.textPlaceholder}
            />
          </View>

          <TouchableOpacity
            style={[styles.button, loading && styles.buttonDisabled]}
            onPress={handleLogin}
            disabled={loading}
            activeOpacity={0.85}
          >
            <Text style={styles.buttonText}>{loading ? 'Connexion...' : 'Se connecter'}</Text>
          </TouchableOpacity>

          <TouchableOpacity onPress={() => navigation.navigate('Register')} style={styles.linkWrap}>
            <Text style={styles.linkText}>
              Pas de compte ?{' '}
              <Text style={styles.linkAccent}>Créer un compte</Text>
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  scroll: { flexGrow: 1 },
  container: {
    flex: 1,
    justifyContent: 'center',
    padding: 28,
    backgroundColor: C.background,
  },
  logoWrap: {
    width: 72,
    height: 72,
    borderRadius: C.radiusXl,
    backgroundColor: C.primaryLight,
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'center',
    marginBottom: 28,
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    color: C.textPrimary,
    textAlign: 'center',
    letterSpacing: -0.4,
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 15,
    color: C.textSecondary,
    textAlign: 'center',
    marginBottom: 32,
    letterSpacing: 0.1,
  },
  fieldWrap: { marginBottom: 16 },
  fieldLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: C.textSecondary,
    marginBottom: 6,
    letterSpacing: 0.1,
  },
  input: {
    backgroundColor: C.surface,
    borderRadius: C.radiusBase,
    paddingHorizontal: 14,
    paddingVertical: 13,
    fontSize: 15,
    borderWidth: 1,
    borderColor: C.border,
    color: C.textPrimary,
    ...C.shadowSm,
  },
  button: {
    backgroundColor: C.primary,
    borderRadius: C.radiusBase,
    paddingVertical: 15,
    alignItems: 'center',
    marginTop: 8,
    marginBottom: 20,
    ...C.shadowMd,
  },
  buttonDisabled: { opacity: 0.6 },
  buttonText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 16, letterSpacing: 0.1 },
  linkWrap: { alignItems: 'center' },
  linkText: { fontSize: 14, color: C.textSecondary },
  linkAccent: { color: C.primary, fontWeight: '600' },
});
