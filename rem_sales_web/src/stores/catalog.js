import { defineStore } from 'pinia'
import axios from 'axios'

// Configuration de l'instance Axios avec gestion des timeouts (crucial pour le réseau instable)
const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'https://api.robust-em.com/api/v1',
  timeout: 10000 // 10 secondes max pour s'adapter aux réalités des connexions locales
})

export const useCatalogStore = defineStore('catalog', {
  state: () => ({
    products: [],
    isLoading: false,
    error: null,
    currentCompanyId: 'robust-corp-africa-123' // Multi-tenant ID hérité de la config globale
  }),

  getters: {
    outOfStockProducts: (state) => state.products.filter(p => p.stockQuantity <= 0),
    lowStockProducts: (state) => state.products.filter(p => p.stockQuantity > 0 && p.stockQuantity <= (p.minStockAlert || 5)),
    totalStockValue: (state) => state.products.reduce((total, p) => total + (p.sellingPrice * p.stockQuantity), 0)
  },

  actions: {
    // 🔄 Charger le catalogue depuis le serveur
    async fetchProducts() {
      this.isLoading = true
      this.error = null
      try {
        const response = await api.get(`/products`, {
          params: { company_id: this.currentCompanyId }
        })
        this.products = response.data
      } catch (err) {
        this.error = err.response?.data?.message || "Erreur réseau lors du chargement du catalogue."
        console.error("⚡ [Catalog Store Error]:", err)
      } finally {
        this.isLoading = false
      }
    },

    // ➕ Ajouter ou mettre à jour un produit (Pousse les modifs au serveur)
    async saveProduct(productData) {
      this.isLoading = true
      try {
        if (productData.serverId) {
          // Mode Édition
          const response = await api.put(`/products/${productData.serverId}`, productData)
          const index = this.products.findIndex(p => p.serverId === productData.serverId)
          if (index !== -1) this.products[index] = response.data
        } else {
          // Mode Création
          const response = await api.post(`/products`, {
            ...productData,
            companyId: this.currentCompanyId
          })
          this.products.push(response.data)
        }
        return true
      } catch (err) {
        this.error = err.response?.data?.message || "Impossible d'enregistrer le produit."
        return false
      } finally {
        this.isLoading = false
      }
    }
  }
})