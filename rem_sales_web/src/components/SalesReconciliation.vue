<template>
  <div class="reconciliation-container">
    <header class="module-header">
      <h2>Historique des Ventes & Réconciliation</h2>
      <p>Consultez les factures générées et le statut des encaissements de l'entreprise.</p>
    </header>

    <div v-if="salesStore.error" class="error-state">
      ⚠️ {{ salesStore.error }}
    </div>

    <div v-else-if="salesStore.loading" class="loading-state">
      Chargement des transactions en cours...
    </div>

    <div v-else-if="!salesStore.sales || salesStore.sales.length === 0" class="empty-state">
      Aucune vente enregistrée pour le moment.
    </div>

    <div v-else class="table-responsive">
      <table class="sales-table">
        <thead>
          <tr>
            <th>Numéro</th>
            <th>Type</th>
            <th>Montant Total</th>
            <th>Statut</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="sale in salesStore.sales" :key="sale.id">
            <td class="font-mono font-bold">{{ sale.number || 'N/A' }}</td>
            <td>
              <span :class="['badge', typeBadgeClass(sale.type)]">
                {{ sale.type === 'QUOTE' ? 'Devis' : 'Facture' }}
              </span>
            </td>
            <td class="font-bold">
              {{ formatCurrency(sale.total_amount ?? sale.totalAmount) }}
            </td>
            <td>
              <span :class="['badge', statusBadgeClass(sale.status)]">
                {{ formatStatus(sale.status) }}
              </span>
            </td>
            <td class="color-muted">
              {{ formatDate(sale.created_at ?? sale.createdAt) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useSalesStore } from '../stores/sales'

const salesStore = useSalesStore()

onMounted(() => {
  // Déclenche l'action nettoyée du store
  salesStore.fetchSales()
})

// Fonction de formatage monétaire
const formatCurrency = (value) => {
  if (value === undefined || value === null) return '0,00'
  return Number(value).toLocaleString(undefined, { 
    minimumFractionDigits: 2, 
    maximumFractionDigits: 2 
  })
}

// Fonction de formatage de date
const formatDate = (dateString) => {
  if (!dateString) return 'N/A'
  try {
    const date = new Date(dateString)
    if (isNaN(date.getTime())) return dateString
    return date.toLocaleDateString(undefined, {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  } catch (e) {
    return 'N/A'
  }
}

const formatStatus = (status) => {
  const mapping = {
    'DRAFT': 'Brouillon',
    'SENT': 'Envoyé',
    'PAID': 'Payé',
    'CANCELLED': 'Annulé'
  }
  return mapping[status] || status || 'Inconnu'
}

const typeBadgeClass = (type) => {
  return type === 'QUOTE' ? 'badge-quote' : 'badge-invoice'
}

const statusBadgeClass = (status) => {
  const classes = {
    'DRAFT': 'badge-draft',
    'SENT': 'badge-sent',
    'PAID': 'badge-paid',
    'CANCELLED': 'badge-cancelled'
  }
  return classes[status] || 'badge-default'
}
</script>

<style scoped>
.reconciliation-container {
  background: #fff;
  padding: 30px;
  border-radius: 12px;
  border: 1px solid #eee;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.02);
}

.module-header { margin-bottom: 25px; }
.module-header h2 { margin: 0; font-size: 1.5rem; font-weight: 700; }
.module-header p { color: #666; font-size: 0.9rem; margin-top: 5px; }

.table-responsive { width: 100%; overflow-x: auto; }
.sales-table { width: 100%; border-collapse: collapse; text-align: left; font-size: 0.95rem; }
.sales-table th { padding: 12px 15px; border-bottom: 2px solid #eee; color: #444; font-weight: 600; }
.sales-table td { padding: 12px 15px; border-bottom: 1px solid #eee; vertical-align: middle; }

.font-mono { font-family: monospace; font-size: 0.9rem; }
.font-bold { font-weight: 600; }
.color-muted { color: #777; font-size: 0.85rem; }

.badge {
  display: inline-block;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 0.8rem;
  font-weight: 600;
  text-transform: uppercase;
}
.badge-quote { background: #e3f2fd; color: #0d47a1; }
.badge-invoice { background: #f3e5f5; color: #4a148c; }
.badge-draft { background: #f5f5f5; color: #616161; }
.badge-sent { background: #fff3e0; color: #e65100; }
.badge-paid { background: #e8f5e9; color: #1b5e20; }
.badge-cancelled { background: #ffebee; color: #b71c1c; }
.badge-default { background: #eee; color: #333; }

.loading-state, .empty-state {
  text-align: center;
  padding: 40px;
  color: #666;
  font-style: italic;
}

.error-state {
  text-align: center;
  padding: 20px;
  background: #ffebee;
  color: #c62828;
  border-radius: 6px;
  margin-bottom: 20px;
  font-weight: bold;
}
</style>