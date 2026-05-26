<script setup>
import { onMounted, ref } from 'vue'
import { useSalesStore } from '../stores/sales'

const salesStore = useSalesStore()
const selectedCurrencyFilter = ref('ALL')

onMounted(() => {
  salesStore.fetchSalesDocuments()
})

// Formater les dates proprement sans alourdir l'application
const formatDate = (dateString) => {
  if (!dateString) return ''
  const date = new Date(dateString)
  return date.toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}
</script>

<template>
  <div class="reconciliation-container">
    <div class="header-actions">
      <h2>📊 Suivi & Réconciliation des Ventes</h2>
      <button @click="salesStore.fetchSalesDocuments" class="btn-refresh">
        🔄 Actualiser les flux
      </button>
    </div>

    <!-- 💰 CARTES KPI MULTI-DEVISES -->
    <div class="kpi-grid" v-if="!salesStore.isLoading">
      <div v-for="(amount, currency) in salesStore.totalsByCurrency" :key="currency" class="kpi-card">
        <span class="kpi-label">CA Encaissé ({{ currency }})</span>
        <span class="kpi-value text-green">{{ amount.toLocaleString() }} {{ currency }}</span>
      </div>
      <div class="kpi-card warning" v-if="salesStore.pendingSyncCount > 0">
        <span class="kpi-label">Factures en attente synchro</span>
        <span class="kpi-value text-orange">{{ salesStore.pendingSyncCount }} DRAFT</span>
      </div>
    </div>

    <!-- 📝 TABLEAU DE VÉRIFICATION DES FACTURES MOBILE -->
    <div class="table-wrapper">
      <table class="sales-table">
        <thead>
          <tr>
            <th>Date / Heure</th>
            <th>N° Facture (Généré Mobile)</th>
            <th>Type</th>
            <th>Montant Total</th>
            <th>Statut Système</th>
          </tr>
        </thead>
        <tbody>
          <!-- State: Chargement -->
          <tr v-if="salesStore.isLoading">
            <td colspan="5" class="text-center padding-30">
              Chargement et calcul des flux financiers de la caisse...
            </td>
          </tr>

          <!-- State: Erreur -->
          <tr v-else-if="salesStore.error">
            <td colspan="5" class="text-center text-red padding-30">
              ⚠️ {{ salesStore.error }}
            </td>
          </tr>

          <!-- State: Aucune donnée -->
          <tr v-else-if="salesStore.documents.length === 0">
            <td colspan="5" class="text-center padding-30 temporaire">
              Aucune vente n'a encore été synchronisée par les terminaux mobiles pour le moment.
            </td>
          </tr>

          <!-- State: Liste des transactions -->
          <tr v-else v-for="doc in salesStore.documents" :key="doc.id" :class="{ 'row-draft': doc.status === 'DRAFT' }">
            <td>{{ formatDate(doc.createdAt) }}</td>
            <td class="font-mono">{{ doc.number }}</td>
            <td><span class="badge-type">{{ doc.type }}</span></td>
            <td class="font-bold">{{ doc.totalAmount.toLocaleString() }} {{ doc.currency || 'XOF' }}</td>
            <td>
              <span :class="['status-pill', doc.status.toLowerCase()]">
                {{ doc.status === 'PAID' ? 'Encaissé' : 'Brouillon / En attente' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.reconciliation-container {
  background: white;
  padding: 24px;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}
.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
.btn-refresh {
  background: #4c51bf;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
}
.btn-refresh:hover { background: #434190; }

/* Grid KPI */
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}
.kpi-card {
  background: #f7fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 16px;
  display: flex;
  flex-direction: column;
}
.kpi-card.warning { border-left: 4px solid #dd6b20; }
.kpi-label { font-size: 0.8rem; color: #718096; text-transform: uppercase; font-weight: bold; }
.kpi-value { font-size: 1.5rem; font-weight: 800; margin-top: 4px; }

/* Tableau */
.table-wrapper { overflow-x: auto; }
.sales-table {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
  font-size: 0.9rem;
}
.sales-table th {
  background: #edf2f7;
  color: #4a5568;
  padding: 12px;
  font-weight: 700;
}
.sales-table td {
  padding: 12px;
  border-bottom: 1px solid #e2e8f0;
}
.row-draft { background-color: #fffaf0; }
.font-mono { font-family: monospace; font-weight: bold; color: #2d3748; }
.font-bold { font-weight: 700; }
.text-center { text-align: center; }
.padding-30 { padding: 30px; }
.text-green { color: #38a169; }
.text-orange { color: #dd6b20; }
.text-red { color: #e53e3e; }
.temporaire { color: #a0aec0; font-style: italic; }

/* Badges */
.badge-type {
  background: #e2e8f0;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: bold;
}
.status-pill {
  padding: 4px 8px;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: bold;
}
.status-pill.paid { background: #c6f6d5; color: #22543d; }
.status-pill.draft { background: #feebc8; color: #744210; }
</style>