import React, { useEffect, useState, useContext } from 'react';
import { View, FlatList, StyleSheet, Text, TouchableOpacity } from 'react-native';
import { Snackbar } from 'react-native-paper';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { C } from '../theme/colors';

type ReceivedInv = { id: number; family_name: string; invited_by: string };
type SentInv = { id: number; email: string; family_name: string; status: string };

const STATUS_LABEL: Record<string, { label: string; color: string }> = {
  PENDING:  { label: 'En attente', color: C.textTertiary },
  ACCEPTED: { label: 'Acceptée',   color: '#22c55e' },
  REJECTED: { label: 'Refusée',    color: C.destructive },
};

export default function InvitationsScreen() {
  const [tab, setTab] = useState<'received' | 'sent'>('received');
  const [received, setReceived] = useState<ReceivedInv[]>([]);
  const [sent, setSent] = useState<SentInv[]>([]);
  const [loading, setLoading] = useState(false);
  const [snackbar, setSnackbar] = useState({ visible: false, message: '' });
  const { token } = useContext(AuthContext);
  const headers = { Authorization: `Bearer ${token}` };

  useEffect(() => { fetchAll(); }, []);

  const fetchAll = async () => {
    setLoading(true);
    try {
      const [recRes, sentRes] = await Promise.all([
        api.get('/families/my-invitations', { headers }),
        api.get('/families/my-sent-invitations', { headers }),
      ]);
      setReceived(recRes.data);
      setSent(sentRes.data);
    } catch {
      setSnackbar({ visible: true, message: 'Erreur lors du chargement' });
    }
    setLoading(false);
  };

  const handleAccept = async (id: number) => {
    try {
      await api.post(`/families/invitations/${id}/accept`, {}, { headers });
      fetchAll();
      setSnackbar({ visible: true, message: 'Invitation acceptée !' });
    } catch {
      setSnackbar({ visible: true, message: 'Erreur' });
    }
  };

  const handleReject = async (id: number) => {
    try {
      await api.post(`/families/invitations/${id}/reject`, {}, { headers });
      fetchAll();
      setSnackbar({ visible: true, message: 'Invitation rejetée' });
    } catch {
      setSnackbar({ visible: true, message: 'Erreur' });
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Invitations</Text>
          {received.length > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{received.length}</Text>
            </View>
          )}
        </View>

        {/* Tabs */}
        <View style={styles.tabRow}>
          <TouchableOpacity
            style={[styles.tabBtn, tab === 'received' && styles.tabActive]}
            onPress={() => setTab('received')}
          >
            <Text style={[styles.tabText, tab === 'received' && styles.tabTextActive]}>
              Reçues {received.length > 0 ? `(${received.length})` : ''}
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.tabBtn, tab === 'sent' && styles.tabActive]}
            onPress={() => setTab('sent')}
          >
            <Text style={[styles.tabText, tab === 'sent' && styles.tabTextActive]}>
              Envoyées {sent.length > 0 ? `(${sent.length})` : ''}
            </Text>
          </TouchableOpacity>
        </View>

        {/* Received */}
        {tab === 'received' && (
          <FlatList
            data={received}
            keyExtractor={item => item.id.toString()}
            refreshing={loading}
            onRefresh={fetchAll}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ paddingBottom: 32 }}
            renderItem={({ item }) => (
              <View style={styles.card}>
                <View style={styles.cardIcon}>
                  <MaterialCommunityIcons name="account-group" size={24} color={C.primary} />
                </View>
                <View style={styles.cardContent}>
                  <Text style={styles.cardTitle}>{item.family_name}</Text>
                  <Text style={styles.cardSub}>Invité par {item.invited_by}</Text>
                  <View style={styles.cardActions}>
                    <TouchableOpacity
                      style={styles.acceptBtn}
                      onPress={() => handleAccept(item.id)}
                      activeOpacity={0.8}
                    >
                      <MaterialCommunityIcons name="check" size={15} color={C.textOnPrimary} />
                      <Text style={styles.acceptBtnText}>Accepter</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.rejectBtn}
                      onPress={() => handleReject(item.id)}
                      activeOpacity={0.8}
                    >
                      <Text style={styles.rejectBtnText}>Rejeter</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            )}
            ListEmptyComponent={
              <View style={styles.empty}>
                <View style={styles.emptyIcon}>
                  <MaterialCommunityIcons name="email-check-outline" size={40} color={C.primary} />
                </View>
                <Text style={styles.emptyTitle}>Aucune invitation reçue</Text>
                <Text style={styles.emptySub}>Vous n'avez aucune invitation en attente.</Text>
              </View>
            }
          />
        )}

        {/* Sent */}
        {tab === 'sent' && (
          <FlatList
            data={sent}
            keyExtractor={item => item.id.toString()}
            refreshing={loading}
            onRefresh={fetchAll}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ paddingBottom: 32 }}
            renderItem={({ item }) => {
              const statusInfo = STATUS_LABEL[item.status] || { label: item.status, color: C.textTertiary };
              return (
                <View style={styles.card}>
                  <View style={[styles.cardIcon, { backgroundColor: '#f0f9ff' }]}>
                    <MaterialCommunityIcons name="email-send-outline" size={22} color="#3b82f6" />
                  </View>
                  <View style={styles.cardContent}>
                    <Text style={styles.cardTitle}>{item.family_name}</Text>
                    <Text style={styles.cardSub}>{item.email}</Text>
                    <View style={[styles.statusChip, { backgroundColor: statusInfo.color + '18' }]}>
                      <Text style={[styles.statusChipText, { color: statusInfo.color }]}>
                        {statusInfo.label}
                      </Text>
                    </View>
                  </View>
                </View>
              );
            }}
            ListEmptyComponent={
              <View style={styles.empty}>
                <View style={styles.emptyIcon}>
                  <MaterialCommunityIcons name="email-send-outline" size={40} color={C.primary} />
                </View>
                <Text style={styles.emptyTitle}>Aucune invitation envoyée</Text>
                <Text style={styles.emptySub}>Vous n'avez encore invité personne.</Text>
              </View>
            }
          />
        )}
      </View>

      <Snackbar
        visible={snackbar.visible}
        onDismiss={() => setSnackbar({ visible: false, message: '' })}
        duration={2000}
        style={{ backgroundColor: C.textPrimary }}
      >
        {snackbar.message}
      </Snackbar>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: C.background },
  container: { flex: 1, backgroundColor: C.background },
  header: {
    flexDirection: 'row', alignItems: 'center',
    paddingHorizontal: 20, paddingTop: 16, paddingBottom: 12,
  },
  title: { fontSize: 24, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.3, flex: 1 },
  badge: {
    backgroundColor: C.primary, borderRadius: C.radiusFull,
    paddingHorizontal: 8, paddingVertical: 2, overflow: 'hidden',
  },
  badgeText: { fontSize: 13, fontWeight: '600', color: C.textOnPrimary },

  tabRow: {
    flexDirection: 'row', marginHorizontal: 16, marginBottom: 16,
    borderRadius: C.radiusBase, borderWidth: 1, borderColor: C.borderLight,
    overflow: 'hidden', backgroundColor: C.surface,
  },
  tabBtn: { flex: 1, paddingVertical: 10, alignItems: 'center' },
  tabActive: { backgroundColor: C.primary },
  tabText: { fontSize: 14, fontWeight: '600', color: C.textSecondary },
  tabTextActive: { color: C.textOnPrimary },

  card: {
    flexDirection: 'row', backgroundColor: C.surface,
    marginHorizontal: 16, marginBottom: 12,
    borderRadius: C.radiusLg, borderWidth: 1, borderColor: C.borderLight,
    padding: 16, ...C.shadowSm,
  },
  cardIcon: {
    width: 48, height: 48, borderRadius: C.radiusBase,
    backgroundColor: C.primaryLight,
    alignItems: 'center', justifyContent: 'center',
    marginRight: 14, flexShrink: 0,
  },
  cardContent: { flex: 1 },
  cardTitle: { fontSize: 16, fontWeight: '700', color: C.textPrimary, marginBottom: 3 },
  cardSub: { fontSize: 13, color: C.textSecondary, marginBottom: 12 },
  cardActions: { flexDirection: 'row', gap: 10 },
  acceptBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 5,
    backgroundColor: C.primary, borderRadius: C.radiusBase,
    paddingVertical: 8, paddingHorizontal: 14,
  },
  acceptBtnText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 13 },
  rejectBtn: {
    borderRadius: C.radiusBase, paddingVertical: 8, paddingHorizontal: 14,
    borderWidth: 1, borderColor: C.border,
  },
  rejectBtnText: { color: C.textSecondary, fontWeight: '500', fontSize: 13 },
  statusChip: {
    alignSelf: 'flex-start', borderRadius: C.radiusFull,
    paddingHorizontal: 10, paddingVertical: 4,
  },
  statusChipText: { fontSize: 12, fontWeight: '700' },

  empty: { alignItems: 'center', paddingTop: 60, paddingHorizontal: 40 },
  emptyIcon: {
    width: 80, height: 80, borderRadius: C.radius2xl,
    backgroundColor: C.primaryLight,
    alignItems: 'center', justifyContent: 'center', marginBottom: 20,
  },
  emptyTitle: { fontSize: 18, fontWeight: '700', color: C.textPrimary, marginBottom: 8 },
  emptySub: { fontSize: 14, color: C.textSecondary, textAlign: 'center', lineHeight: 20 },
});
