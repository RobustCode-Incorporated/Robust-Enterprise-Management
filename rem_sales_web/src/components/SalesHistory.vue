<template>
  <div class="history-module">
    <div class="header-section">
      <h2>Historique des Activités Commerciales</h2>
      <p class="subtitle">Consultez vos transactions personnelles au sein de l'établissement</p>
    </div>
    
    <fieldset class="filter-zone no-print">
      <legend>Moteur de recherche et filtres</legend>
      <div class="filter-grid">
        <div class="search-box">
          <label for="search-input">Rechercher une transaction</label>
          <input 
            id="search-input"
            v-model="searchQuery" 
            @input="triggerSearch"
            type="text" 
            placeholder="Par numéro de facture ou client." 
            class="input-field"
          />
        </div>

        <div class="filter-box">
          <label for="status-select">Filtrer par statut</label>
          <select id="status-select" v-model="selectedStatus" @change="resetAndFetch" class="input-field select-field">
            <option value="">Tous les statuts</option>
            <option value="PAID">Payées (PAID)</option>
            <option value="DRAFT">Brouillons (DRAFT)</option>
            <option value="CANCELLED">Annulées (CANCELLED)</option>
          </select>
        </div>
      </div>
    </fieldset>

    <div v-if="loading" class="state-feedback">
      <span class="spinner"></span> Chargement de l'historique des flux...
    </div>

    <div v-else-if="salesHistory.length === 0" class="state-feedback empty-state">
      Aucune transaction disponible ou trouvée.
    </div>

    <table v-else class="data-table" :class="{ 'no-print': isModalOpen }">
      <thead>
        <tr>
          <th>Numéro Facture</th>
          <th>Type</th>
          <th>Client / Fournisseur</th>
          <th>Date</th>
          <th>Montant</th>
          <th>Statut</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="doc in salesHistory" :key="doc.id">
          <td class="font-mono font-bold">{{ doc.number || 'N/A' }}</td>
          <td>
            <span :class="['type-badge', String(doc.type).toLowerCase()]">
              {{ String(doc.type).toUpperCase().includes('RESTOCK') ? 'RESTOCK' : 'VENTE' }}
            </span>
          </td>
          <td class="font-bold">
            {{ doc.client_name || doc.reseller_name || (String(doc.type).toUpperCase().includes('RESTOCK') ? 'Dépôt Principal' : 'Client de passage') }}
            <span v-if="doc.depot_name" class="depot-tag">({{ doc.depot_name }})</span>
          </td>
          <td>{{ formatDate(doc.created_at) }}</td>
          <td class="font-bold text-success">{{ Number(doc.total_amount || 0).toLocaleString() }} $</td>
          <td>
            <span :class="['badge', String(doc.status || '').toLowerCase()]">
              {{ doc.status || 'UNKNOWN' }}
            </span>
          </td>
          <td>
            <button @click="openInvoice(doc)" class="action-btn">Consulter</button>
          </td>
        </tr>
      </tbody>
    </table>

    <div v-if="isModalOpen" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <div class="modal-actions-bar no-print">
          <button @click="printInvoice" class="btn-action-print">Imprimer / PDF</button>
          <button @click="closeModal" class="btn-action-close">Fermer</button>
        </div>

        <div class="invoice-paper">
          <div class="invoice-header">
            <div>
              <h2>{{ String(selectedInvoice.type).toUpperCase().includes('RESTOCK') ? 'BON DE COMMANDE / RESTOCK' : 'REÇU DE VENTE' }}</h2>
              <p><strong>N° :</strong> {{ selectedInvoice.number }}</p>
              <p><strong>Date :</strong> {{ formatDate(selectedInvoice.created_at) }}</p>
            </div>
          </div>
          <hr class="invoice-separator" />
          <table class="invoice-items-table">
            <thead>
              <tr>
                <th>Description</th>
                <th class="text-right">Quantité</th>
                <th class="text-right">Prix Unitaire</th>
                <th class="text-right">Total</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="item in selectedInvoiceItems" :key="item.id">
                <td>{{ item.product_name || 'Article' }}</td>
                <td class="text-right">{{ item.quantity }}</td>
                <td class="text-right">{{ Number(item.unit_price || 0).toLocaleString() }} $</td>
                <td class="text-right font-bold">{{ Number(item.total_price || 0).toLocaleString() }} $</td>
              </tr>
              <tr v-if="itemsLoading">
                <td colspan="4" class="text-center text-muted">Récupération des lignes...</td>
              </tr>
            </tbody>
          </table>
          <div class="invoice-total-block">
            <div class="total-row grand-total">
              <span>Total Net (USD) :</span>
              <span>{{ Number(selectedInvoice.total_amount || 0).toLocaleString() }} $</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import axios from 'axios';

const salesHistory = ref([]);
const searchQuery = ref('');
const selectedStatus = ref('');
const loading = ref(false);
const itemsLoading = ref(false);
let debounceTimeout = null;

const isModalOpen = ref(false);
const selectedInvoice = ref(null);
const selectedInvoiceItems = ref([]);

