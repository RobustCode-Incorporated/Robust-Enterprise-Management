<template>
  <div class="map-module-container">
    <div class="map-header">
      <h3>🛰️ Suivi Géographique Avancé (Resellers)</h3>
      <div class="map-actions">
        <div class="view-toggle">
          <button 
            @click="switchViewMode('standard')" 
            :class="['toggle-btn', { active: viewMode === 'standard' }]"
          >
            📍 Standard & Clusters
          </button>
          <button 
            @click="switchViewMode('heatmap')" 
            :class="['toggle-btn', { active: viewMode === 'heatmap' }]"
          >
            🔥 Carte de chaleur
          </button>
        </div>
        <button @click="fetchResellers" class="refresh-btn" :disabled="loading">
          {{ loading ? 'Mise à jour...' : '🔄 Actualiser' }}
        </button>
      </div>
    </div>

    <!-- Barre de recherche -->
    <div class="search-box-container">
      <input 
        v-model="searchQuery" 
        @keydown.enter="onSearchEnter"
        type="text" 
        placeholder="🔍 Rechercher par Nom, Email, Dépôt ou Téléphone... (Appuyez sur Entrée)" 
        class="search-input"
      />
      
      <ul v-if="searchResults.length > 0 && searchQuery" class="search-results-dropdown">
        <li 
          v-for="reseller in searchResults" 
          :key="reseller.id" 
          @click="focusOnReseller(reseller)"
          class="result-item"
        >
          <div class="result-main">
            <span>👤 {{ reseller.name }}</span> 
            <span class="deposit-tag">📦 {{ reseller.deposit_name || 'Sans dépôt' }}</span>
          </div>
          <div class="result-sub">
            📧 {{ reseller.email }} | 📞 {{ reseller.phone || 'Pas de numéro' }}
          </div>
        </li>
      </ul>
    </div>

    <!-- Conteneur de la carte -->
    <div id="live-resellers-map" class="resellers-map"></div>
  </div>
</template>

<script setup>
import { onMounted, onBeforeUnmount, ref, computed } from 'vue';
import axios from 'axios';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

const loading = ref(false);
const searchQuery = ref('');
const resellersList = ref([]);
const viewMode = ref('standard');
const markerMap = new Map();

let map = null;
let markerClusterGroup = null;
let heatmapLayer = null;
let pollInterval = null;

const defaultIcon = L.icon({
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34]
});

// Chargement synchrone des plugins d'affichage
const loadLeafletPlugins = () => {
  return new Promise((resolve) => {
    if (window.L && window.L.markerClusterGroup && window.L.heatLayer) {
      resolve();
      return;
    }

    const clusterCss = document.createElement('link');
    clusterCss.rel = 'stylesheet';
    clusterCss.href = 'https://cdnjs.cloudflare.com/ajax/libs/leaflet.markercluster/1.5.3/MarkerCluster.css';
    document.head.appendChild(clusterCss);

    const clusterDefaultCss = document.createElement('link');
    clusterDefaultCss.rel = 'stylesheet';
    clusterDefaultCss.href = 'https://cdnjs.cloudflare.com/ajax/libs/leaflet.markercluster/1.5.3/MarkerCluster.Default.css';
    document.head.appendChild(clusterDefaultCss);

    const clusterJs = document.createElement('script');
    clusterJs.src = 'https://cdnjs.cloudflare.com/ajax/libs/leaflet.markercluster/1.5.3/leaflet.markercluster.js';
    clusterJs.onload = () => {
      const heatmapJs = document.createElement('script');
      heatmapJs.src = 'https://cdnjs.cloudflare.com/ajax/libs/leaflet.heat/0.2.0/leaflet-heat.js';
      heatmapJs.onload = resolve;
      document.head.appendChild(heatmapJs);
    };
    document.head.appendChild(clusterJs);
  });
};

const searchResults = computed(() => {
  if (!searchQuery.value) return [];
  const query = searchQuery.value.toLowerCase();
  return resellersList.value.filter(r => 
    r.name.toLowerCase().includes(query) ||
    r.email.toLowerCase().includes(query) ||
    (r.phone && r.phone.toLowerCase().includes(query)) ||
    (r.deposit_name && r.deposit_name.toLowerCase().includes(query))
  );
});

// L'initialisation de la carte attend d'avoir chargé les dépendances
const initMap = () => {
  console.log("[UX LOG] Initialisation de la carte Leaflet Pro avec ses extensions.");
  map = L.map('live-resellers-map').setView([50.8503, 4.3517], 11);

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap contributors'
  }).addTo(map);

  // Initialisation sécurisée du groupe
  markerClusterGroup = L.markerClusterGroup({
    spiderfyOnMaxZoom: true,
    showCoverageOnHover: false,
    zoomToBoundsOnClick: true
  });
  
  map.addLayer(markerClusterGroup);
};

