<template>
  <div class="dashboard-stats-container">
    <div class="header-section">
      <h2>Vue d'ensemble</h2>
      <p class="subtitle">Vos indicateurs de performance en temps réel</p>
    </div>

    <div v-if="isLoading && productsStock.length === 0" class="loader">
      <span class="spinner"></span> Synchronisation de vos données...
    </div>

    <div v-else>
      <div class="stats-grid">
        <div class="stat-card black-card">
          <div class="card-icon stock-icon">📦</div>
          <div class="card-content">
            <h3>Articles en Stock</h3>
            <div class="metric">{{ totalStock }} <span class="unit">unités</span></div>
            <p class="trend">Disponibles immédiatement</p>
          </div>
        </div>

        <div class="stat-card black-card">
          <div class="card-icon revenue-icon">💰</div>
          <div class="card-content">
            <h3>Mes Ventes (Caisse)</h3>
            <div class="metric">{{ totalRevenue.toLocaleString() }} <span class="unit">$</span></div>
            <p class="trend">Ventes directes clients</p>
          </div>
        </div>
      </div>

      <div class="inventory-section">
        <div class="section-title-zone">
          <h3>Répartition et Stock Optimal par Marchandise</h3>
          <p class="section-subtitle">Chaque produit dispose de son indicateur de complétion visuel basé sur son seuil optimal</p>
        </div>

        <div v-if="productsStock.length === 0" class="empty-stock">
          <p>Aucun produit en stock actuellement. Effectuez une demande de réapprovisionnement.</p>
        </div>

        <div v-else class="inventory-grid">
          <div v-for="item in productsStock" :key="item.id" class="inventory-card">
            <div class="donut-wrapper">
              <div class="mini-donut" :style="getDonutStyle(item)">
                <div class="donut-center">
                  <span class="donut-qty">{{ item.quantity }}</span>
                </div>
              </div>
            </div>
            <div class="inventory-details">
              <h4>{{ item.products?.name || item.product_name || 'Produit inconnu' }}</h4>
              <span :class="['stock-badge', getStockStatusClass(item.stock_status)]">
                {{ getStockStatusText(item.stock_status, item.optimal_threshold) }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import axios from 'axios';

const totalStock = ref(0);
const totalRevenue = ref(0);
const productsStock = ref([]);
const isLoading = ref(true);
let refreshInterval = null;

const extractArray = (payload) => {
  if (!payload) return [];
  if (Array.isArray(payload)) return payload;
  if (payload.data && Array.isArray(payload.data)) return payload.data;
  if (payload.documents && Array.isArray(payload.documents)) return payload.documents;
  if (payload.results && Array.isArray(payload.results)) return payload.results;
  const alternativeArray = Object.values(payload).find(val => Array.isArray(val));
  return alternativeArray || [];
};

const getCurrentUserId = () => {
  const token = localStorage.getItem('token');
  if (!token) return null;
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const payload = JSON.parse(window.atob(base64));
    return payload.id || payload.userId || payload.user_id || payload.staffId || payload.staff_id || payload.sub;
  } catch (e) {
    return null;
  }
};

const fetchDashboardData = async (silent = false) => {
  if (!silent) isLoading.value = true;
  
  const token = localStorage.getItem('token');
  const companyId = localStorage.getItem('companyId');
  const currentUserId = getCurrentUserId();
  const headers = { Authorization: `Bearer ${token}` };

  console.group("📊 [REM DIAGNOSTIC] Analyse des flux Dashboard");
  console.log("Configuration Contextuelle - Company ID:", companyId, "| User ID:", currentUserId);

  try {
    // 1. Récupération des Stocks (Déjà sécurisé par /me/stock)
    const stockRes = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/resellers/me/stock`, { headers });
    const stockArray = extractArray(stockRes.data);
    productsStock.value = stockArray;
    totalStock.value = stockArray.reduce((acc, item) => acc + Number(item.quantity || 0), 0);

    // 2. Récupération des documents sécurisés par le backend
    const queryParams = {};
    if (companyId) queryParams.company_id = companyId;

    const docsRes = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/sales/documents`, { 
      params: queryParams, 
      headers 
    });
    
    const myDocuments = extractArray(docsRes.data);
    console.log(`Nombre de documents sécurisés reçus du backend : ${myDocuments.length}`);

    // Calcul direct du Chiffre d'Affaires sans re-filtrage d'identifiant
    totalRevenue.value = myDocuments
      .filter(doc => {
        const type = String(doc.type || '').toUpperCase();
        const status = String(doc.status || '').toUpperCase();
        
        const matchesType = type.includes('SALE') || type.includes('VENTE') || type.includes('FACTURE') || (!type.includes('RESTOCK') && type !== '');
        const matchesStatus = status.includes('PAID') || status.includes('PAY') || status.includes('COMPLETED') || status.includes('VALID');
        
        return matchesType && matchesStatus;
      })
      .reduce((acc, doc) => {
        const amount = doc.total_amount ?? doc.totalAmount ?? doc.amount ?? 0;
        return acc + Number(amount);
      }, 0);

    console.log("Calcul final de la carte Ventes Caisse :", totalRevenue.value);

  } catch (err) {
    console.error("❌ Erreur critique lors de la récupération des indicateurs :", err);
  } finally {
    console.groupEnd();
    isLoading.value = false;
  }
};

