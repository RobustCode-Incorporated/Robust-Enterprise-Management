<script setup>
import { ref } from 'vue'
import { useCatalogStore } from '../stores/catalog'

const catalogStore = useCatalogStore()

// État initial du formulaire vierge
const initialFormState = {
  name: '',
  sellingPrice: null,
  stockQuantity: null,
  minStockAlert: 5
}

const form = ref({ ...initialFormState })
const isSuccess = ref(false)
const errorMessage = ref('')

const handleSubmit = async () => {
  errorMessage.value = ''
  isSuccess.value = false

  // Validation de sécurité basique côté client
  if (!form.value.name || form.value.sellingPrice <= 0 || form.value.stockQuantity < 0) {
    errorMessage.value = 'Veuillez remplir correctement tous les champs obligatoires.'
    return
  }

  // Envoi au store Pinia -> Axios -> REM Backend -> DB Neon
  const success = await catalogStore.saveProduct(form.value)

  if (success) {
    isSuccess.value = true
    form.value = { ...initialFormState } // Reset le formulaire
    // Masquer le message de succès après 3 secondes
    setTimeout(() => { isSuccess.value = false }, 3000)
  } else {
    errorMessage.value = catalogStore.error || "Une erreur est survenue lors de l'enregistrement dans Neon."
  }
}
</script>

<template>
  <div class="form-container">
    <div class="form-header">
      <h2>📦 Ajouter un nouveau produit au catalogue</h2>
      <p>Le produit sera immédiatement disponible pour les vendeurs sur le terrain après leur prochaine synchronisation.</p>
    </div>

    <!-- Notifications d'état -->
    <div v-if="isSuccess" class="banner success">
      ✨ Produit enregistré avec succès dans la base Neon et propagé au réseau !
    </div>
    
    <div v-if="errorMessage" class="banner error">
      ⚠️ {{ errorMessage }}
    </div>

    <form @submit.prevent="handleSubmit" class="product-form">
      <div class="form-group">
        <label for="name">Désignation de l'article *</label>
        <input 
          id="name" 
          v-model="form.name" 
          type="text" 
          placeholder="Ex: Sac de Ciment Robust 50kg, Fer à béton 12..." 
          required
        />
      </div>

      <div class="form-row">
        <div class="form-group">
          <label for="price">Prix de vente unitaire *</label>
          <div class="input-with-suffix">
            <input 
              id="price" 
              v-model.number="form.sellingPrice" 
              type="number" 
              placeholder="0" 
              min="1"
              required
            />
            <span class="suffix">Multi-Devise</span>
          </div>
        </div>

        <div class="form-group">
          <label for="stock">Quantité initiale en stock *</label>
          <input 
            id="stock" 
            v-model.number="form.stockQuantity" 
            type="number" 
            placeholder="Ex: 100" 
            min="0"
            required
          />
        </div>
      </div>

      <div class="form-group">
        <label for="alert">Seuil d'alerte stock (Minimum critique) *</label>
        <input 
          id="alert" 
          v-model.number="form.minStockAlert" 
          type="number" 
          min="1"
          required
        />
        <small class="help-text">Le système déclenchera une alerte visuelle dès que le stock terrain passera sous cette valeur.</small>
      </div>

      <div class="form-actions">
        <button type="submit" :disabled="catalogStore.isLoading" class="btn-submit">
          <span v-if="catalogStore.isLoading">Enregistrement dans REM Backend...</span>
          <span v-else>💾 Sauvegarder le produit</span>
        </button>
      </div>
    </form>
  </div>
</template>

<style scoped>
.form-container {
  background: white;
  padding: 30px;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
  max-width: 700px;
  margin: 0 auto;
}

.form-header {
  margin-bottom: 24px;
}

.form-header h2 {
  color: #1a202c;
  font-size: 1.4rem;
  margin-bottom: 6px;
}

.form-header p {
  color: #718096;
  font-size: 0.9rem;
}

.product-form {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

label {
  font-size: 0.85rem;
  font-weight: 700;
  color: #4a5568;
}

input {
  padding: 10px 14px;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  font-size: 0.95rem;
  color: #2d3748;
  transition: border-color 0.2s;
}

input:focus {
  outline: none;
  border-color: #4c51bf;
  box-shadow: 0 0 0 3px rgba(76, 81, 191, 0.1);
}

.input-with-suffix {
  display: flex;
  position: relative;
}

.input-with-suffix input {
  width: 100%;
  padding-right: 110px;
}

.suffix {
  position: absolute;
  right: 10px;
  top: 50%;
  transform: translateY(-50%);
  font-size: 0.75rem;
  background: #edf2f7;
  padding: 4px 8px;
  border-radius: 4px;
  color: #4a5568;
  font-weight: bold;
}

.help-text {
  color: #a0aec0;
  font-size: 0.8rem;
}

.banner {
  padding: 12px 16px;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 600;
  margin-bottom: 20px;
}

.banner.success {
  background-color: #c6f6d5;
  color: #22543d;
  border: 1px solid #98e8aa;
}

.banner.error {
  background-color: #fff5f5;
  color: #e53e3e;
  border: 1px solid #feb2b2;
}

.btn-submit {
  background: #4c51bf;
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.2s;
  width: 100%;
}

.btn-submit:hover:not(:disabled) {
  background: #434190;
}

.btn-submit:disabled {
  background: #a0aec0;
  cursor: not-allowed;
}

@media (max-width: 576px) {
  .form-row { grid-template-columns: 1fr; gap: 20px; }
}
</style>