const fetchResellers = async () => {
  loading.value = true;
  try {
    const companyId = localStorage.getItem('companyId') || '943e411e-9c4c-484f-9dde-9db708f5159a';
    const token = localStorage.getItem('token');
    
    const response = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/sales/resellers-location`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { company_id: companyId }
    });

    resellersList.value = response.data.data;
    renderLayers();
  } catch (error) {
    console.error("❌ [UX ERROR] Erreur lors du chargement des resellers :", error);
  } finally {
    loading.value = false;
  }
};

const switchViewMode = (mode) => {
  viewMode.value = mode;
  renderLayers();
};

const renderLayers = () => {
  if (!map || !markerClusterGroup) return;

  markerClusterGroup.clearLayers();
  markerMap.clear();
  if (heatmapLayer) {
    map.removeLayer(heatmapLayer);
    heatmapLayer = null;
  }

  if (viewMode.value === 'standard') {
    resellersList.value.forEach(reseller => {
      const lat = parseFloat(reseller.latitude);
      const lng = parseFloat(reseller.longitude);
      if (isNaN(lat) || isNaN(lng)) return;

      const popupContent = `
        <div class="map-popup-card">
          <h4 style="margin: 0 0 6px 0; color: #000; font-size: 0.95rem;">👤 ${reseller.name}</h4>
          <p style="margin: 0 0 8px 0; color: #666; font-size: 0.8rem;">📦 <strong>Dépôt :</strong> ${reseller.deposit_name || 'Non spécifié'}</p>
          <div style="border-top: 1px solid #eee; margin: 6px 0;"></div>
          <p style="margin: 4px 0; font-size: 0.75rem; color: #333;">📞 <strong>Tél :</strong> ${reseller.phone || 'Non renseigné'}</p>
          <p style="margin: 4px 0; font-size: 0.75rem; color: #333;">📧 <strong>Email :</strong> ${reseller.email}</p>
        </div>
      `;

      const marker = L.marker([lat, lng], { icon: defaultIcon }).bindPopup(popupContent);
      markerClusterGroup.addLayer(marker);
      markerMap.set(reseller.id, marker);
    });
  } else if (viewMode.value === 'heatmap') {
    const heatPoints = resellersList.value
      .map(reseller => {
        const lat = parseFloat(reseller.latitude);
        const lng = parseFloat(reseller.longitude);
        if (isNaN(lat) || isNaN(lng)) return null;
        return [lat, lng, 0.7];
      })
      .filter(p => p !== null);

    if (window.L && window.L.heatLayer && heatPoints.length > 0) {
      heatmapLayer = window.L.heatLayer(heatPoints, {
        radius: 25,
        blur: 15,
        maxZoom: 15
      }).addTo(map);
    }
  }
};

const focusOnReseller = (reseller) => {
  const lat = parseFloat(reseller.latitude);
  const lng = parseFloat(reseller.longitude);
  if (isNaN(lat) || isNaN(lng)) return;

  searchQuery.value = reseller.name;

  if (viewMode.value === 'heatmap') {
    viewMode.value = 'standard';
    renderLayers();
  }

  map.flyTo([lat, lng], 16, { animate: true, duration: 1.2 });

  const marker = markerMap.get(reseller.id);
  if (marker) {
    setTimeout(() => {
      markerClusterGroup.zoomToShowLayer(marker, () => {
        marker.openPopup();
      });
    }, 1300);
  }
};

const onSearchEnter = () => {
  if (searchResults.value.length > 0) {
    focusOnReseller(searchResults.value[0]);
  }
};

// --- CORRECTIF DE L'ORDRE D'EXÉCUTION DU CYCLE DE VIE ---
onMounted(async () => {
  await loadLeafletPlugins(); // 1. On attend impérativement les scripts externes
  initMap();                  // 2. On initialise le DOM de la carte et les groupes associés
  await fetchResellers();     // 3. On charge les données épurées de l'API
  pollInterval = setInterval(fetchResellers, 45000);
});

onBeforeUnmount(() => {
  if (pollInterval) clearInterval(pollInterval);
  if (map) map.remove();
});
</script>

<style scoped>
/* Les styles restent identiques à ta charte graphique minimaliste */
.map-module-container { background: #ffffff; padding: 24px; border-radius: 4px; border: 1px solid #e5e5e5; margin-bottom: 24px; position: relative; }
.map-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 12px; }
.map-header h3 { font-size: 0.85rem; font-weight: 700; color: #000000; margin: 0; text-transform: uppercase; letter-spacing: 0.5px; }
.map-actions { display: flex; align-items: center; gap: 12px; }
.view-toggle { display: flex; background: #f5f5f5; padding: 4px; border-radius: 6px; border: 1px solid #e5e5e5; }
.toggle-btn { background: transparent; border: none; padding: 6px 12px; font-size: 0.75rem; font-weight: 600; cursor: pointer; border-radius: 4px; transition: all 0.2s; color: #666; }
.toggle-btn.active { background: #ffffff; color: #000000; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
.refresh-btn { background: #000000; color: #ffffff; border: none; padding: 8px 14px; border-radius: 4px; font-weight: 600; font-size: 0.75rem; cursor: pointer; }
.search-box-container { position: relative; margin-bottom: 20px; z-index: 1010; }
.search-input { width: 100%; padding: 12px 16px; border: 1px solid #e5e5e5; border-radius: 4px; font-size: 0.85rem; box-sizing: border-box; outline: none; }
.search-input:focus { border-color: #000000; }
.search-results-dropdown { position: absolute; top: 100%; left: 0; right: 0; background: #ffffff; border: 1px solid #e5e5e5; border-top: none; list-style: none; padding: 0; margin: 0; max-height: 260px; overflow-y: auto; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
.result-item { padding: 12px 16px; cursor: pointer; border-bottom: 1px solid #f9f9f9; }
.result-item:hover { background: #f5f5f5; }
.result-main { font-size: 0.85rem; font-weight: 700; color: #000000; display: flex; justify-content: space-between; }
.deposit-tag { font-size: 0.7rem; color: #707070; background: #f0f0f0; padding: 2px 8px; border-radius: 12px; }
.result-sub { font-size: 0.75rem; color: #707070; margin-top: 4px; }
.resellers-map { width: 100%; height: 520px; border-radius: 4px; border: 1px solid #e5e5e5; z-index: 1; }
</style>