const getDonutStyle = (item) => {
  const percentage = item.percentage || 0;
  const deg = (percentage / 100) * 360;
  let color = '#10b981';
  if (item.stock_status === 'CRITICAL') color = '#ef4444';
  else if (item.stock_status === 'WARNING') color = '#f59e0b';
  return { background: `conic-gradient(${color} ${deg}deg, #222 ${deg}deg)` };
};

const getStockStatusText = (status, optimalThreshold) => {
  if (status === 'CRITICAL') return 'Stock critique';
  if (status === 'WARNING') return 'Stock moyen';
  return `Optimal (≥ ${optimalThreshold || 0})`;
};

const getStockStatusClass = (status) => {
  if (status === 'CRITICAL') return 'status-danger';
  if (status === 'WARNING') return 'status-warning';
  return 'status-success';
};

onMounted(() => {
  fetchDashboardData();
  refreshInterval = setInterval(() => fetchDashboardData(true), 30000);
  window.addEventListener('sales-updated', () => fetchDashboardData(true));
});

onUnmounted(() => {
  clearInterval(refreshInterval);
  window.removeEventListener('sales-updated', fetchDashboardData);
});
</script>

<style scoped>
.dashboard-stats-container { max-width: 1200px; margin: 0 auto; }
.header-section { margin-bottom: 30px; }
.header-section h2 { font-size: 1.8rem; color: #111; margin-bottom: 5px; font-weight: bold; }
.subtitle { color: #666; font-size: 0.95rem; }
.stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 25px; margin-bottom: 45px; }
.black-card { background: #111; color: #fff; border-radius: 12px; padding: 25px; display: flex; align-items: flex-start; gap: 20px; border: 1px solid #222; }
.card-icon { font-size: 2.2rem; background: #1c1c1c; width: 55px; height: 55px; display: flex; align-items: center; justify-content: center; border-radius: 10px; }
.card-content h3 { font-size: 0.85rem; color: #888; margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 1px; }
.metric { font-size: 2rem; font-weight: bold; margin: 0 0 4px 0; }
.unit { font-size: 0.9rem; color: #666; }
.trend { font-size: 0.8rem; color: #10b981; margin: 0; }
.inventory-section { background: #fff; border: 1px solid #eee; border-radius: 14px; padding: 30px; }
.section-title-zone { margin-bottom: 25px; }
.section-title-zone h3 { font-size: 1.2rem; color: #111; margin: 0; }
.section-subtitle { color: #777; font-size: 0.85rem; }
.inventory-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 20px; }
.inventory-card { background: #fafafa; border: 1px solid #f0f0f0; border-radius: 10px; padding: 20px; display: flex; align-items: center; gap: 20px; }
.mini-donut { width: 55px; height: 55px; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.donut-center { width: 41px; height: 41px; background: #fafafa; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.donut-qty { font-size: 0.95rem; font-weight: bold; }
.inventory-details h4 { font-size: 0.95rem; color: #111; margin: 0 0 6px 0; }
.stock-badge { font-size: 0.72rem; padding: 4px 8px; border-radius: 20px; font-weight: bold; text-transform: uppercase; }
.status-success { background: #e6f4ea; color: #137333; }
.status-warning { background: #fef7e0; color: #b06000; }
.status-danger { background: #fce8e6; color: #c5221f; }
.empty-stock { padding: 20px; text-align: center; color: #777; border: 1px dashed #ddd; border-radius: 8px; }
.loader { display: flex; align-items: center; gap: 15px; padding: 40px 0; }
.spinner { width: 22px; height: 22px; border: 3px solid #eee; border-top-color: #111; border-radius: 50%; animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>