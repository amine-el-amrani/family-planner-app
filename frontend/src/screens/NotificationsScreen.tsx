import React, { useContext, useEffect, useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, FlatList, TouchableOpacity, Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { C } from '../theme/colors';
import { useNavigation } from '@react-navigation/native';

type Notif = {
  id: number;
  message: string;
  read: boolean;
  created_by: string | null;
  related_entity_type: string | null;
  related_entity_id: number | null;
  created_at: string | null;
};

function timeAgo(dateStr: string | null): string {
  if (!dateStr) return '';
  const diff = (Date.now() - new Date(dateStr).getTime()) / 1000;
  if (diff < 60) return 'à l\'instant';
  if (diff < 3600) return `il y a ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `il y a ${Math.floor(diff / 3600)} h`;
  return `il y a ${Math.floor(diff / 86400)} j`;
}

function notifIcon(type: string | null): string {
  switch (type) {
    case 'family': return 'account-group-outline';
    case 'task': return 'format-list-checks';
    case 'event': return 'calendar-outline';
    case 'invitation': return 'email-outline';
    default: return 'bell-outline';
  }
}

function notifColor(type: string | null): string {
  switch (type) {
    case 'family': return '#3b82f6';
    case 'event': return '#8b5cf6';
    case 'invitation': return '#f59e0b';
    default: return C.primary;
  }
}

export default function NotificationsScreen() {
  const { token } = useContext(AuthContext);
  const navigation = useNavigation<any>();
  const headers = { Authorization: `Bearer ${token}` };

  const [notifs, setNotifs] = useState<Notif[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchNotifs = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/notifications/', { headers });
      setNotifs(res.data);
    } catch {}
    setLoading(false);
  }, [token]);

  useEffect(() => { fetchNotifs(); }, []);

  const handleRead = async (notif: Notif) => {
    // Navigate to related entity
    if (notif.related_entity_type === 'invitation') {
      navigation.navigate('Main', { screen: 'Communities' });
    } else if (notif.related_entity_type === 'family' && notif.related_entity_id) {
      navigation.navigate('Main', { screen: 'Communities' });
    }
    // Delete the notification
    try {
      await api.post(`/notifications/${notif.id}/read`, {}, { headers });
      setNotifs(prev => prev.filter(n => n.id !== notif.id));
    } catch {}
  };

  const handleDeleteAll = () => {
    Alert.alert('Tout supprimer', 'Supprimer toutes les notifications ?', [
      { text: 'Annuler' },
      {
        text: 'Supprimer', style: 'destructive',
        onPress: async () => {
          try {
            await api.post('/notifications/mark-all-read', {}, { headers });
            setNotifs([]);
          } catch {}
        },
      },
    ]);
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
          <MaterialCommunityIcons name="arrow-left" size={22} color={C.textPrimary} />
        </TouchableOpacity>
        <Text style={styles.title}>Notifications</Text>
        {notifs.length > 0 && (
          <TouchableOpacity onPress={handleDeleteAll} style={styles.clearBtn}>
            <Text style={styles.clearText}>Tout supprimer</Text>
          </TouchableOpacity>
        )}
      </View>

      <FlatList
        data={notifs}
        keyExtractor={item => item.id.toString()}
        refreshing={loading}
        onRefresh={fetchNotifs}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 40 }}
        ListEmptyComponent={
          <View style={styles.empty}>
            <MaterialCommunityIcons name="bell-check-outline" size={48} color={C.borderLight} />
            <Text style={styles.emptyTitle}>Aucune notification</Text>
            <Text style={styles.emptySub}>Vous êtes à jour !</Text>
          </View>
        }
        renderItem={({ item }) => {
          const iconName = notifIcon(item.related_entity_type) as any;
          const color = notifColor(item.related_entity_type);
          return (
            <TouchableOpacity
              style={styles.card}
              onPress={() => handleRead(item)}
              activeOpacity={0.75}
            >
              <View style={[styles.iconWrap, { backgroundColor: color + '20' }]}>
                <MaterialCommunityIcons name={iconName} size={22} color={color} />
              </View>
              <View style={styles.cardContent}>
                <Text style={styles.message}>{item.message}</Text>
                {item.created_at && (
                  <Text style={styles.time}>{timeAgo(item.created_at)}</Text>
                )}
              </View>
              <MaterialCommunityIcons name="chevron-right" size={18} color={C.textTertiary} />
            </TouchableOpacity>
          );
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: C.background },
  header: {
    flexDirection: 'row', alignItems: 'center',
    paddingHorizontal: 16, paddingTop: 12, paddingBottom: 12,
    borderBottomWidth: 1, borderBottomColor: C.borderLight,
  },
  backBtn: {
    width: 36, height: 36, borderRadius: C.radiusFull,
    alignItems: 'center', justifyContent: 'center', marginRight: 12,
  },
  title: { fontSize: 20, fontWeight: '700', color: C.textPrimary, flex: 1, letterSpacing: -0.3 },
  clearBtn: { paddingHorizontal: 4 },
  clearText: { fontSize: 13, color: C.destructive, fontWeight: '600' },

  card: {
    flexDirection: 'row', alignItems: 'center',
    paddingHorizontal: 16, paddingVertical: 14,
    borderBottomWidth: 1, borderBottomColor: C.borderLight,
    backgroundColor: C.surface,
  },
  iconWrap: {
    width: 44, height: 44, borderRadius: C.radiusBase,
    alignItems: 'center', justifyContent: 'center', marginRight: 14, flexShrink: 0,
  },
  cardContent: { flex: 1, marginRight: 8 },
  message: { fontSize: 14, color: C.textPrimary, lineHeight: 20, fontWeight: '500' },
  time: { fontSize: 12, color: C.textTertiary, marginTop: 3 },

  empty: { alignItems: 'center', paddingTop: 80, gap: 12, paddingHorizontal: 40 },
  emptyTitle: { fontSize: 18, fontWeight: '700', color: C.textPrimary },
  emptySub: { fontSize: 14, color: C.textSecondary },
});
