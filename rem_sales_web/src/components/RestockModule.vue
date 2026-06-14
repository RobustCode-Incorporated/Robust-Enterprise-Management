<template>
  <div class="restock-module">
    <div class="header">
      <h2>Mon Inventaire & Commandes</h2>
      <button @click="showOrderForm = !showOrderForm" class="btn-primary">
        {{ showOrderForm ? 'Fermer le catalogue' : '+ Commander au dépôt' }}
      </button>
    </div>

    <CreateRestockForm v-if="showOrderForm" @submitted="onOrderSubmitted" />

    <div v-else>
      <h3>Mes demandes de réapprovisionnement</h3>
      
      <div v-if="loading" class="state-feedback">
        <span class="spinner"></span> Analyse de vos demandes d'approvisionnement...
      </div>
      
      <div v-else-if="restockHistory.length === 0" class="state-feedback">
        Aucune demande de réapprovisionnement enregistrée.
      </div>

      <table v-else class="data-table">
        <thead>
          <tr>
            <th>Numéro</th>
            <th>Date</th>
            <th>Statut</th>
            <th>Montant Total</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="doc in restockHistory" :key="doc.id">
            <td class="font-bold">{{ doc.number || 'N/A' }}</td>
            <td>{{ formatDate(doc.created_at) }}</td>
            <td>
              <span :class="['badge', String(doc.status || '').toLowerCase()]">{{ doc.status || 'UNKNOWN' }}</span>
            </td>
            <td class="font-bold">{{ Number(doc.total_amount || 0).toLocaleString() }} $</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import axios from 'axios';
import CreateRestockForm from './CreateRestockForm.vue';

const showOrderForm = ref(false);
const restockHistory = ref([]);
const loading = ref(false);

const extractArray = (payload) => {
  if (!payload) return [];
  if (Array.isArray(payload)) return payload;
  if (payload.data && Array.isArray(payload.data)) return payload.data;
  if (payload.documents && Array.isArray(payload.documents)) return payload.documents;
  const alternativeArray = Object.values(payload).find(val => Array.isArray(val));
  return alternativeArray || [];
};

const fetchRestockHistory = async () => {
  loading.value = true;
  const companyId = localStorage.getItem('companyId');
  
  console.group("📦 [REM DIAGNOSTIC] Module Réapprovisionnement (Restock)");

  try {
    const queryParams = {};
    if (companyId) queryParams.company_id = companyId;

    const res = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/sales/documents`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
      params: queryParams
    });
    
    const allDocs = extractArray(res.data);
    console.log("Documents sécurisés reçus du backend pour Restock :", allDocs);

    // On garde uniquement le filtre par type (car la route générique renvoie ventes + restocks)
    restockHistory.value = allDocs.filter(doc => {
      const typeStr = String(doc.type || '').toUpperCase();
      return typeStr.includes('RESTOCK') || typeStr.includes('APPRO');
    });
    
    console.log("Résultat final injecté dans le tableau de restock :", restockHistory.value);

  } catch (err) {
    console.error("❌ Erreur de chargement de l'historique restock :", err);
  } finally {
    console.groupEnd();
    loading.value = false;
  }
};

const formatDate = (dateString) => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleDateString('fr-FR');
};

const onOrderSubmitted = () => {
  showOrderForm.value = false;
  fetchRestockHistory();
};

onMounted(fetchRestockHistory);
</script>

<style scoped>
.restock-module { background: #fff; padding: 24px; border-radius: 8px; border: 1px solid #e2e8f0; }
.header { display: flex; justify-content: space-between; margin-bottom: 20px; }
.btn-primary { background: #000; color: #fff; border: none; padding: 10px 20px; border-radius: 6px; cursor: pointer; font-weight: bold; }
.data-table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; }
.data-table th, .data-table td { padding: 15px; text-align: left; border-bottom: 1px solid #eee; }
.font-bold { font-weight: bold; }
.badge { padding: 5px 10px; border-radius: 12px; font-size: 0.8rem; font-weight: bold; text-transform: uppercase; }
.badge.paid, .badge.completed { background: #d1fae5; color: #065f46; }
.badge.draft { background: #fef3c7; color: #92400e; }
.badge.cancelled { background: #fee2e2; color: #991b1b; }
.state-feedback { text-align: center; padding: 40px; color: #64748b; font-style: italic; }
.spinner { width: 16px; height: 16px; border: 2px solid #e2e8f0; border-top-color: #000; border-radius: 50%; animation: spin 0.8s linear infinite; display: inline-block; margin-right: 8px; vertical-align: middle; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>