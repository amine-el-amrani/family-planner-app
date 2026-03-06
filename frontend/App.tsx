import 'react-native-gesture-handler';
import React, { useEffect, useContext } from 'react';
import { Platform } from 'react-native';
import { MD3LightTheme, Provider as PaperProvider } from 'react-native-paper';
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import { AuthProvider, AuthContext } from './src/context/AuthContext';
import RootNavigator from './src/navigation/RootNavigator';
import { paperTheme } from './src/theme/colors';
import { api } from './src/api/axios';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

const theme = {
  ...MD3LightTheme,
  colors: { ...MD3LightTheme.colors, ...paperTheme.colors },
};

function PushRegistrar() {
  const { token } = useContext(AuthContext);

  useEffect(() => {
    if (!token) return;
    async function registerPush() {
      if (!Device.isDevice) return;
      const { status: existing } = await Notifications.getPermissionsAsync();
      let finalStatus = existing;
      if (existing !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        finalStatus = status;
      }
      if (finalStatus !== 'granted') return;
      if (Platform.OS === 'android') {
        await Notifications.setNotificationChannelAsync('default', {
          name: 'default',
          importance: Notifications.AndroidImportance.MAX,
          vibrationPattern: [0, 250, 250, 250],
          lightColor: '#e44232',
        });
      }
      try {
        const pushToken = (await Notifications.getExpoPushTokenAsync()).data;
        await api.put('/users/me/push-token', { token: pushToken }, {
          headers: { Authorization: `Bearer ${token}` },
        });
      } catch {}
    }
    registerPush();
  }, [token]);

  return null;
}

export default function App() {
  return (
    <PaperProvider theme={theme}>
      <AuthProvider>
        <PushRegistrar />
        <RootNavigator />
      </AuthProvider>
    </PaperProvider>
  );
}
