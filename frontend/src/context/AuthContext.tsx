import React, { createContext, useState, useEffect, ReactNode } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

type AuthContextType = {
  token: string | null;
  login: (token: string) => Promise<void>;
  logout: () => Promise<void>;
  isLoading: boolean;
};

export const AuthContext = createContext<AuthContextType>({
  token: null,
  login: async () => {},
  logout: async () => {},
  isLoading: true,
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Récupérer le token sauvegardé au démarrage
    AsyncStorage.getItem('auth_token').then(stored => {
      if (stored) setToken(stored);
      setIsLoading(false);
    });
  }, []);

  const login = async (newToken: string) => {
    await AsyncStorage.setItem('auth_token', newToken);
    setToken(newToken);
  };

  const logout = async () => {
    await AsyncStorage.removeItem('auth_token');
    setToken(null);
  };

  return (
    <AuthContext.Provider value={{ token, login, logout, isLoading }}>
      {children}
    </AuthContext.Provider>
  );
}
