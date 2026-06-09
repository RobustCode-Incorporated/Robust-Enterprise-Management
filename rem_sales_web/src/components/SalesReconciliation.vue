<template>
  <div class="sales-module-container">
    
    <fieldset class="filter-zone no-print">
      <legend>Moteur de Recherche & Filtrage Avancé</legend>
      <div class="filter-grid">
        <div class="search-box">
          <label for="search-input">Rechercher une transaction</label>
          <input 
            id="search-input"
            v-model="searchQuery" 
            @input="triggerSearch"
            type="text" 
            placeholder="Ex: FACT-001234 ou Nom du client..." 
            class="input-field"
          />
        </div>

        <div class="filter-box">
          <label for="status-select">Filtrer par Statut</label>
          <select id="status-select" v-model="selectedStatus" @change="resetAndFetch" class="input-field select-field">
            <option value="">Tous les statuts</option>
            <option value="PAID">Payées (PAID)</option>
            <option value="DRAFT">Brouillons (DRAFT)</option>
            <option value="CANCELLED">Annulées (CANCELLED)</option>
          </select>
        </div>
      </div>
    </fieldset>

    <div class="results-meta no-print" v-if="metaData">
      <p><strong>{{ metaData.totalItems }}</strong> transactions correspondantes trouvées</p>
    </div>

    <div class="table-wrapper" :class="{ 'no-print': isModalOpen }">
      <div v-if="loading" class="state-feedback loading-state">
        🔄 Chargement et pagination des données en cours...
      </div>
      
      <div v-else-if="salesList.length === 0" class="state-feedback empty-state">
        ⚠️ Aucune vente ne correspond à vos critères de recherche.
      </div>

      <table v-else class="sales-table">
        <thead>
          <tr>
            <th>N° Facture</th>
            <th>Client</th>
            <th>Date d'émission</th>
            <th>Montant Total</th>
            <th>Statut</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="sale in salesList" :key="sale.id">
            <td class="font-mono font-bold">{{ sale.number }}</td>
            <td>{{ sale.client_name || 'Client Anonyme' }}</td>
            <td>{{ formatDate(sale.created_at) }}</td>
            <td class="text-right font-bold">{{ Number(sale.total_amount).toLocaleString() }} $</td>
            <td>
              <span :class="['badge', sale.status.toLowerCase()]">
                {{ sale.status }}
              </span>
            </td>
            <td>
              <button @click="openInvoice(sale)" class="action-btn btn-view" title="Voir la facture">👁️</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="pagination-bar no-print" v-if="metaData && metaData.totalPages > 1">
      <button @click="changePage(currentPage - 1)" :disabled="currentPage === 1" class="pag-btn">◀ Précédent</button>
      <span class="page-indicator">Page <strong>{{ currentPage }}</strong> sur <strong>{{ metaData.totalPages }}</strong></span>
      <button @click="changePage(currentPage + 1)" :disabled="currentPage === metaData.totalPages" class="pag-btn">Suivant ▶</button>
    </div>

    <div v-if="isModalOpen" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        
        <div class="modal-actions-bar no-print">
          <button @click="printInvoice" class="btn-action-print">🖨️ Imprimer / PDF</button>
          <a :href="whatsappLink" target="_blank" class="btn-action-whatsapp">💬 WhatsApp</a>
          <a :href="emailLink" class="btn-action-email">✉️ Email</a>
          <button @click="closeModal" class="btn-action-close">Fermer ✕</button>
        </div>

        <div class="invoice-paper">
          <div class="invoice-header">
            <div class="logo-container">
              <img :src="logoRobustCode" alt="Robust Code Inc. Logo" class="invoice-logo-img" />
              <p class="company-details">Solutions Technologiques Multi-tenant<br>Bruxelles, Belgique</p>
            </div>
            <div class="invoice-meta-block">
              <h2>FACTURE</h2>
              <p><strong>N° :</strong> {{ selectedInvoice.number }}</p>
              <p><strong>Date :</strong> {{ formatDate(selectedInvoice.created_at) }}</p>
              <p><strong>Statut :</strong> <span class="invoice-status-text">{{ selectedInvoice.status }}</span></p>
            </div>
          </div>

          <hr class="invoice-separator" />

          <div class="invoice-bill-to">
            <h3>Facturé à :</h3>
            <p class="client-name">{{ selectedInvoice.client_name || 'Client Anonyme' }}</p>
            <p class="client-details">Identifiant Client : {{ selectedInvoice.client_id || 'N/A' }}</p>
          </div>

          <table class="invoice-items-table">
            <thead>
              <tr>
                <th>Description</th>
                <th class="text-right">Total</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Prestation de services ou vente de marchandises rattachée au dossier {{ selectedInvoice.number }}</td>
                <td class="text-right font-bold">{{ Number(selectedInvoice.total_amount).toLocaleString() }} $</td>
              </tr>
            </tbody>
          </table>

          <div class="invoice-total-block">
            <div class="total-row">
              <span>Montant Net HT :</span>
              <span>{{ Number(selectedInvoice.total_amount).toLocaleString() }} $</span>
            </div>
            <div class="total-row">
              <span>TVA (0% / Régime Spécifique) :</span>
              <span>0 $</span>
            </div>
            <div class="total-row grand-total">
              <span>Total Net à Payer (USD) :</span>
              <span>{{ Number(selectedInvoice.total_amount).toLocaleString() }} $</span>
            </div>
          </div>

          <div class="invoice-footer">
            <p>Merci pour votre confiance !</p>
            <p class="footer-legal">Robust Code Inc. — Document généré électroniquement par le REM Core System v1.0.0</p>
          </div>
        </div>

      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'