const extractArray = (payload) => {
  if (!payload) return [];
  if (Array.isArray(payload)) return payload;
  if (payload.data && Array.isArray(payload.data)) return payload.data;
  if (payload.documents && Array.isArray(payload.documents)) return payload.documents;
  const alternativeArray = Object.values(payload).find(val => Array.isArray(val));
  return alternativeArray || [];
};

const fetchSales = async () => {
  loading.value = true;
  const companyId = localStorage.getItem('companyId');
  
  console.group("📜 [REM DIAGNOSTIC] Historique Commercial");

  try {
    const queryParams = {};
    if (companyId) queryParams.company_id = companyId;
    if (searchQuery.value) queryParams.search = searchQuery.value;
    if (selectedStatus.value) queryParams.status = selectedStatus.value;

    const res = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/sales/documents`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
      params: queryParams
    });
    
    // Le tri de sécurité s'effectue directement en amont par le contrôleur SQL backend.
    salesHistory.value = extractArray(res.data);
    console.log("Documents injectés directement (Sécurisés par l'API) :", salesHistory.value);

  } catch (err) {
    console.error("❌ Échec historique :", err);
  } finally {
    console.groupEnd();
    loading.value = false;
  }
};

const fetchInvoiceItems = async (documentId) => {
  itemsLoading.value = true;
  try {
    const res = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/sales/documents/${documentId}/items`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
    });
    selectedInvoiceItems.value = extractArray(res.data);
  } catch (err) {
    selectedInvoiceItems.value = [];
  } finally {
    itemsLoading.value = false;
  }
};

const triggerSearch = () => {
  clearTimeout(debounceTimeout);
  debounceTimeout = setTimeout(() => { fetchSales(); }, 350);
};

const resetAndFetch = () => { fetchSales(); };

const openInvoice = async (sale) => {
  selectedInvoice.value = sale;
  isModalOpen.value = true;
  await fetchInvoiceItems(sale.id);
};

const closeModal = () => {
  isModalOpen.value = false;
  selectedInvoice.value = null;
};

const printInvoice = () => { window.print(); };

const formatDate = (dateString) => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleDateString('fr-FR', {
    day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit'
  });
};

onMounted(fetchSales);
</script>

<style scoped>
.history-module { background: #fff; padding: 24px; border-radius: 8px; border: 1px solid #e2e8f0; }
.header-section { margin-bottom: 20px; }
.header-section h2 { font-size: 1.4rem; color: #111; font-weight: bold; margin: 0 0 4px 0; }
.subtitle { color: #64748b; font-size: 0.88rem; margin: 0; }
.filter-zone { border: 1px solid #cbd5e1; border-radius: 6px; padding: 18px; margin-bottom: 25px; background-color: #fafafa; }
.filter-grid { display: grid; grid-template-columns: 2fr 1fr; gap: 16px; }
.search-box, .filter-box { display: flex; flex-direction: column; gap: 6px; }
.input-field { padding: 10px 14px; border: 1px solid #cbd5e1; border-radius: 4px; font-size: 0.88rem; outline: none; }
.data-table { width: 100%; border-collapse: collapse; margin-top: 10px; }
.data-table th { background: #f8fafc; color: #475569; padding: 14px; border-bottom: 2px solid #e2e8f0; text-align: left; }
.data-table td { padding: 14px; border-bottom: 1px solid #f1f5f9; }
.font-bold { font-weight: bold; }
.text-success { color: #10b981; }
.type-badge { padding: 3px 8px; border-radius: 4px; font-size: 0.68rem; font-weight: 700; background: #e2e8f0; }
.badge { padding: 4px 8px; border-radius: 4px; font-size: 0.72rem; font-weight: bold; }
.action-btn { background: #000; color: #fff; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer; }
.modal-overlay { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0,0,0,0.4); display: flex; justify-content: center; align-items: center; z-index: 9999; }
.modal-content { background: #fff; width: 90%; max-width: 800px; max-height: 90vh; border-radius: 8px; overflow: hidden; display: flex; flex-direction: column; }
.modal-actions-bar { background: #000; padding: 12px 24px; display: flex; gap: 12px; }
.btn-action-print { background: #3b82f6; color: #fff; padding: 8px 16px; border-radius: 4px; border: none; cursor: pointer; }
.btn-action-close { background: #333; color: #fff; padding: 8px 16px; border-radius: 4px; border: none; cursor: pointer; margin-left: auto; }
.invoice-paper { padding: 40px; overflow-y: auto; flex: 1; }
.invoice-items-table { width: 100%; border-collapse: collapse; margin-top: 24px; }
.invoice-items-table th { background: #f8fafc; padding: 10px; border-bottom: 1px solid #e2e8f0; }
.invoice-items-table td { padding: 12px 10px; border-bottom: 1px solid #f1f5f9; }
.invoice-total-block { width: 45%; margin-left: auto; margin-top: 24px; }
.grand-total { font-size: 1.05rem; font-weight: 800; border-top: 2px solid #000; padding-top: 10px; display: flex; justify-content: space-between; }
.state-feedback { text-align: center; padding: 40px; color: #64748b; font-style: italic; }
.spinner { width: 16px; height: 16px; border: 2px solid #e2e8f0; border-top-color: #000; border-radius: 50%; animation: spin 0.8s linear infinite; display: inline-block; margin-right: 8px; vertical-align: middle; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>