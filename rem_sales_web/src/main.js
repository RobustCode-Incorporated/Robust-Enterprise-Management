import { createApp } from 'vue'
import { createPinia } from 'pinia'
import VueApexCharts from "vue3-apexcharts" // 💡 Importation de la bibliothèque graphique
import App from './App.vue'
import router from './router' 

const app = createApp(App)

app.use(createPinia())
app.use(router) 
app.use(VueApexCharts) // 💡 Enregistrement global pour pouvoir utiliser <apexchart> partout

app.mount('#app')