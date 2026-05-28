<template>
  <div class="reseller-portal">
    <header class="portal-header">
      <h2>Mon Espace Revendeur</h2>
      <p>Gérez votre dépôt et validez votre position.</p>
    </header>

    <div class="action-card">
      <h3>Géolocalisation</h3>
      <p>Cliquez pour mettre à jour votre position actuelle sur la carte du réseau.</p>
      
      <button @click="updateLocation" :disabled="loading" class="btn-geo">
        {{ loading ? 'Localisation en cours...' : 'Mettre à jour ma position GPS' }}
      </button>

      <div v-if="statusMessage" :class="['status-msg', statusType]">
        {{ statusMessage }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import axios from 'axios'

const loading = ref(false)
const statusMessage = ref('')
const statusType = ref('')

const updateLocation = () => {
  if (!navigator.geolocation) {
    statusMessage.value = "La géolocalisation n'est pas supportée par votre navigateur."
    statusType.value = 'error'
    return
  }

  loading.value = true
  navigator.geolocation.getCurrentPosition(
    async (position) => {
      try {
        const { latitude, longitude } = position.coords
        const resellerId = localStorage.getItem('resellerId') // Assure-toi de stocker cet ID au login
        
        await axios.patch(`${import.meta.env.VITE_API_BASE_URL}/resellers/${resellerId}/location`, {
          latitude,
          longitude
        })
        
        statusMessage.value = "Position mise à jour avec succès !"
        statusType.value = 'success'
      } catch (err) {
        statusMessage.value = "Erreur lors de l'envoi au serveur."
        statusType.value = 'error'
      } finally {
        loading.value = false
      }
    },
    () => {
      statusMessage.value = "Impossible d'obtenir votre position."
      statusType.value = 'error'
      loading.value = false
    }
  )
}
</script>

<style scoped>
.reseller-portal { padding: 20px; font-family: 'ABeeZee', sans-serif; max-width: 500px; margin: 0 auto; }
.portal-header { margin-bottom: 30px; }
.action-card { background: #fff; padding: 25px; border-radius: 12px; border: 1px solid #eee; text-align: center; }
.btn-geo { background: #000; color: #fff; border: none; padding: 15px 25px; border-radius: 8px; cursor: pointer; width: 100%; font-weight: bold; }
.btn-geo:disabled { background: #555; }
.status-msg { margin-top: 15px; padding: 10px; border-radius: 6px; font-size: 0.9rem; }
.success { background: #e8f5e9; color: #2e7d32; }
.error { background: #ffebee; color: #c62828; }
</style>