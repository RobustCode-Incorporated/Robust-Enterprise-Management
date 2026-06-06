<template>
  <div class="module-container">
    <header class="module-header">
      <h2>Nouvelle Commande</h2>
    </header>

    <div class="order-form">
      <div class="form-group">
        <label>Article</label>
        <select v-model="selectedProduct" class="form-input">
          <option v-for="p in catalogStore.products" :key="p.id" :value="p">
            {{ p.name }} - {{ p.selling_price }} {{ p.currency }}
          </option>
        </select>
      </div>

      <div class="form-group">
        <label>Quantité</label>
        <input type="number" v-model="quantity" class="form-input" min="1" />
      </div>

      <button @click="placeOrder" class="btn-primary">Confirmer</button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useCatalogStore } from '../stores/catalog'

const catalogStore = useCatalogStore()
const selectedProduct = ref(null)
const quantity = ref(1)

onMounted(() => {
  catalogStore.fetchProducts()
})

const placeOrder = () => {
  console.log(`Commande de ${quantity.value}x ${selectedProduct.value.name}`)
  // Ici tu appelleras ton API de création de commande
}
</script>

<style scoped>
.order-form { max-width: 400px; background: #fff; padding: 20px; border-radius: 8px; border: 1px solid #eee; }
.form-group { margin-bottom: 20px; }
.form-input { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; }
.btn-primary { background: #000; color: #fff; border: none; padding: 12px; width: 100%; cursor: pointer; }
</style>