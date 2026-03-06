import React, { useContext, useEffect, useState } from 'react';
import { useWindowDimensions } from 'react-native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import HomeScreen from '../screens/HomeScreen';
import AgendaScreen from '../screens/AgendaScreen';
import ShoppingScreen from '../screens/ShoppingScreen';
import ProfileScreen from '../screens/ProfileScreen';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import CommunityStack from './CommunityStack';
import { C } from '../theme/colors';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';

const Tab = createBottomTabNavigator();

export default function AppNavigator() {
  const { token } = useContext(AuthContext);
  const [invitationCount, setInvitationCount] = useState(0);
  const { width } = useWindowDimensions();

  // Responsive tab sizing — 5 tabs, labels can be long (e.g. "Aujourd'hui")
  const tabFontSize = width < 360 ? 9 : width < 400 ? 10 : 11;
  const tabHeight = width < 360 ? 58 : 62;
  const tabIconSize = width < 360 ? 22 : 24;

  useEffect(() => {
    const fetchInvitations = async () => {
      try {
        const res = await api.get('/families/my-invitations', {
          headers: { Authorization: `Bearer ${token}` }
        });
        setInvitationCount(res.data.length);
      } catch {}
    };
    fetchInvitations();
    const interval = setInterval(fetchInvitations, 30000);
    return () => clearInterval(interval);
  }, [token]);

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: C.primary,
        tabBarInactiveTintColor: C.textTertiary,
        tabBarStyle: {
          backgroundColor: C.surface,
          borderTopColor: C.borderLight,
          borderTopWidth: 1,
          height: tabHeight,
          paddingBottom: 6,
          paddingTop: 4,
        },
        tabBarLabelStyle: {
          fontSize: tabFontSize,
          fontWeight: '500',
          marginTop: 1,
        },
        tabBarIconStyle: {
          marginTop: 2,
        },
      }}
    >
      <Tab.Screen
        name="Aujourd'hui"
        component={HomeScreen}
        options={{
          tabBarLabel: "Auj.",
          tabBarIcon: ({ color }) => (
            <MaterialCommunityIcons name="home-outline" color={color} size={tabIconSize} />
          ),
        }}
      />
      <Tab.Screen
        name="A venir"
        component={AgendaScreen}
        options={{
          tabBarLabel: 'Agenda',
          tabBarIcon: ({ color }) => (
            <MaterialCommunityIcons name="calendar-outline" color={color} size={tabIconSize} />
          ),
        }}
      />
      <Tab.Screen
        name="Shopping"
        component={ShoppingScreen}
        options={{
          tabBarLabel: 'Courses',
          tabBarIcon: ({ color }) => (
            <MaterialCommunityIcons name="cart-outline" color={color} size={tabIconSize} />
          ),
        }}
      />
      <Tab.Screen
        name="Communities"
        component={CommunityStack}
        options={{
          tabBarLabel: 'Familles',
          tabBarBadge: invitationCount > 0 ? invitationCount : undefined,
          tabBarIcon: ({ color }) => (
            <MaterialCommunityIcons name="account-group-outline" color={color} size={tabIconSize} />
          ),
        }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{
          tabBarLabel: 'Profil',
          tabBarIcon: ({ color }) => (
            <MaterialCommunityIcons name="account-circle-outline" color={color} size={tabIconSize} />
          ),
        }}
      />
    </Tab.Navigator>
  );
}
