import { defineStore } from 'pinia'
import axios from 'axios'

/**
 * CATALOG STORE
 * Gestion de l'inventaire et du catalogue produits.
 */
export const useCatalogStore = defineStore('catalog', {
  state: () => ({
    products: [],
    loading: false,
    error: null
  }),

  getters: {
    /**
     * Filtre les produits en rupture de stock.
     */
    outOfStockProducts: (state) => {
      if (!Array.isArray(state.products)) return []
      
      return state.products.filter(p => {
        // On vérifie les deux syntaxes possibles (DB snake_case vs JS camelCase)
        const quantity = parseFloat(p.stock_quantity || p.stockQuantity || 0)
        return quantity <= 0
      })
    }
  },

  actions: {
    /**
     * Récupération du catalogue produits par entreprise.
     */
    async fetchProducts() {
      this.loading = true
      this.error = null
      
      try {
        const baseUrl = import.meta.env.VITE_API_BASE_URL
        const companyId = localStorage.getItem('companyId')
        const token = localStorage.getItem('token')

        if (!companyId || !token) {
          throw new Error("Authentification invalide.")
        }

        const response = await axios.get(`${baseUrl}/products`, {
          params: { company_id: companyId },
          headers: { Authorization: `Bearer ${token}` }
        })

        this.products = Array.isArray(response.data) ? response.data : []

      } catch (err) {
        console.error('Catalog Store Error:', err)
        this.error = err.response?.data?.message || "Impossible de charger le catalogue."
        this.products = []
      } finally {
        this.loading = false
      }
    },

    /**
     * Enregistrement d'un nouvel article.
     * @param {Object} productData - { name, purchasePrice, sellingPrice, stockQuantity, minStockAlert, currency }
     */
    async saveProduct(productData) {
      this.loading = true
      this.error = null
      
      try {
        const baseUrl = import.meta.env.VITE_API_BASE_URL
        const companyId = localStorage.getItem('companyId')
        const token = localStorage.getItem('token')

        // On envoie toutes les données du formulaire + l'ID de l'entreprise
        await axios.post(`${baseUrl}/products`, 
          { 
            ...productData, 
            company_id: companyId 
          },
          { 
            headers: { Authorization: `Bearer ${token}` } 
          }
        )
        
        // Rafraîchissement automatique du catalogue après succès
        await this.fetchProducts() 
        return true

      } catch (err) {
        console.error('Save Product Error:', err)
        // Récupération de l'erreur spécifique envoyée par le serveur
        this.error = err.response?.data?.error || "Erreur lors de la sauvegarde du produit."
        return false
      } finally {
        this.loading = false
      }
    }
  }
})