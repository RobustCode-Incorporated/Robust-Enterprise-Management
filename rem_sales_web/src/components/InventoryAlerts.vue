<script setup>
import { onMounted } from 'vue'
import { useCatalogStore } from '../stores/catalog'

const catalogStore = useCatalogStore()

// Au montage du composant, le senior dev s'assure qu'on rafraîchit la data
onMounted(() => {
  if (catalogStore.products.length === 0) {
    catalogStore.fetchProducts()
  }
})
</script>

<template>
  <div class="inventory-alerts-container">
    <h2 class="section-title">🚨 État Critique des Stocks (Terrain)</h2>

    <!-- State: Chargement -->
    <div v-if="catalogStore.isLoading" class="loader">
      <p>Synchronisation avec les stocks du dépôt en cours...</p>
    </div>

    <!-- State: Erreur Réseau -->
    <div v-else-if="catalogStore.error" class="error-banner">
      <p>⚠️ {{ catalogStore.error }}</p>
      <button @click="catalogStore.fetchProducts" class="btn-retry">Réessayer</button>
    </div>

    <!-- State: Data validée -->
    <div v-else class="alerts-grid">
      <!-- Bloc Ruptures -->
      <div class="alert-card rupture">
        <h3>Rupture Totale ({{ catalogStore.outOfStockProducts.length }})</h3>
        <ul>
          <li v-for="product in catalogStore.outOfStockProducts" :key="product.serverId">
            <span class="prod-name">{{ product.name }}</span>
            <span class="badge badge-red">0 en stock</span>
          </li>
          <li v-if="catalogStore.outOfStockProducts.length === 0" class="no-alert">
            ✓ Aucune rupture à signaler.
          </li>
        </ul>
      </div>

      <!-- Bloc Alertes Critiques -->
      <div class="alert-card warning">
        <h3>Seuil d'Alerte Atteint ({{ catalogStore.lowStockProducts.length }})</h3>
        <ul>
          <li v-for="product in catalogStore.lowStockProducts" :key="product.serverId">
            <span class="prod-name">{{ product.name }}</span>
            <span class="badge badge-orange">Reste : {{ product.stockQuantity }} unités</span>
          </li>
          <li v-if="catalogStore.lowStockProducts.length === 0" class="no-alert">
            ✓ Tous les niveaux de stocks sont confortables.
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<style scoped>
.inventory-alerts-container {
  padding: 20px;
  background-color: #f8f9fa;
  border-radius: 8px;
}
.section-title {
  color: #1e1e2f;
  font-size: 1.25rem;
  margin-bottom: 15px;
}
.alerts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 20px;
}
.alert-card {
  background: #ffffff;
  border-radius: 6px;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
  border-top: 4px solid;
}
.rupture { border-top-color: #dc3545; }
.warning { border-top-color: #fd7e14; }
ul { list-style: none; padding: 0; margin: 10px 0 0 0; }
li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid #edf2f7;
  font-size: 0.9rem;
}
.prod-name { font-weight: 600; color: #2d3748; }
.badge {
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: bold;
}
.badge-red { background-color: #fff5f5; color: #e53e3e; }
.badge-orange { background-color: #fffaf0; color: #dd6b20; }
.no-alert { color: #38a169; justify-content: center; font-style: italic; border: none; }
.loader, .error-banner { text-align: center; padding: 30px; background: white; border-radius: 6px; }
.btn-retry { margin-top: 10px; background: #4c51bf; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; }
</style>