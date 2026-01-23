import React, { createContext, useState, ReactNode } from 'react';

type AuthContextType = {
  token: string | null;
  login: (token: string) => void;
  logout: () => void;
};

export const AuthContext = createContext<AuthContextType>({
  token: null,
  login: () => {},
  logout: () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(null);

  return (
    <AuthContext.Provider
      value={{
        token,
        login: setToken,
        logout: () => setToken(null),
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
