<template>
  <div class="form-container">
    <div class="form-header">
      <h2>Ajouter un nouvel article</h2>
      <p>Configurez les détails du produit pour le rendre disponible dans le catalogue.</p>
    </div>

    <div v-if="isSuccess" class="banner success">Produit enregistré avec succès.</div>
    <div v-if="errorMessage" class="banner error">{{ errorMessage }}</div>

    <form @submit.prevent="handleSubmit" class="product-form">
      <div class="form-group">
        <label for="name">Désignation de l'article</label>
        <input id="name" v-model="form.name" type="text" placeholder="Ex: Sac de Ciment 50kg" required />
      </div>

      <div class="form-row">
        <div class="form-group">
          <label for="purchasePrice">Prix d'achat</label>
          <input id="purchasePrice" v-model.number="form.purchasePrice" type="number" placeholder="0" min="0" required />
        </div>
        <div class="form-group">
          <label for="sellingPrice">Prix de vente</label>
          <input id="sellingPrice" v-model.number="form.sellingPrice" type="number" placeholder="0" min="1" required />
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label for="stock">Quantité initiale</label>
          <input id="stock" v-model.number="form.stockQuantity" type="number" placeholder="Ex: 100" min="0" required />
        </div>
        <div class="form-group">
          <label for="currency">Monnaie</label>
          <select id="currency" v-model="form.currency">
            <option value="USD">USD ($)</option>
            <option value="EUR">EUR (€)</option>
            <option value="CDF">CDF (FC)</option>
          </select>
        </div>
      </div>

      <div class="form-group">
        <label for="alert">Seuil d'alerte stock</label>
        <input id="alert" v-model.number="form.minStockAlert" type="number" min="1" required />
      </div>

      <button type="submit" :disabled="catalogStore.loading" class="btn-submit">
        {{ catalogStore.loading ? 'Enregistrement...' : 'Sauvegarder le produit' }}
      </button>
    </form>

    <hr class="divider" />
    <div class="list-section">
      <h3>Catalogue actuel</h3>
      <table class="product-table">
        <thead>
          <tr>
            <th>Nom</th>
            <th>Stock</th>
            <th>Prix Achat</th>
            <th>Prix Vente</th>
            <th>Monnaie</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="product in catalogStore.products" :key="product.id">
            <td class="prod-name">{{ product.name }}</td>
            <td>{{ product.stock_quantity }}</td>
            <td>{{ product.purchase_price }}</td>
            <td>{{ product.selling_price }}</td>
            <td>
              <span class="currency-tag">{{ product.currency }}</span>
            </td>
          </tr>
          <tr v-if="catalogStore.products.length === 0">
            <td colspan="5" class="empty-msg">Aucun article enregistré.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useCatalogStore } from '../stores/catalog'

const catalogStore = useCatalogStore()

const initialFormState = {
  name: '',
  purchasePrice: null,
  sellingPrice: null,
  stockQuantity: null,
  minStockAlert: 5,
  currency: 'USD'
}

const form = ref({ ...initialFormState })
const isSuccess = ref(false)
const errorMessage = ref('')

onMounted(() => {
  catalogStore.fetchProducts()
})

const handleSubmit = async () => {
  errorMessage.value = ''
  isSuccess.value = false

  const success = await catalogStore.saveProduct(form.value)

  if (success) {
    isSuccess.value = true
    form.value = { ...initialFormState }
    setTimeout(() => { isSuccess.value = false }, 3000)
  } else {
    errorMessage.value = catalogStore.error || "Une erreur est survenue."
  }
}
</script>

<style scoped>
/* ... (ton style reste identique, assure-toi juste de garder .currency-tag) */
.form-container { background: white; padding: 40px; border-radius: 8px; max-width: 700px; margin: 0 auto; font-family: 'ABeeZee', sans-serif; }
.form-header { margin-bottom: 30px; }
.product-form { display: flex; flex-direction: column; gap: 20px; margin-bottom: 40px; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
label { font-size: 0.85rem; font-weight: 600; color: #333; }
input, select { padding: 12px; border: 1px solid #ddd; border-radius: 6px; }

.divider { border: 0; border-top: 1px solid #eee; margin: 30px 0; }
.list-section h3 { margin-bottom: 15px; font-size: 1.1rem; }
.product-table { width: 100%; border-collapse: collapse; }
.product-table th, .product-table td { padding: 12px; border-bottom: 1px solid #eee; text-align: left; font-size: 0.9rem; }
.prod-name { font-weight: 600; }
.currency-tag { font-size: 0.75rem; color: #000; font-weight: bold; background: #e0e0e0; padding: 4px 8px; border-radius: 4px; }
.empty-msg { text-align: center; color: #999; padding: 20px; }

.btn-submit { background: #000; color: #fff; border: none; padding: 15px; border-radius: 6px; font-weight: bold; cursor: pointer; }
.banner { padding: 12px; margin-bottom: 20px; border-radius: 6px; font-weight: 600; }
.success { background: #e8f5e9; color: #2e7d32; }
.error { background: #ffebee; color: #c62828; }
</style>