// 💡 Importation officielle de ton logo via Vite
import logoRobustCode from '../assets/RobustCodelogowhite.png'

// États réactifs existants
const salesList = ref([])
const metaData = ref(null)
const currentPage = ref(1)
const searchQuery = ref('')
const selectedStatus = ref('')
const loading = ref(false)
let debounceTimeout = null

// États pour la gestion de la modale
const isModalOpen = ref(false)
const selectedInvoice = ref(null)

// Requête HTTP principale connectée à l'API paginée
const fetchPaginatingSales = async () => {
  loading.value = true
  try {
    const token = localStorage.getItem('token')
    const urlParams = new URLSearchParams(window.location.search)
    const companyId = urlParams.get('company_id') || localStorage.getItem('companyId') || '943e411e-9c4c-484f-9dde-9db708f5159a'

    const response = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/sales/documents`, {
      headers: { Authorization: `Bearer ${token}` },
      params: {
        page: currentPage.value,
        limit: 15,
        search: searchQuery.value,
        status: selectedStatus.value,
        company_id: companyId
      }
    })
    salesList.value = response.data.data
    metaData.value = response.data.meta
  } catch (error) {
    console.error("❌ [UX ERROR] Échec de la récupération des ventes paginées:", error)
  } finally {
    loading.value = false
  }
}

// Moteur de Debounce
const triggerSearch = () => {
  clearTimeout(debounceTimeout)
  debounceTimeout = setTimeout(() => {
    currentPage.value = 1
    fetchPaginatingSales()
  }, 350)
}

const resetAndFetch = () => {
  currentPage.value = 1
  fetchPaginatingSales()
}

const changePage = (newPage) => {
  if (newPage >= 1 && newPage <= metaData.value.totalPages) {
    currentPage.value = newPage
    fetchPaginatingSales()
  }
}

const formatDate = (dateString) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Logique de la modale
const openInvoice = (sale) => {
  selectedInvoice.value = sale
  isModalOpen.value = true
}

const closeModal = () => {
  isModalOpen.value = false
  selectedInvoice.value = null
}

const printInvoice = () => {
  window.print()
}

// Liens omnicanaux
const whatsappLink = computed(() => {
  if (!selectedInvoice.value) return '#'
  const text = encodeURIComponent(
    `Bonjour, voici votre facture ${selectedInvoice.value.number} d'un montant de ${Number(selectedInvoice.value.total_amount).toLocaleString()} $. Merci pour votre confiance !`
  )
  return `https://api.whatsapp.com/send?text=${text}`
})

const emailLink = computed(() => {
  if (!selectedInvoice.value) return '#'
  const subject = encodeURIComponent(`Facture Robust Code Inc. - N° ${selectedInvoice.value.number}`)
  const body = encodeURIComponent(
    `Bonjour,\n\nVeuillez trouver les informations de votre facture ${selectedInvoice.value.number}.\nMontant total : ${Number(selectedInvoice.value.total_amount).toLocaleString()} $\nStatut : ${selectedInvoice.value.status}\n\nCordialement,\nL'équipe de Robust Code Inc.`
  )
  return `mailto:?subject=${subject}&body=${body}`
})

onMounted(() => {
  fetchPaginatingSales()
})
</script>

