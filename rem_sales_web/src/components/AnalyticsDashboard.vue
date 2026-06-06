<template>
  <div class="analytics-container">
    <header class="stats-header">
      <h2>Vue d'ensemble analytique</h2>
      <p>Analyse en temps réel de 15 000+ transactions injectées.</p>
    </header>

    <!-- Cartes KPI -->
    <div class="kpi-grid">
      <div class="kpi-card">
        <span class="label">Chiffre d'Affaires</span>
        <span class="value">{{ totalRevenue.toLocaleString() }} $</span>
      </div>
      <div class="kpi-card">
        <span class="label">Volume de Ventes</span>
        <span class="value">{{ salesStore.sales.length }}</span>
      </div>
      <div class="kpi-card">
        <span class="label">Panier Moyen</span>
        <span class="value">{{ averageBasket.toFixed(2) }} $</span>
      </div>
    </div>

    <!-- Section Graphiques -->
    <div class="charts-grid">
      <div class="chart-box">
        <h3>Répartition des Statuts</h3>
        <apexchart type="donut" :options="donutOptions" :series="statusSeries"></apexchart>
      </div>
      <div class="chart-box">
        <h3>Évolution des Ventes</h3>
        <apexchart type="area" :options="lineOptions" :series="lineSeries"></apexchart>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useSalesStore } from '../stores/sales'

const salesStore = useSalesStore()

onMounted(() => {
  // On s'assure que les données sont chargées au montage
  if (salesStore.sales.length === 0) {
    salesStore.fetchSales() 
  }
})

// --- CALCULS KPI ---
const totalRevenue = computed(() => {
  return salesStore.sales
    .filter(s => s.status === 'PAID')
    .reduce((sum, s) => sum + Number(s.total_amount), 0)
})

const averageBasket = computed(() => {
  return salesStore.sales.length ? totalRevenue.value / salesStore.sales.length : 0
})

// --- CONFIG GRAPHIQUE DONUT (Statuts) ---
const statusSeries = computed(() => {
  const paid = salesStore.sales.filter(s => s.status === 'PAID').length
  const draft = salesStore.sales.filter(s => s.status === 'DRAFT').length
  const cancelled = salesStore.sales.filter(s => s.status === 'CANCELLED').length
  return [paid, draft, cancelled]
})

const donutOptions = {
  labels: ['Payées', 'Brouillons', 'Annulées'],
  colors: ['#00E396', '#FEB019', '#FF4560'],
  legend: { position: 'bottom' }
}

// --- CONFIG GRAPHIQUE LIGNE (Évolution) ---
const lineSeries = computed(() => [{
  name: 'Ventes ($)',
  data: [30, 40, 35, 50, 49, 60, 70, 91, 125] // Ici tu pourras mapper tes ventes par mois
}])

const lineOptions = {
  chart: { toolbar: { show: false } },
  stroke: { curve: 'smooth', colors: ['#000'] },
  xaxis: { categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'] }
}
</script>

<style scoped>
.analytics-container { display: flex; flex-direction: column; gap: 30px; }
.stats-header h2 { font-size: 1.8rem; margin: 0; }

.kpi-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
.kpi-card { background: #fff; padding: 20px; border-radius: 10px; border: 1px solid #eee; display: flex; flex-direction: column; }
.kpi-card .label { font-size: 0.8rem; color: #666; text-transform: uppercase; }
.kpi-card .value { font-size: 1.5rem; font-weight: 700; margin-top: 5px; }

.charts-grid { display: grid; grid-template-columns: 1fr 2fr; gap: 20px; }
.chart-box { background: #fff; padding: 20px; border-radius: 10px; border: 1px solid #eee; }
.chart-box h3 { font-size: 1rem; margin-bottom: 20px; border-bottom: 1px solid #f5f5f5; padding-bottom: 10px; }
</style>