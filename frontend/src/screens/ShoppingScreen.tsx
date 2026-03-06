import React, { useContext, useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  Modal, TextInput as RNTextInput, Alert, ActivityIndicator,
  KeyboardAvoidingView, Platform, Pressable, Keyboard,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { FAB } from 'react-native-paper';
import { useFocusEffect } from '@react-navigation/native';
import { api } from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { C } from '../theme/colors';

// ─── Types ───────────────────────────────────────────────────────────────────

type ShoppingList = {
  id: number;
  name: string;
  family_id: number;
  family_name: string;
  created_by: string;
  item_count: number;
  checked_count: number;
};

type ShoppingItem = {
  id: number;
  list_id: number;
  title: string;
  quantity?: string;
  is_checked: boolean;
  added_by?: string;
  checked_by?: string;
};

type Family = { id: number; name: string };

// ─── Quick-add templates ──────────────────────────────────────────────────────

const QUICK_ITEMS = [
  { icon: 'bread-slice-outline', label: 'Pain' },
  { icon: 'cow', label: 'Lait' },
  { icon: 'egg-outline', label: 'Œufs' },
  { icon: 'fruit-cherries', label: 'Fruits' },
  { icon: 'carrot', label: 'Légumes' },
  { icon: 'food-steak', label: 'Viande' },
  { icon: 'water-outline', label: 'Eau' },
  { icon: 'coffee-outline', label: 'Café' },
];

// ─── Screen ───────────────────────────────────────────────────────────────────

export default function ShoppingScreen() {
  const { token } = useContext(AuthContext);
  const headers = { Authorization: `Bearer ${token}` };

  const [lists, setLists] = useState<ShoppingList[]>([]);
  const [loading, setLoading] = useState(false);

  // Active list (open detail)
  const [activeList, setActiveList] = useState<ShoppingList | null>(null);
  const [items, setItems] = useState<ShoppingItem[]>([]);
  const [loadingItems, setLoadingItems] = useState(false);

  // Create list modal
  const [createListVisible, setCreateListVisible] = useState(false);
  const [newListName, setNewListName] = useState('');
  const [newListFamilyId, setNewListFamilyId] = useState<number | null>(null);
  const [families, setFamilies] = useState<Family[]>([]);
  const [creating, setCreating] = useState(false);

  // Add item
  const [addItemText, setAddItemText] = useState('');
  const [addItemQty, setAddItemQty] = useState('');
  const [addingItem, setAddingItem] = useState(false);

  // ── Fetch ──

  const fetchLists = async () => {
    setLoading(true);
    try {
      const res = await api.get('/shopping/my-lists', { headers });
      setLists(res.data);
    } catch {}
    setLoading(false);
  };

  const fetchFamilies = async () => {
    try {
      const res = await api.get('/events/my-families', { headers });
      setFamilies(res.data);
    } catch {}
  };

  const fetchItems = async (listId: number) => {
    setLoadingItems(true);
    try {
      const res = await api.get(`/shopping/lists/${listId}/items`, { headers });
      setItems(res.data);
    } catch {}
    setLoadingItems(false);
  };

  useFocusEffect(
    useCallback(() => {
      fetchLists();
    }, [token])
  );

  // ── Actions ──

  const openList = async (list: ShoppingList) => {
    setActiveList(list);
    setAddItemText('');
    setAddItemQty('');
    await fetchItems(list.id);
  };

  const handleCreateList = async () => {
    if (!newListName.trim() || !newListFamilyId) return;
    setCreating(true);
    try {
      await api.post('/shopping/lists', { name: newListName.trim(), family_id: newListFamilyId }, { headers });
      setCreateListVisible(false);
      setNewListName('');
      setNewListFamilyId(null);
      await fetchLists();
    } catch { Alert.alert('Erreur', 'Impossible de créer la liste'); }
    setCreating(false);
  };

  const handleDeleteList = (list: ShoppingList) => {
    Alert.alert('Supprimer la liste', `Supprimer "${list.name}" et tous ses articles ?`, [
      { text: 'Annuler' },
      {
        text: 'Supprimer', style: 'destructive',
        onPress: async () => {
          try {
            await api.delete(`/shopping/lists/${list.id}`, { headers });
            if (activeList?.id === list.id) setActiveList(null);
            await fetchLists();
          } catch { Alert.alert('Erreur', 'Impossible de supprimer'); }
        },
      },
    ]);
  };

  const handleAddItem = async () => {
    if (!addItemText.trim() || !activeList) return;
    setAddingItem(true);
    try {
      const res = await api.post(`/shopping/lists/${activeList.id}/items`, {
        title: addItemText.trim(),
        quantity: addItemQty.trim() || undefined,
      }, { headers });
      setItems(prev => [res.data, ...prev]);
      setAddItemText('');
      setAddItemQty('');
      // Update count in list
      setLists(prev => prev.map(l => l.id === activeList.id
        ? { ...l, item_count: l.item_count + 1 }
        : l
      ));
    } catch { Alert.alert('Erreur', "Impossible d'ajouter l'article"); }
    setAddingItem(false);
  };

  const handleToggleItem = async (item: ShoppingItem) => {
    // Optimistic update
    setItems(prev => prev.map(i => i.id === item.id ? { ...i, is_checked: !i.is_checked } : i));
    try {
      const res = await api.patch(`/shopping/items/${item.id}/toggle`, {}, { headers });
      setItems(prev => prev.map(i => i.id === item.id ? res.data : i));
      // Sync checked count
      setLists(prev => prev.map(l => {
        if (l.id === activeList?.id) {
          return { ...l, checked_count: res.data.is_checked ? l.checked_count + 1 : l.checked_count - 1 };
        }
        return l;
      }));
    } catch {
      // Revert
      setItems(prev => prev.map(i => i.id === item.id ? item : i));
    }
  };

  const handleDeleteItem = async (item: ShoppingItem) => {
    setItems(prev => prev.filter(i => i.id !== item.id));
    try {
      await api.delete(`/shopping/items/${item.id}`, { headers });
      setLists(prev => prev.map(l => l.id === activeList?.id
        ? { ...l, item_count: l.item_count - 1, checked_count: item.is_checked ? l.checked_count - 1 : l.checked_count }
        : l
      ));
    } catch { await fetchItems(activeList!.id); }
  };

  const handleClearChecked = async () => {
    if (!activeList) return;
    Alert.alert('Effacer cochés', 'Supprimer tous les articles cochés ?', [
      { text: 'Annuler' },
      {
        text: 'Effacer', style: 'destructive',
        onPress: async () => {
          try {
            await api.delete(`/shopping/lists/${activeList.id}/checked`, { headers });
            await fetchItems(activeList.id);
            await fetchLists();
          } catch {}
        },
      },
    ]);
  };

  // ── Render helpers ──

  const unchecked = items.filter(i => !i.is_checked);
  const checked = items.filter(i => i.is_checked);
  const progress = items.length > 0 ? checked.length / items.length : 0;

  // ─── List View ────────────────────────────────────────────────────────────

  if (activeList) {
    return (
      <SafeAreaView style={styles.safe}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => { setActiveList(null); fetchLists(); }} style={{ padding: 4 }}>
            <MaterialCommunityIcons name="arrow-left" size={24} color={C.textPrimary} />
          </TouchableOpacity>
          <View style={styles.headerCenter}>
            <Text style={styles.headerTitleDetail} numberOfLines={1}>{activeList.name}</Text>
            <Text style={styles.headerSub} numberOfLines={1}>{activeList.family_name}</Text>
          </View>
          {checked.length > 0 && (
            <TouchableOpacity onPress={handleClearChecked} style={styles.clearBtn} hitSlop={{ top: 8, bottom: 8, left: 4, right: 4 }}>
              <MaterialCommunityIcons name="broom" size={16} color={C.textSecondary} />
            </TouchableOpacity>
          )}
        </View>

        {/* Progress bar */}
        {items.length > 0 && (
          <View style={styles.progressWrap}>
            <View style={styles.progressBar}>
              <View style={[styles.progressFill, { width: `${progress * 100}%` as any }]} />
            </View>
            <Text style={styles.progressText}>{checked.length}/{items.length}</Text>
          </View>
        )}

        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={{ flex: 1 }}>
          <ScrollView
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ padding: 16, paddingBottom: 120 }}
            keyboardShouldPersistTaps="handled"
          >
            {loadingItems ? (
              <ActivityIndicator color={C.primary} style={{ marginTop: 32 }} />
            ) : (
              <>
                {/* Add item row */}
                <View style={styles.addItemRow}>
                  <RNTextInput
                    style={styles.addItemInput}
                    placeholder="Ajouter un article..."
                    placeholderTextColor={C.textPlaceholder}
                    value={addItemText}
                    onChangeText={setAddItemText}
                    returnKeyType="done"
                    onSubmitEditing={handleAddItem}
                  />
                  <RNTextInput
                    style={[styles.addItemInput, { width: 70, marginLeft: 8 }]}
                    placeholder="Qté"
                    placeholderTextColor={C.textPlaceholder}
                    value={addItemQty}
                    onChangeText={setAddItemQty}
                    returnKeyType="done"
                    onSubmitEditing={handleAddItem}
                  />
                  <TouchableOpacity
                    style={[styles.addItemBtn, !addItemText.trim() && { opacity: 0.4 }]}
                    onPress={handleAddItem}
                    disabled={!addItemText.trim() || addingItem}
                  >
                    <MaterialCommunityIcons name="plus" size={20} color="#fff" />
                  </TouchableOpacity>
                </View>

                {/* Quick add chips */}
                <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 20 }}>
                  {QUICK_ITEMS.map(q => (
                    <TouchableOpacity
                      key={q.label}
                      style={styles.quickChip}
                      onPress={() => setAddItemText(q.label)}
                    >
                      <MaterialCommunityIcons name={q.icon as any} size={14} color={C.primary} />
                      <Text style={styles.quickChipText}>{q.label}</Text>
                    </TouchableOpacity>
                  ))}
                </ScrollView>

                {items.length === 0 && (
                  <View style={styles.emptyState}>
                    <MaterialCommunityIcons name="cart-outline" size={48} color={C.borderLight} />
                    <Text style={styles.emptyText}>Liste vide — ajoutez des articles</Text>
                  </View>
                )}

                {/* Unchecked items */}
                {unchecked.map(item => (
                  <ItemRow key={item.id} item={item} onToggle={handleToggleItem} onDelete={handleDeleteItem} />
                ))}

                {/* Checked section */}
                {checked.length > 0 && (
                  <>
                    <Text style={styles.checkedLabel}>Cochés ({checked.length})</Text>
                    {checked.map(item => (
                      <ItemRow key={item.id} item={item} onToggle={handleToggleItem} onDelete={handleDeleteItem} />
                    ))}
                  </>
                )}
              </>
            )}
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    );
  }

  // ─── Lists Overview ───────────────────────────────────────────────────────

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.header}>
        <Text style={[styles.headerTitle, { flex: 1 }]}>Courses</Text>
      </View>

      {loading ? (
        <ActivityIndicator color={C.primary} style={{ marginTop: 48 }} />
      ) : lists.length === 0 ? (
        <View style={styles.emptyState}>
          <MaterialCommunityIcons name="cart-outline" size={60} color={C.borderLight} />
          <Text style={styles.emptyTitle}>Aucune liste de courses</Text>
          <Text style={styles.emptyText}>Créez une liste partagée avec votre famille</Text>
          <TouchableOpacity style={styles.emptyCreateBtn} onPress={() => { fetchFamilies(); setCreateListVisible(true); }}>
            <MaterialCommunityIcons name="plus" size={16} color={C.textOnPrimary} />
            <Text style={styles.emptyCreateText}>Créer une liste</Text>
          </TouchableOpacity>
        </View>
      ) : (
        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ padding: 16, paddingBottom: 100 }}>
          {lists.map(list => {
            const pct = list.item_count > 0 ? list.checked_count / list.item_count : 0;
            return (
              <TouchableOpacity
                key={list.id}
                style={styles.listCard}
                onPress={() => openList(list)}
                onLongPress={() => handleDeleteList(list)}
                activeOpacity={0.85}
              >
                <View style={styles.listCardLeft}>
                  <View style={styles.listIconWrap}>
                    <MaterialCommunityIcons name="cart-outline" size={22} color={C.primary} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.listCardName}>{list.name}</Text>
                    <View style={styles.listCardMeta}>
                      <View style={styles.familyTag}>
                        <MaterialCommunityIcons name="account-group-outline" size={11} color="#3b82f6" />
                        <Text style={styles.familyTagText}>{list.family_name}</Text>
                      </View>
                      <Text style={styles.listCardCount}>
                        {list.item_count === 0 ? 'Vide' : `${list.checked_count}/${list.item_count} articles`}
                      </Text>
                    </View>
                    {list.item_count > 0 && (
                      <View style={styles.miniProgress}>
                        <View style={[styles.miniProgressFill, { width: `${pct * 100}%` as any }]} />
                      </View>
                    )}
                  </View>
                </View>
                <MaterialCommunityIcons name="chevron-right" size={20} color={C.textTertiary} />
              </TouchableOpacity>
            );
          })}
        </ScrollView>
      )}

      <FAB
        icon="plus"
        style={styles.fab}
        color={C.textOnPrimary}
        onPress={() => { fetchFamilies(); setCreateListVisible(true); }}
      />

      {/* Create list modal */}
      <Modal visible={createListVisible} transparent animationType="fade" onRequestClose={() => setCreateListVisible(false)}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={styles.kavContainer}>
          <Pressable style={{ flex: 1 }} onPress={() => { Keyboard.dismiss(); setCreateListVisible(false); }} />
          <View style={styles.formBox}>
            <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              <Text style={styles.formTitle}>Nouvelle liste de courses</Text>
              <RNTextInput
                style={styles.textInput}
                placeholder="Nom de la liste"
                placeholderTextColor={C.textPlaceholder}
                value={newListName}
                onChangeText={setNewListName}
                autoFocus
              />
              {families.length > 0 && (
                <>
                  <Text style={styles.fieldLabel}>Famille *</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 16 }}>
                    {families.map(f => (
                      <TouchableOpacity
                        key={f.id}
                        style={[styles.chipBtn, newListFamilyId === f.id && styles.chipActive]}
                        onPress={() => setNewListFamilyId(f.id)}
                      >
                        <Text style={[styles.chipText, newListFamilyId === f.id && styles.chipTextActive]}>{f.name}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                </>
              )}
              <TouchableOpacity
                style={[styles.primaryBtn, (!newListName.trim() || !newListFamilyId || creating) && styles.btnDisabled]}
                onPress={handleCreateList}
                disabled={!newListName.trim() || !newListFamilyId || creating}
              >
                <Text style={styles.primaryBtnText}>{creating ? 'Création...' : 'Créer la liste'}</Text>
              </TouchableOpacity>
              <TouchableOpacity style={{ alignItems: 'center', marginTop: 10 }} onPress={() => setCreateListVisible(false)}>
                <Text style={{ color: C.textSecondary, fontSize: 14 }}>Annuler</Text>
              </TouchableOpacity>
            </ScrollView>
          </View>
          <View style={{ flex: 0.3 }} />
        </KeyboardAvoidingView>
      </Modal>
    </SafeAreaView>
  );
}