<style scoped>
/* Styles structurels du Dashboard */
.sales-module-container { background: #fff; padding: 24px; border-radius: 8px; border: 1px solid #e2e8f0; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
.filter-zone { border: 1px solid #cbd5e1; border-radius: 6px; padding: 16px; margin-bottom: 20px; }
.filter-zone legend { font-size: 0.8rem; font-weight: bold; text-transform: uppercase; padding: 0 8px; }
.filter-grid { display: grid; grid-template-columns: 2fr 1fr; gap: 16px; }
.search-box, .filter-box { display: flex; flex-direction: column; gap: 6px; }
.search-box label, .filter-box label { font-size: 0.75rem; font-weight: 600; color: #475569; }
.input-field { padding: 10px 14px; border: 1px solid #cbd5e1; border-radius: 4px; font-size: 0.9rem; outline: none; }
.input-field:focus { border-color: #000; }
.select-field { cursor: pointer; }
.results-meta { font-size: 0.85rem; color: #64748b; margin-bottom: 12px; }
.table-wrapper { overflow-x: auto; min-height: 200px; }
.sales-table { width: 100%; border-collapse: collapse; text-align: left; font-size: 0.9rem; }
.sales-table th { background: #f8fafc; color: #475569; font-weight: 600; padding: 12px; border-bottom: 2px solid #e2e8f0; }
.sales-table td { padding: 12px; border-bottom: 1px solid #edf2f7; color: #1e293b; }
.font-mono { font-family: monospace; }
.font-bold { font-weight: bold; }
.text-right { text-align: right; }
.badge { padding: 4px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: bold; text-transform: uppercase; }
.badge.paid { background: #d1fae5; color: #065f46; }
.badge.draft { background: #fef3c7; color: #92400e; }
.badge.cancelled { background: #fee2e2; color: #991b1b; }
.action-btn { background: none; border: none; cursor: pointer; font-size: 1.1rem; padding: 4px; border-radius: 4px; }
.action-btn:hover { background: #f1f5f9; }
.state-feedback { text-align: center; padding: 40px; color: #64748b; }
.pagination-bar { display: flex; justify-content: center; align-items: center; gap: 16px; margin-top: 24px; padding-top: 16px; border-top: 1px solid #e2e8f0; }
.pag-btn { background: #000; color: #fff; border: none; padding: 8px 16px; border-radius: 4px; font-size: 0.8rem; font-weight: 600; cursor: pointer; }
.pag-btn:disabled { background: #cbd5e1; color: #94a3b8; cursor: not-allowed; }
.page-indicator { font-size: 0.85rem; color: #334155; }

/* Modale Overlay */
.modal-overlay { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(15, 23, 42, 0.6); backdrop-filter: blur(4px); display: flex; justify-content: center; align-items: center; z-index: 9999; }
.modal-content { background: #f8fafc; width: 90%; max-width: 800px; max-height: 90vh; border-radius: 12px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1); display: flex; flex-direction: column; overflow: hidden; }

/* Actions Bar */
.modal-actions-bar { background: #1e293b; padding: 12px 24px; display: flex; gap: 12px; align-items: center; }
.modal-actions-bar button, .modal-actions-bar a { padding: 8px 16px; border-radius: 6px; font-size: 0.85rem; font-weight: 600; text-decoration: none; cursor: pointer; border: none; }
.btn-action-print { background: #3b82f6; color: white; }
.btn-action-whatsapp { background: #22c55e; color: white; }
.btn-action-email { background: #64748b; color: white; }
.btn-action-close { background: #ef4444; color: white; margin-left: auto; }

/* Zone Papier Facture & Intégration du Logo */
.invoice-paper { background: #ffffff; padding: 40px; overflow-y: auto; flex: 1; color: #1e293b; font-family: 'Segoe UI', system-ui, sans-serif; }
.invoice-header { display: flex; justify-content: space-between; align-items: flex-start; }

.logo-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.invoice-logo-img {
  max-width: 180px;
  height: auto;
  object-fit: contain;
  filter: brightness(0) contrast(100%); 
}

.company-details { font-size: 0.85rem; color: #64748b; line-height: 1.4; margin: 0; }
.invoice-meta-block { text-align: right; }
.invoice-meta-block h2 { font-size: 1.6rem; font-weight: 700; color: #0f172a; margin: 0 0 8px 0; }
.invoice-meta-block p { margin: 4px 0; font-size: 0.9rem; color: #475569; }
.invoice-status-text { font-weight: bold; color: #22c55e; }
.invoice-separator { border: 0; border-top: 2px solid #f1f5f9; margin: 24px 0; }
.invoice-bill-to h3 { font-size: 0.85rem; text-transform: uppercase; color: #64748b; margin-bottom: 8px; letter-spacing: 0.5px; }
.client-name { font-size: 1.1rem; font-weight: 700; margin: 0 0 4px 0; color: #0f172a; }
.client-details { font-size: 0.85rem; color: #64748b; margin: 0; }
.invoice-items-table { width: 100%; border-collapse: collapse; margin-top: 32px; }
.invoice-items-table th { background: #f8fafc; padding: 10px 12px; font-size: 0.8rem; text-transform: uppercase; color: #64748b; border-bottom: 1px solid #cbd5e1; }
.invoice-items-table td { padding: 16px 12px; font-size: 0.95rem; border-bottom: 1px solid #f1f5f9; }
.invoice-total-block { width: 40%; margin-left: auto; margin-top: 24px; display: flex; flex-direction: column; gap: 8px; }
.total-row { display: flex; justify-content: space-between; font-size: 0.9rem; color: #475569; }
.grand-total { font-size: 1.1rem; font-weight: 800; color: #0f172a; border-top: 2px solid #0f172a; padding-top: 8px; margin-top: 4px; }
.invoice-footer { margin-top: 60px; text-align: center; color: #94a3b8; }
.invoice-footer p { margin: 4px 0; font-size: 0.9rem; }
.footer-legal { font-size: 0.75rem !important; margin-top: 12px !important; }

/* Impression CSS */
@media print {
  .no-print, .no-print * { display: none !important; }
  .modal-overlay { position: absolute !important; background: none !important; padding: 0 !important; margin: 0 !important; width: 100% !important; }
  .modal-content { box-shadow: none !important; width: 100% !important; max-width: 100% !important; background: transparent !important; }
  .invoice-paper { padding: 0 !important; margin: 0 !important; width: 100% !important; }
  .invoice-logo-img { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
}
</style>