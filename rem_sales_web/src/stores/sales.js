import { defineStore } from 'pinia'
import axios from 'axios'

export const useSalesStore = defineStore('sales', {
  state: () => ({
    sales: [],
    loading: false,
    error: null
  }),

  actions: {
    async fetchSales() {
      this.loading = true
      this.error = null
      try {
        const token = localStorage.getItem('token')
        const companyId = localStorage.getItem('companyId')

        // Appel à ton API avec le token et le company_id requis
        const response = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/sales`, {
          params: { company_id: companyId },
          headers: { Authorization: `Bearer ${token}` }
        })

        // 🛡️ ADAPTATION ULTRA-SOUPLE DE LA RÉPONSE :
        // On vérifie toutes les structures possibles que ton backend peut renvoyer
        if (Array.isArray(response.data)) {
          this.sales = response.data
        } else if (response.data && Array.isArray(response.data.documents)) {
          this.sales = response.data.documents
        } else if (response.data && Array.isArray(response.data.sales)) {
          this.sales = response.data.sales
        } else {
          this.sales = []
        }

        console.log("Ventes chargées dans le store Pinia :", this.sales)
      } catch (err) {
        console.error("Erreur lors de la récupération des ventes dans le store :", err)
        this.error = err.message || "Impossible de charger les ventes."
      } finally {
        this.loading = false
      }
    }
  }
})