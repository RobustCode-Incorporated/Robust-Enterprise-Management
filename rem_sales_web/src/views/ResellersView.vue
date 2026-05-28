<template>
  <div class="resellers-page">
    <div class="page-header">
      <h1>Gestion des Revendeurs</h1>
      <button @click="showForm = !showForm" class="btn-toggle">
        {{ showForm ? 'Fermer' : '+ Ajouter un revendeur' }}
      </button>
    </div>

    <!-- Écoute de l'événement 'created' pour rafraîchir -->
    <div v-if="showForm" class="form-section">
      <ResellerForm @created="handleCreated" />
    </div>

    <div class="table-container">
      <h3>Liste des partenaires</h3>
      <!-- ... ton tableau reste identique ... -->
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import axios from 'axios'
import ResellerForm from './ResellerForm.vue'

const showForm = ref(false)
const resellers = ref([])

const fetchResellers = async () => {
  const companyId = localStorage.getItem('companyId')
  try {
    const res = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/resellers`, {
      params: { company_id: companyId }
    })
    resellers.value = res.data
  } catch (err) {
    console.error('Erreur chargement revendeurs:', err)
  }
}

// Fonction wrapper pour fermer le formulaire après création
const handleCreated = () => {
  showForm.value = false
  fetchResellers()
}

onMounted(fetchResellers)
</script>