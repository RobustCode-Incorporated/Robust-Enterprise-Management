<template>
  <div class="analytics-wrapper">
    
    <!-- 1. En-tête Analytique Industriel -->
    <div class="analytics-lead">
      <h2>Suivi Analytique Global</h2>
      <p>Analyse multi-tenant en temps réel du flux transactionnel Neon</p>
    </div>

    <!-- 2. Bloc Cartographique des Resellers (Impact Visuel Majeur) -->
    <div class="card-section-container">
      <ResellersMap />
    </div>

    <!-- 3. Grille de KPIs Financiers Dynamiques -->
    <div class="metrics-grid">
      <div class="metric-card">
        <span class="card-label">Chiffre d'Affaires Encaissé</span>
        <h3 class="card-number">{{ totalRevenue.toLocaleString() }} $</h3>
        <span class="card-status status-up">▲ Statut PAID</span>
      </div>
      <div class="metric-card">
        <span class="card-label">Volume de Ventes (Global)</span>
        <h3 class="card-number">{{ salesStore.sales.length }}</h3>
        <span class="card-status status-sync">● Documents Synchronisés</span>
      </div>
      <div class="metric-card">
        <span class="card-label">Panier Moyen</span>
        <h3 class="card-number">{{ averageBasket.toFixed(2) }} $</h3>
        <span class="card-status status-up">▲ Flux d'Affaires</span>
      </div>
    </div>

    <!-- 4. Grille des Graphiques de Performance (ApexCharts) -->
    <div class="charts-grid">
      <div class="chart-box">
        <h3>Répartition des Statuts Documents</h3>
        <apexchart type="donut" :options="donutOptions" :series="statusSeries"></apexchart>
      </div>
      <div class="chart-box">
        <h3>Évolution Temporelle des Ventes</h3>
        <apexchart type="area" :options="lineOptions" :series="lineSeries"></apexchart>
      </div>
    </div>

  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useSalesStore } from '../stores/sales'
import ResellersMap from './ResellersMap.vue'

// Initialisation du store global
const salesStore = useSalesStore()

onMounted(() => {
  console.log("[UX LOG] Initialisation de AnalyticsDashboard. Synchro des magasins et resellers.");
  if (salesStore.sales.length === 0) {
    salesStore.fetchSales() 
  }
})

// --- CALCULS METRICS FINANCIÈRES RÉELLES ---
const totalRevenue = computed(() => {
  return salesStore.sales
    .filter(s => s.status === 'PAID')
    .reduce((sum, s) => sum + Number(s.total_amount), 0)
})

const averageBasket = computed(() => {
  return salesStore.sales.length ? totalRevenue.value / salesStore.sales.length : 0
})

// --- CONFIGURATION APEXCHARTS : DONUT (Statuts) ---
const statusSeries = computed(() => {
  const paid = salesStore.sales.filter(s => s.status === 'PAID').length
  const draft = salesStore.sales.filter(s => s.status === 'DRAFT').length
  const cancelled = salesStore.sales.filter(s => s.status === 'CANCELLED').length
  return [paid, draft, cancelled]
})

const donutOptions = {
  labels: ['Payées', 'Brouillons', 'Annulées'],
  colors: ['#16a34a', '#FEB019', '#FF4560'], // Alignement vert Robust Code pour le PAID
  legend: { position: 'bottom', fontFamily: 'system-ui, sans-serif' },
  chart: { animations: { enabled: true } }
}

// --- CONFIGURATION APEXCHARTS : AREA CHART (Évolution) ---
const lineSeries = computed(() => [{
  name: 'Ventes ($)',
  data: [30, 40, 35, 50, 49, 60, 70, 91, 125] // Prêt pour le mapping dynamique de ta comptabilité
}])

const lineOptions = {
  chart: { toolbar: { show: false }, fontFamily: 'system-ui, sans-serif' },
  stroke: { curve: 'smooth', colors: ['#000000'], width: 2 }, // Courbe noire minimaliste haut de gamme
  fill: {
    type: 'gradient',
    gradient: { shadeIntensity: 1, opacityFrom: 0.2, opacityTo: 0, stops: [0, 90, 100] }
  },
  xaxis: { 
    categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
    labels: { style: { colors: '#707070' } }
  },
  yaxis: { labels: { style: { colors: '#707070' } } }
}
</script>

<style scoped>
.analytics-wrapper {
  display: flex;
  flex-direction: column;
  gap: 32px;
  padding-bottom: 40px;
}

/* En-tête */
.analytics-lead h2 {
  font-size: 1.4rem;
  font-weight: 700;
  color: #000000;
  margin: 0 0 4px 0;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.analytics-lead p {
  font-size: 0.85rem;
  color: #707070;
  margin: 0;
}

/* Carte */
.card-section-container {
  width: 100%;
}

/* Grille KPI */
.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 20px;
}
.metric-card {
  background: #ffffff;
  padding: 24px;
  border-radius: 4px;
  border: 1px solid #e5e5e5;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.card-label {
  font-size: 0.75rem;
  text-transform: uppercase;
  color: #707070;
  letter-spacing: 0.5px;
  font-weight: 600;
}
.card-number {
  font-size: 1.6rem;
  font-weight: 700;
  color: #000000;
  margin: 0;
}
.card-status {
  font-size: 0.75rem;
  font-weight: bold;
}
.card-status.status-up { color: #16a34a; }
.card-status.status-sync { color: #2563eb; }

/* Grille Graphiques */
.charts-grid {
  display: grid;
  grid-template-columns: 1fr 2fr;
  gap: 24px;
}
@media (max-width: 968px) {
  .charts-grid {
    grid-template-columns: 1fr;
  }
}
.chart-box {
  background: #ffffff;
  padding: 24px;
  border-radius: 4px;
  border: 1px solid #e5e5e5;
}
.chart-box h3 {
  font-size: 0.85rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #000000;
  margin: 0 0 20px 0;
  padding-bottom: 10px;
  border-bottom: 1px solid #f5f5f5;
}
</style>