<template>
  <div class="list-container">
    <h3>Catalogue des Articles</h3>
    <table>
      <thead>
        <tr>
          <th>Nom</th>
          <th>Stock</th>
          <th>Prix Achat</th>
          <th>Prix Vente</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="product in catalogStore.products" :key="product.id">
          <td>{{ product.name }}</td>
          <td>{{ product.stock_quantity }}</td>
          <td>{{ product.purchase_price }}</td>
          <td>{{ product.selling_price }}</td>
        </tr>
      </tbody>
    </table>
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