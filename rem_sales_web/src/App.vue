<script setup>
import { ref, onMounted, computed } from 'vue'
import { useCatalogStore } from './stores/catalog'
import { useSalesStore } from './stores/sales'
import InventoryAlerts from './components/InventoryAlerts.vue'
import SalesReconciliation from './components/SalesReconciliation.vue'
import ProductForm from './components/ProductForm.vue' 

// 🛡️ CORRECTION SENIOR DEV : On déclare les références vides.
// On évite d'exécuter useStore() directement ici pour ne pas bloquer l'initialisation de Pinia.
let catalogStore = null
let salesStore = null

// Flag de sécurité pour s'assurer que les stores sont prêts avant le rendu html
const isReady = ref(false)

// Navigation réactive simplifiée pour le MVP
const currentTab = ref('dashboard')

// Déconnexion simulée (Multi-tenant)
const tenantId = 'robust-corp-africa-123'

// Initialisation sécurisée des données au montage de la plateforme
onMounted(async () => {
  // 🍍 Initialisation sécurisée à l'intérieur du cycle de vie Vue
  catalogStore = useCatalogStore()
  salesStore = useSalesStore()
  
  isReady.value = true

  // Lancement des requêtes HTTP asynchrones vers le REM Backend
  try {
    await Promise.all([
      catalogStore.fetchProducts(),
      salesStore.fetchSalesDocuments()
    ])
  } catch (err) {
    console.error("⚡ [REM WEB APP] Erreur lors du chargement initial :", err)
  }
})

// 💡 CALCULATED : Gestion dynamique du titre de la topbar selon l'état de l'onglet actif
const currentTitle = computed(() => {
  if (currentTab.value === 'dashboard') return 'Tableau de Bord Financier'
  if (currentTab.value === 'inventory') return 'Supervision des Stocks'
  return 'Gestion du Catalogue Articles'
})

// 💡 COMPONENT MAP : Association propre de l'onglet actif avec son composant Vue
const activeComponent = computed(() => {
  if (currentTab.value === 'dashboard') return SalesReconciliation
  if (currentTab.value === 'inventory') return InventoryAlerts
  return ProductForm
})
</script>

<template>
  <div class="app-layout">
    <aside class="sidebar">
      <div class="brand">
        <span class="logo-icon">🚀</span>
        <div class="brand-text">
          <h1>REM Web Core</h1>
          <small>V1.0 - Multi-Tenant</small>
        </div>
      </div>

      <div class="tenant-badge">
        <span class="indicator green"></span>
        <span class="tenant-name">{{ tenantId }}</span>
      </div>

      <nav class="nav-menu">
        <button 
          :class="['nav-item', { active: currentTab === 'dashboard' }]"
          @click="currentTab = 'dashboard'"
        >
          📊 Suivi des Ventes
        </button>
        <button 
          :class="['nav-item', { active: currentTab === 'inventory' }]"
          @click="currentTab = 'inventory'"
        >
          🚨 Alertes Stocks
        </button>
        <button 
          :class="['nav-item', { active: currentTab === 'add-product' }]"
          @click="currentTab = 'add-product'"
        >
          📦 Ajouter un Produit
        </button>
      </nav>

      <div class="sidebar-footer">
        <p>Connecté en tant que <strong>Manager</strong></p>
      </div>
    </aside>

    <main class="main-content">
      <header class="topbar">
        <div class="topbar-left">
          <h2>{{ currentTitle }}</h2>
        </div>
        <div class="topbar-right">
          <span class="date-badge">📅 Mai 2026</span>
        </div>
      </header>

      <section class="content-body">
        <div v-if="!isReady" class="app-loader">
          <p>Initialisation de la plateforme d'administration REM...</p>
        </div>
        
        <keep-alive v-else>
          <component :is="activeComponent" />
        </keep-alive>
      </section>
    </main>
  </div>
</template>

<style>
/* 🎨 STYLES GLOBAUX DE RÉINITIALISATION ET DESIGN SYSTEM REM */
:root {
  --primary: #4c51bf;
  --primary-hover: #434190;
  --bg-main: #f7fafc;
  --bg-sidebar: #1a202c;
  --text-light: #edf2f7;
  --text-dark: #2d3748;
  --border-color: #e2e8f0;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
  font-family: 'Inter', system-ui, -apple-system, sans-serif;
}

body {
  background-color: var(--bg-main);
  color: var(--text-dark);
}

.app-layout {
  display: flex;
  min-height: 100vh;
}

/* 🏢 STYLES SIDEBAR */
.sidebar {
  width: 260px;
  background-color: var(--bg-sidebar);
  color: var(--text-light);
  display: flex;
  flex-direction: column;
  padding: 24px 16px;
  border-right: 1px solid var(--border-color);
}

.brand {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 24px;
}

.logo-icon {
  font-size: 1.8rem;
}

.brand-text h1 {
  font-size: 1.1rem;
  font-weight: 800;
  letter-spacing: 0.5px;
}

.brand-text small {
  color: #a0aec0;
  font-size: 0.75rem;
}

.tenant-badge {
  background: #2d3748;
  padding: 8px 12px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 30px;
  font-size: 0.8rem;
}

.indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.indicator.green { background-color: #48bb78; }

.tenant-name {
  font-family: monospace;
  color: #cbd5e0;
}

.nav-menu {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex-grow: 1;
}

.nav-item {
  background: none;
  border: none;
  color: #a0aec0;
  padding: 12px 16px;
  text-align: left;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.nav-item:hover:not(:disabled) {
  background: #2d3748;
  color: white;
}

.nav-item.active {
  background: var(--primary);
  color: white;
}

.nav-item.disabled {
  opacity: 0.4;
  cursor: not-allowed;
  font-style: italic;
}

.sidebar-footer {
  font-size: 0.8rem;
  color: #718096;
  border-top: 1px solid #2d3748;
  padding-top: 15px;
}

/* 🖥️ STYLES CONTENU PRINCIPAL */
.main-content {
  flex-grow: 1;
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow-y: auto;
}

.topbar {
  background: white;
  height: 70px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 30px;
  border-bottom: 1px solid var(--border-color);
}

.topbar-left h2 {
  font-size: 1.3rem;
  font-weight: 700;
  color: #1a202c;
}

.date-badge {
  background: #edf2f7;
  padding: 6px 12px;
  border-radius: 20px;
  font-size: 0.85rem;
  font-weight: 600;
  color: #4a5568;
}

.content-body {
  padding: 30px;
  flex-grow: 1;
  background-color: var(--bg-main);
}

.app-loader {
  text-align: center;
  padding: 50px;
  font-size: 1.1rem;
  color: #718096;
  font-weight: 600;
}

/* RESPONSIVE DESIGN DE BASE FOR TABLETS */
@media (max-width: 768px) {
  .app-layout { flex-direction: column; }
  .sidebar { width: 100%; height: auto; }
  .main-content { height: auto; }
}
</style>