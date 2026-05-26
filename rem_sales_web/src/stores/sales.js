import { defineStore } from 'pinia'
import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'https://api.robust-em.com/api/v1',
  timeout: 10000
})

export const useSalesStore = defineStore('sales', {
  state: () => ({
    documents: [],
    isLoading: false,
    error: null,
    currentCompanyId: 'robust-corp-africa-123'
  }),

  getters: {
    // 📈 Séparation des totaux par devise pour gérer l'économie multi-devise (RDC, Afrique de l'Ouest, etc.)
    totalsByCurrency: (state) => {
      const totals = {}
      state.documents.forEach(doc => {
        // Idéalement la devise est liée au document ou récupérée dans les métadonnées
        // Pour le MVP, on extrait ou on trie selon les données reçues
        const currency = doc.currency || 'XOF' 
        if (!totals[currency]) totals[currency] = 0
        if (doc.status === 'PAID') {
          totals[currency] += doc.totalAmount
        }
      })
      return totals
    },
    
    // Lister les documents en attente de traitement ou synchronisés en mode Draft
    pendingSyncCount: (state) => state.documents.filter(d => d.status === 'DRAFT').length
  },

  actions: {
    async fetchSalesDocuments() {
      this.isLoading = true
      this.error = null
      try {
        const response = await api.get(`/sales`, {
          params: { company_id: this.currentCompanyId }
        })
        this.documents = response.data
      } catch (err) {
        this.error = err.response?.data?.message || "Erreur lors de la récupération des ventes."
        console.error("⚡ [Sales Store Error]:", err)
      } finally {
        this.isLoading = false
      }
    }
  }
})