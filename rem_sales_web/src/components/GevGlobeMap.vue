<template>
  <div class="gev-globe-container">
    <div class="gev-globe-header">
      <h3>Globe (prototype GEV)</h3>
      <button @click="fetchResellers" class="refresh-btn" :disabled="loading">
        {{ loading ? 'Mise à jour...' : '🔄 Actualiser' }}
      </button>
    </div>
    <p v-if="statusMessage" class="gev-globe-status">{{ statusMessage }}</p>

    <div class="gev-tools-row">
      <div class="gev-tool-box">
        <label class="gev-tool-label">🔎 Rechercher une adresse</label>
        <div class="gev-tool-inline">
          <input
            v-model="addressQuery"
            @keydown.enter="searchAddress"
            type="text"
            placeholder="Ex: Rue de la Loi 16, Bruxelles"
            class="gev-tool-input"
          />
          <button @click="searchAddress" :disabled="addressSearching" class="gev-tool-btn">
            {{ addressSearching ? '...' : 'Localiser' }}
          </button>
        </div>
        <p v-if="addressMessage" class="gev-tool-message">{{ addressMessage }}</p>
      </div>

      <div class="gev-tool-box">
        <label class="gev-tool-label">🚚 Itinéraire logistique</label>
        <div class="gev-tool-inline">
          <select v-model="routeFromId" class="gev-tool-select">
            <option value="" disabled>Départ...</option>
            <option v-for="r in resellersList" :key="'from-' + r.id" :value="r.id">{{ r.name }}</option>
          </select>
          <select v-model="routeToId" class="gev-tool-select">
            <option value="" disabled>Arrivée...</option>
            <option v-for="r in resellersList" :key="'to-' + r.id" :value="r.id">{{ r.name }}</option>
          </select>
          <select v-model="routeMode" class="gev-tool-select gev-tool-select-mode">
            <option value="car">🚗</option>
            <option value="bike">🚲</option>
            <option value="foot">🚶</option>
          </select>
          <button @click="computeRoute" :disabled="routeComputing" class="gev-tool-btn">
            {{ routeComputing ? '...' : 'Calculer' }}
          </button>
        </div>
        <p v-if="routeMessage" class="gev-tool-message">{{ routeMessage }}</p>
      </div>
    </div>

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
import { createDefaultPlaceSearch } from 'gods-eye-view/search';

const containerEl = ref(null);
const loading = ref(false);
const statusMessage = ref('Démarrage du globe...');
const resellersList = ref([]);

// Recherche d'adresse (GEV/search, keyless via Photon — voir docs/GEV-GLOBE-PROTOTYPE.md)
const addressQuery = ref('');
const addressSearching = ref(false);
const addressMessage = ref('');

// Itinéraire logistique entre deux revendeurs (GEV/search route, proxy OSRM côté backend)
const routeFromId = ref('');
const routeToId = ref('');
const routeMode = ref('car');
const routeComputing = ref(false);
const routeMessage = ref('');

let app = null;
let pollInterval = null;
let placeSearch = null;

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

