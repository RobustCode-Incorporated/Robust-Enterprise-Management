<template>
  <div class="portal-wrapper">
    <div class="action-card">
      <div class="icon-box">📍</div>
      <h3>Géolocalisation</h3>
      <p>Mettez à jour votre position actuelle pour valider votre dépôt.</p>
      
      <button @click="updateLocation" :disabled="loading" class="btn-geo">
        {{ loading ? 'Localisation...' : 'Actualiser ma position GPS' }}
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
    statusMessage.value = "Géolocalisation non supportée."
    statusType.value = 'error'
    return
  }

  loading.value = true
  navigator.geolocation.getCurrentPosition(
    async (position) => {
      try {
        const { latitude, longitude } = position.coords
        const resellerId = localStorage.getItem('resellerId')
        
        await axios.patch(`${import.meta.env.VITE_API_BASE_URL}/resellers/${resellerId}/location`, {
          latitude,
          longitude
        })
        
        statusMessage.value = "Position mise à jour avec succès !"
        statusType.value = 'success'
        if (navigator.vibrate) navigator.vibrate(200)
      } catch (err) {
        statusMessage.value = "Erreur serveur."
        statusType.value = 'error'
      } finally {
        loading.value = false
      }
    },
    () => {
      statusMessage.value = "Accès à la position refusé."
      statusType.value = 'error'
      loading.value = false
    }
  )
}
</script>

<style scoped>
.portal-wrapper { width: 100%; max-width: 450px; }
.action-card { background: #fff; padding: 30px; border-radius: 16px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); text-align: center; }
.icon-box { font-size: 3rem; margin-bottom: 10px; }
.btn-geo { background: #000; color: #fff; border: none; padding: 20px; border-radius: 12px; cursor: pointer; width: 100%; font-weight: bold; margin-top: 20px; transition: 0.2s; }
.btn-geo:disabled { background: #555; }
.status-msg { margin-top: 20px; padding: 12px; border-radius: 8px; font-size: 0.85rem; }
.success { background: #e8f5e9; color: #2e7d32; }
.error { background: #ffebee; color: #c62828; }
</style>