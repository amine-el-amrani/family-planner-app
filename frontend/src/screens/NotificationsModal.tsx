import React, { useContext, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Modal,
  ActivityIndicator,
} from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { C } from '../theme/colors';

interface Notification {
  id: number;
  message: string;
  read: boolean;
  created_by: string | null;
}

interface Props {
  visible: boolean;
  onClose: () => void;
  onRead: () => void; // called after marking read to refresh badge
}

export default function NotificationsModal({ visible, onClose, onRead }: Props) {
  const { token } = useContext(AuthContext);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(false);

  const headers = { Authorization: `Bearer ${token}` };

  useEffect(() => {
    if (visible) fetchNotifications();
  }, [visible]);

  const fetchNotifications = async () => {
    setLoading(true);
    try {
      const res = await api.get('/notifications/', { headers });
      setNotifications(res.data);
    } catch {}
    setLoading(false);
  };

  const handleMarkRead = async (id: number) => {
    try {
      await api.post(`/notifications/${id}/read`, {}, { headers });
      setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n));
      onRead();
    } catch {}
  };

  const handleMarkAllRead = async () => {
    try {
      await api.post('/notifications/mark-all-read', {}, { headers });
      setNotifications(prev => prev.map(n => ({ ...n, read: true })));
      onRead();
    } catch {}
  };

  const unreadCount = notifications.filter(n => !n.read).length;

  const renderItem = ({ item }: { item: Notification }) => (
    <TouchableOpacity
      style={[styles.notifRow, !item.read && styles.notifUnread]}
      onPress={() => !item.read && handleMarkRead(item.id)}
      activeOpacity={0.75}
    >
      <View style={[styles.notifDot, item.read && styles.notifDotRead]} />
      <View style={styles.notifContent}>
        <Text style={[styles.notifMessage, item.read && styles.notifMessageRead]}>
          {item.message}
        </Text>
        {item.created_by && (
          <Text style={styles.notifBy}>De {item.created_by}</Text>
        )}
      </View>
      {!item.read && (
        <MaterialCommunityIcons name="check" size={16} color={C.primary} />
      )}
    </TouchableOpacity>
  );

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <TouchableOpacity style={styles.backdrop} activeOpacity={1} onPress={onClose} />
      <View style={styles.sheet}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Notifications</Text>
          <View style={styles.headerRight}>
            {unreadCount > 0 && (
              <TouchableOpacity style={styles.markAllBtn} onPress={handleMarkAllRead}>
                <Text style={styles.markAllText}>Tout marquer lu</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
              <MaterialCommunityIcons name="close" size={22} color={C.textSecondary} />
            </TouchableOpacity>
          </View>
        </View>

        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator color={C.primary} />
          </View>
        ) : notifications.length === 0 ? (
          <View style={styles.center}>
            <MaterialCommunityIcons name="bell-off-outline" size={48} color={C.textTertiary} />
            <Text style={styles.emptyText}>Aucune notification</Text>
          </View>
        ) : (
          <FlatList
            data={notifications}
            keyExtractor={item => String(item.id)}
            renderItem={renderItem}
            contentContainerStyle={{ paddingBottom: 24 }}
            showsVerticalScrollIndicator={false}
          />
        )}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.35)',
  },
  sheet: {
    backgroundColor: C.surface,
    borderTopLeftRadius: C.radius2xl,
    borderTopRightRadius: C.radius2xl,
    maxHeight: '75%',
    paddingHorizontal: 20,
    paddingTop: 20,
    ...C.shadowMd,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  title: {
    fontSize: 18,
    fontWeight: '700',
    color: C.textPrimary,
  },
  headerRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  markAllBtn: {
    backgroundColor: C.primaryLight,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: C.radiusBase,
  },
  markAllText: {
    fontSize: 12,
    fontWeight: '600',
    color: C.primary,
  },
  closeBtn: { padding: 4 },
  center: { alignItems: 'center', justifyContent: 'center', paddingVertical: 48, gap: 12 },
  emptyText: { fontSize: 15, color: C.textTertiary, marginTop: 8 },
  notifRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: C.borderLight,
    gap: 12,
  },
  notifUnread: { backgroundColor: C.primaryLight, marginHorizontal: -20, paddingHorizontal: 20 },
  notifDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: C.primary,
    flexShrink: 0,
  },
  notifDotRead: { backgroundColor: C.textTertiary },
  notifContent: { flex: 1 },
  notifMessage: {
    fontSize: 14,
    fontWeight: '600',
    color: C.textPrimary,
    lineHeight: 20,
  },
  notifMessageRead: { fontWeight: '400', color: C.textSecondary },
  notifBy: { fontSize: 11, color: C.textTertiary, marginTop: 2 },
});