function createTools({ scene, signal, defer }) {
  // Keyless geocoding (Photon) for the address search box; route() is proxied
  // by the REM backend (/api/route -> OSRM) for the logistics itinerary below.
  placeSearch = createDefaultPlaceSearch({
    signal,
    endpoints: { route: `${import.meta.env.VITE_API_BASE_URL}/route` },
  });
  const annotations = initAnnotations({ viewer: scene.viewer, placeSearch });
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
    resellersList.value = response.data.data;

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

    // Pas de clear() ici : l'engine de-dup un pin identique (même place, même
    // libellé) plutôt que de le dupliquer, donc un rafraîchissement de 45s ne
    // fait pas disparaître une recherche d'adresse ou un itinéraire en cours.
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

const searchAddress = async () => {
  if (!app || !placeSearch || !addressQuery.value.trim()) return;
  addressSearching.value = true;
  addressMessage.value = '';
  try {
    const { place } = await placeSearch.geocode(addressQuery.value.trim());
    if (!place) {
      addressMessage.value = 'Adresse introuvable.';
      return;
    }
    const { annotations } = app.getComponents().tools;
    await annotations.annotate(
      [
        {
          type: 'pin',
          latitude: place.lat,
          longitude: place.lng,
          label: place.label || place.name || addressQuery.value,
        },
      ],
      { flyTo: true },
    );
    addressMessage.value = `Localisé : ${place.label || place.name}`;
  } catch (error) {
    addressMessage.value = 'Erreur pendant la recherche.';
    console.error('[GevGlobeMap] searchAddress failed:', error);
  } finally {
    addressSearching.value = false;
  }
};

const computeRoute = async () => {
  if (!app || !placeSearch) return;
  const from = resellersList.value.find((r) => r.id === routeFromId.value);
  const to = resellersList.value.find((r) => r.id === routeToId.value);
  if (!from || !to) {
    routeMessage.value = 'Choisissez un revendeur de départ et un d’arrivée.';
    return;
  }

  routeComputing.value = true;
  routeMessage.value = '';
  try {
    const { annotations } = app.getComponents().tools;
    const result = await annotations.annotate(
      [
        {
          type: 'route',
          mode: routeMode.value,
          label: `${from.name} → ${to.name}`,
          points: [
            { latitude: parseFloat(from.latitude), longitude: parseFloat(from.longitude) },
            { latitude: parseFloat(to.latitude), longitude: parseFloat(to.longitude) },
          ],
        },
      ],
      { flyTo: true },
    );
    const leg = result.results?.[0];
    if (!leg?.ok) {
      routeMessage.value = "Impossible de calculer l'itinéraire.";
      return;
    }
    const km = (leg.distanceM / 1000).toFixed(1);
    const minutes = Number.isFinite(leg.durationS) ? Math.round(leg.durationS / 60) : null;
    routeMessage.value = leg.fallback
      ? `⚠️ Itinéraire indisponible — ligne directe : ${km} km`
      : `${km} km${minutes ? ` · ~${minutes} min` : ''} (${routeMode.value})`;
  } catch (error) {
    routeMessage.value = "Erreur pendant le calcul de l'itinéraire.";
    console.error('[GevGlobeMap] computeRoute failed:', error);
  } finally {
    routeComputing.value = false;
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
  placeSearch = null;
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
.gev-tools-row {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 16px;
}
.gev-tool-box {
  flex: 1 1 320px;
  background: #f9f9f9;
  border: 1px solid #e5e5e5;
  border-radius: 4px;
  padding: 12px;
}
.gev-tool-label {
  display: block;
  font-size: 0.7rem;
  font-weight: 700;
  color: #333;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  margin-bottom: 8px;
}
.gev-tool-inline {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}
.gev-tool-input {
  flex: 1 1 180px;
  padding: 8px 10px;
  border: 1px solid #e5e5e5;
  border-radius: 4px;
  font-size: 0.8rem;
  outline: none;
}
.gev-tool-input:focus {
  border-color: #000000;
}
.gev-tool-select {
  flex: 1 1 120px;
  padding: 8px 10px;
  border: 1px solid #e5e5e5;
  border-radius: 4px;
  font-size: 0.8rem;
  background: #ffffff;
}
.gev-tool-select-mode {
  flex: 0 0 64px;
}
.gev-tool-btn {
  background: #000000;
  color: #ffffff;
  border: none;
  padding: 8px 14px;
  border-radius: 4px;
  font-weight: 600;
  font-size: 0.75rem;
  cursor: pointer;
}
.gev-tool-btn:disabled {
  background: #666;
  cursor: not-allowed;
}
.gev-tool-message {
  font-size: 0.72rem;
  color: #444;
  margin: 8px 0 0 0;
}
</style>
