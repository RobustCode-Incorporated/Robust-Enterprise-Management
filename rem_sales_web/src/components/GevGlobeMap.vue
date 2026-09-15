<template>
  <div class="gev-globe-container">
    <div class="gev-globe-header">
      <h3>Globe (prototype GEV)</h3>
      <button @click="fetchResellers" class="refresh-btn" :disabled="loading">
        {{ loading ? 'Mise à jour...' : '🔄 Actualiser' }}
      </button>
    </div>
    <p v-if="statusMessage" class="gev-globe-status">{{ statusMessage }}</p>
    <div ref="containerEl" class="gev-globe-canvas"></div>
  </div>
</template>

<script setup>
/**
 * Prototype Option B (voir "Resume by One.md" dans gods-eye-view) : remplace
 * la carte Leaflet 2D de ResellersMap.vue par un globe Cesium minimal, en
 * réutilisant uniquement le contrat de cycle de vie et le moteur
 * d'annotations de gods-eye-view — pas ses couches ADS-B/AIS/CCTV.
 *
 * Isolé volontairement de AnalyticsDashboard.vue : aucune route existante
 * n'est modifiée, ce composant vit derrière /globe-prototype.
 */
import { onMounted, onBeforeUnmount, ref } from 'vue';
import axios from 'axios';
import 'cesium/Build/Cesium/Widgets/widgets.css';
import { createApplication } from 'gods-eye-view/application';
import { createApplicationViewer } from 'gods-eye-view/application/viewer';
import { createEsriImagery } from 'gods-eye-view/maps/imagery';
import { initAnnotations } from 'gods-eye-view/annotations';

const containerEl = ref(null);
const loading = ref(false);
const statusMessage = ref('Démarrage du globe...');

let app = null;
let pollInterval = null;

function createScene({ defer, signal }) {
  const creditContainer = document.createElement('div');
  creditContainer.style.display = 'none';
  document.body.appendChild(creditContainer);
  defer(() => creditContainer.remove());

  const viewer = createApplicationViewer({
    container: containerEl.value,
    creditContainer,
  });
  defer(() => {
    if (!viewer.isDestroyed()) viewer.destroy();
  });

  return (async () => {
    viewer.scene.globe.show = true;
    const imagery = await createEsriImagery();
    signal.throwIfAborted();
    viewer.imageryLayers.addImageryProvider(imagery);
    // Default Cesium home view (whole globe) is enough for this prototype.
    return { viewer };
  })();
}

// Pas de gestion de style/caméra dédiée pour ce prototype : la vue par
// défaut du viewer Cesium suffit à prouver le rendu du globe + des pins.
function createControls() {
  return {};
}

// Aucune couche de données GEV (avions/navires/etc.) : REM fournit ses
// propres données (les revendeurs) directement via l'API existante.
function createData() {
  return {};
}

function createTools({ scene, defer }) {
  const annotations = initAnnotations({ viewer: scene.viewer });
  defer(() => annotations.destroy());
  return { annotations };
}

const fetchResellers = async () => {
  if (!app) return;
  const token = localStorage.getItem('token');
  if (!token) {
    statusMessage.value = 'Aucun token : connectez-vous pour charger les revendeurs.';
    return;
  }

  loading.value = true;
  try {
    const companyId =
      localStorage.getItem('companyId') || '943e411e-9c4c-484f-9dde-9db708f5159a';
    const response = await axios.get(
      `${import.meta.env.VITE_API_BASE_URL}/sales/resellers-location`,
      {
        headers: { Authorization: `Bearer ${token}` },
        params: { company_id: companyId },
      },
    );

    const { annotations } = app.getComponents().tools;
    annotations.clear();

    const pins = response.data.data
      .map((reseller) => {
        const lat = parseFloat(reseller.latitude);
        const lon = parseFloat(reseller.longitude);
        if (Number.isNaN(lat) || Number.isNaN(lon)) return null;
        return {
          type: 'pin',
          latitude: lat,
          longitude: lon,
          label: reseller.deposit_name
            ? `${reseller.name} — ${reseller.deposit_name}`
            : reseller.name,
        };
      })
      .filter(Boolean);

    if (pins.length) await annotations.annotate(pins);
    statusMessage.value = `${pins.length} revendeur(s) affiché(s) sur le globe.`;
  } catch (error) {
    if (error.response?.status === 401 || error.response?.status === 403) {
      if (pollInterval) {
        clearInterval(pollInterval);
        pollInterval = null;
      }
    }
    statusMessage.value = "Erreur lors du chargement des revendeurs.";
    console.error('[GevGlobeMap] fetchResellers failed:', error);
  } finally {
    loading.value = false;
  }
};

onMounted(async () => {
  app = createApplication({ createScene, createControls, createData, createTools });
  app.subscribe(({ status, phase }) => {
    if (status === 'starting') statusMessage.value = `Initialisation (${phase})...`;
    if (status === 'failed') statusMessage.value = 'Échec du démarrage du globe.';
  });

  try {
    await app.start();
    statusMessage.value = 'Globe prêt.';
    await fetchResellers();
    pollInterval = setInterval(fetchResellers, 45000);
  } catch (error) {
    statusMessage.value = 'Échec du démarrage du globe.';
    console.error('[GevGlobeMap] startup failed:', error);
  }
});

onBeforeUnmount(async () => {
  if (pollInterval) clearInterval(pollInterval);
  if (app) await app.destroy();
});
</script>

<style scoped>
.gev-globe-container {
  background: #ffffff;
  padding: 24px;
  border-radius: 4px;
  border: 1px solid #e5e5e5;
  margin-bottom: 24px;
}
.gev-globe-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}
.gev-globe-header h3 {
  font-size: 0.85rem;
  font-weight: 700;
  color: #000000;
  margin: 0;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.refresh-btn {
  background: #000000;
  color: #ffffff;
  border: none;
  padding: 8px 14px;
  border-radius: 4px;
  font-weight: 600;
  font-size: 0.75rem;
  cursor: pointer;
}
.refresh-btn:disabled {
  background: #666;
  cursor: not-allowed;
}
.gev-globe-status {
  font-size: 0.75rem;
  color: #707070;
  margin: 0 0 12px 0;
}
.gev-globe-canvas {
  position: relative;
  width: 100%;
  height: 520px;
  border-radius: 4px;
  border: 1px solid #e5e5e5;
  overflow: hidden;
}
</style>