// ─── ItemRow ──────────────────────────────────────────────────────────────────

function ItemRow({
  item, onToggle, onDelete,
}: {
  item: ShoppingItem;
  onToggle: (item: ShoppingItem) => void;
  onDelete: (item: ShoppingItem) => void;
}) {
  return (
    <View style={[itemStyles.row, item.is_checked && itemStyles.rowChecked]}>
      <TouchableOpacity onPress={() => onToggle(item)} style={itemStyles.checkBtn} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
        <MaterialCommunityIcons
          name={item.is_checked ? 'checkbox-marked-circle' : 'checkbox-blank-circle-outline'}
          size={22}
          color={item.is_checked ? '#22c55e' : C.textTertiary}
        />
      </TouchableOpacity>
      <View style={{ flex: 1, marginLeft: 12 }}>
        <Text style={[itemStyles.title, item.is_checked && itemStyles.titleDone]}>{item.title}</Text>
        {item.quantity ? <Text style={itemStyles.qty}>{item.quantity}</Text> : null}
      </View>
      <TouchableOpacity onPress={() => onDelete(item)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
        <MaterialCommunityIcons name="close" size={18} color={C.textTertiary} />
      </TouchableOpacity>
    </View>
  );
}

const itemStyles = StyleSheet.create({
  row: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: C.surface, borderRadius: C.radiusBase,
    padding: 12, marginBottom: 8, ...C.shadowSm,
  },
  rowChecked: { backgroundColor: C.surfaceAlt },
  checkBtn: { padding: 2 },
  title: { fontSize: 15, color: C.textPrimary, fontWeight: '500' },
  titleDone: { textDecorationLine: 'line-through', color: C.textTertiary },
  qty: { fontSize: 12, color: C.textTertiary, marginTop: 2 },
});

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: C.background },
  header: {
    flexDirection: 'row', alignItems: 'center',
    paddingHorizontal: 20, paddingTop: 16, paddingBottom: 12,
  },
  headerTitle: { fontSize: 24, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.3 },
  headerCenter: { flex: 1, marginLeft: 12, marginRight: 8 },
  headerTitleDetail: { fontSize: 18, fontWeight: '700', color: C.textPrimary, letterSpacing: -0.2 },
  headerSub: { fontSize: 13, color: C.textTertiary, marginTop: 2 },
  clearBtn: {
    alignItems: 'center', justifyContent: 'center',
    width: 34, height: 34,
    borderWidth: 1, borderColor: C.borderLight, borderRadius: C.radiusFull,
  },

  progressWrap: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 12, gap: 10 },
  progressBar: { flex: 1, height: 5, backgroundColor: C.borderLight, borderRadius: 3, overflow: 'hidden' },
  progressFill: { height: '100%', backgroundColor: '#22c55e', borderRadius: 3 },
  progressText: { fontSize: 12, color: C.textTertiary, fontWeight: '600', minWidth: 32, textAlign: 'right' },

  listCard: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: C.surface, borderRadius: C.radiusLg,
    padding: 16, marginBottom: 12, ...C.shadowSm,
  },
  listCardLeft: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 14 },
  listIconWrap: {
    width: 44, height: 44, borderRadius: C.radiusBase,
    backgroundColor: C.primaryLight, alignItems: 'center', justifyContent: 'center',
  },
  listCardName: { fontSize: 16, fontWeight: '700', color: C.textPrimary, marginBottom: 4 },
  listCardMeta: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6 },
  listCardCount: { fontSize: 12, color: C.textTertiary },
  familyTag: {
    flexDirection: 'row', alignItems: 'center', gap: 3,
    backgroundColor: '#eff6ff', borderRadius: C.radiusFull,
    paddingHorizontal: 6, paddingVertical: 2,
  },
  familyTagText: { fontSize: 11, color: '#3b82f6', fontWeight: '500' },
  miniProgress: { height: 4, backgroundColor: C.borderLight, borderRadius: 2, overflow: 'hidden', width: '80%' },
  miniProgressFill: { height: '100%', backgroundColor: '#22c55e', borderRadius: 2 },

  addItemRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 12, gap: 0 },
  addItemInput: {
    flex: 1, borderWidth: 1, borderColor: C.border, borderRadius: C.radiusBase,
    paddingHorizontal: 14, paddingVertical: 10,
    fontSize: 15, color: C.textPrimary, backgroundColor: C.surface,
  },
  addItemBtn: {
    backgroundColor: C.primary, borderRadius: C.radiusBase,
    padding: 11, marginLeft: 8, alignItems: 'center', justifyContent: 'center',
  },
  quickChip: {
    flexDirection: 'row', alignItems: 'center', gap: 5,
    paddingHorizontal: 12, paddingVertical: 6,
    borderRadius: C.radiusFull, borderWidth: 1, borderColor: C.borderLight,
    backgroundColor: C.surfaceAlt, marginRight: 8,
  },
  quickChipText: { fontSize: 12, color: C.textSecondary, fontWeight: '500' },

  checkedLabel: { fontSize: 13, fontWeight: '700', color: C.textTertiary, marginTop: 8, marginBottom: 8 },

  emptyState: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60, gap: 12 },
  emptyTitle: { fontSize: 18, fontWeight: '700', color: C.textPrimary },
  emptyText: { fontSize: 14, color: C.textTertiary, textAlign: 'center', paddingHorizontal: 40 },
  emptyCreateBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    backgroundColor: C.primary, borderRadius: C.radiusFull,
    paddingHorizontal: 20, paddingVertical: 10, marginTop: 8,
  },
  emptyCreateText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 14 },

  fab: { position: 'absolute', right: 20, bottom: 28, backgroundColor: C.primary },

  kavContainer: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)' },
  formBox: {
    backgroundColor: C.surface, marginHorizontal: 16,
    borderRadius: C.radiusXl, padding: 20, maxHeight: '70%',
  },
  formTitle: { fontSize: 17, fontWeight: '700', color: C.textPrimary, marginBottom: 16 },
  textInput: {
    borderWidth: 1, borderColor: C.border, borderRadius: C.radiusBase,
    paddingHorizontal: 14, paddingVertical: 11,
    fontSize: 15, color: C.textPrimary, backgroundColor: C.surfaceAlt, marginBottom: 12,
  },
  fieldLabel: { fontSize: 13, fontWeight: '600', color: C.textSecondary, marginBottom: 8 },
  chipBtn: {
    paddingHorizontal: 14, paddingVertical: 8,
    borderRadius: C.radiusFull, borderWidth: 1, borderColor: C.border, marginRight: 8,
  },
  chipActive: { backgroundColor: C.primary, borderColor: C.primary },
  chipText: { fontSize: 13, color: C.textSecondary, fontWeight: '500' },
  chipTextActive: { color: C.textOnPrimary },
  primaryBtn: {
    backgroundColor: C.primary, borderRadius: C.radiusBase,
    paddingVertical: 13, alignItems: 'center', marginTop: 4,
  },
  btnDisabled: { opacity: 0.5 },
  primaryBtnText: { color: C.textOnPrimary, fontWeight: '700', fontSize: 15 },
});
