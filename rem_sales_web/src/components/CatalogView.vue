<template>
  <div class="catalog-page">
    <div class="page-header">
      <h1>Mon Catalogue</h1>
      <button @click="showForm = !showForm" class="btn-primary">
        {{ showForm ? 'Fermer le formulaire' : '+ Ajouter un article' }}
      </button>
    </div>

    <ProductForm v-if="showForm" />

    <div class="table-container">
      <table class="product-table">
        <thead>
          <tr>
            <th>Nom de l'article</th>
            <th>Stock</th>
            <th>Prix Achat</th>
            <th>Prix Vente</th>
            <th>Seuil Alerte</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="product in catalogStore.products" :key="product.id">
            <td class="name-col">{{ product.name }}</td>
            <td>
              <span :class="['stock-badge', product.stock_quantity <= product.min_stock_alert ? 'low' : 'ok']">
                {{ product.stock_quantity }}
              </span>
            </td>
            <td>{{ product.purchase_price }} {{ product.currency }}</td>
            <td>{{ product.selling_price }} {{ product.currency }}</td>
            <td>{{ product.min_stock_alert }}</td>
          </tr>
          <tr v-if="catalogStore.products.length === 0">
            <td colspan="5" class="empty-msg">Aucun produit dans le catalogue pour le moment.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useCatalogStore } from '../stores/catalog'
import ProductForm from './ProductForm.vue'

const catalogStore = useCatalogStore()
const showForm = ref(false)

onMounted(() => {
  catalogStore.fetchProducts()
})
</script>

<style scoped>
.catalog-page { padding: 20px; font-family: 'ABeeZee', sans-serif; }
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
.btn-primary { background: #000; color: #fff; border: none; padding: 10px 20px; border-radius: 6px; cursor: pointer; }

.table-container { background: white; border-radius: 8px; overflow: hidden; border: 1px solid #eee; }
.product-table { width: 100%; border-collapse: collapse; text-align: left; }
.product-table th { background: #f9f9f9; padding: 15px; font-size: 0.85rem; color: #666; }
.product-table td { padding: 15px; border-top: 1px solid #eee; font-size: 0.9rem; }
.name-col { font-weight: 600; }

.stock-badge { padding: 4px 8px; border-radius: 4px; font-weight: bold; }
.stock-badge.low { background: #ffebee; color: #c62828; }
.stock-badge.ok { background: #e8f5e9; color: #2e7d32; }
.empty-msg { text-align: center; color: #999; padding: 40px; }
</style>