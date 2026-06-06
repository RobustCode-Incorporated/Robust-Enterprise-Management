<template>
  <div class="module-container">
    <header class="module-header">
      <h2>Catalogue des Produits</h2>
      <p>Voici la liste des articles disponibles à la commande.</p>
    </header>

    <div class="table-container">
      <table class="styled-table">
        <thead>
          <tr>
            <th>Article</th>
            <th>Prix de Vente</th>
            <th>Devise</th>
          </tr>
        </thead>
        <tbody>
          <!-- On utilise la liste issue du store -->
          <tr v-for="product in catalogStore.products" :key="product.id">
            <td class="name-col">{{ product.name }}</td>
            <td class="price-col">{{ product.selling_price }}</td>
            <td><span class="currency-tag">{{ product.currency }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useCatalogStore } from '../stores/catalog'

const catalogStore = useCatalogStore()

onMounted(() => {
  catalogStore.fetchProducts()
})
</script>

<style scoped>
.module-container { max-width: 700px; margin: 0 auto; }
.module-header { margin-bottom: 25px; }
.styled-table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; border: 1px solid #eee; }
.styled-table th { background: #f9f9f9; padding: 15px; text-align: left; font-size: 0.85rem; color: #666; }
.styled-table td { padding: 15px; border-bottom: 1px solid #eee; }
.name-col { font-weight: 600; }
.price-col { font-weight: bold; }
.currency-tag { font-size: 0.75rem; background: #eee; padding: 4px 8px; border-radius: 4px; }
</style>