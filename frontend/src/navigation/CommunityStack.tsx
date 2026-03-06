import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import FamilyScreen from '../screens/FamilyScreen';
import FamilyDetailsScreen from '../screens/FamilyDetailsScreen';
import InvitationsScreen from '../screens/InvitationsScreen';

const Stack = createNativeStackNavigator();

export default function CommunityStack() {
  return (
    <Stack.Navigator>
      <Stack.Screen
        name="FamilyList"
        component={FamilyScreen}
        options={{ title: 'Mes Familles' }}
      />
      <Stack.Screen
        name="FamilyDetails"
        component={FamilyDetailsScreen}
        options={{ title: 'Détail famille' }}
      />
      <Stack.Screen
        name="Invitations"
        component={InvitationsScreen}
        options={{ title: 'Invitations' }}
      />
    </Stack.Navigator>
  );
}