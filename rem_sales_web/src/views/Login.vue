<template>
  <div class="login-container">
    <div class="left-panel">
      <div class="branding">
        <img src="../assets/RobustCodelogowhite.png" alt="Logo REM" class="logo-rem" />
        <h1 class="title">ROBUST ENTERPRISE MANAGEMENT</h1>
      </div>
    </div>

    <div class="right-panel">
      <div class="form-wrapper">
        <h1 class="form-title">Connexion Administrateur</h1>

        <form class="login-form" @submit.prevent="handleLogin">
          <label>Email professionnel</label>
          <input v-model="credentials.email" type="email" placeholder="patron@entreprise.com" required />

          <label>Mot de passe</label>
          <input type="password" v-model="credentials.password" placeholder="••••••••" required />

          <button type="submit" :disabled="loading">
            {{ loading ? 'Connexion en cours...' : 'SE CONNECTER' }}
          </button>
        </form>

        <p class="register-text">
          Pas encore de compte ?
          <router-link to="/register">S’enregistrer</router-link>
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import axios from 'axios';
import { useRouter } from 'vue-router';

const router = useRouter();
const loading = ref(false);
const credentials = ref({ email: '', password: '' });

const handleLogin = async () => {
  loading.value = true;
  try {
    const res = await axios.post(`${import.meta.env.VITE_API_BASE_URL}/auth/login`, credentials.value);

    // Sauvegarde du jeton et des infos utilisateur
    localStorage.setItem('token', res.data.token);
    localStorage.setItem('companyId', res.data.user.companyId);
    localStorage.setItem('userRole', res.data.user.role);
    
    // Sauvegarde du vrai ID du revendeur si présent
    if (res.data.user.resellerId) {
      localStorage.setItem('resellerId', res.data.user.resellerId);
    } else {
      localStorage.setItem('resellerId', res.data.user.id);
    }

    // Redirection selon le rôle
    if (res.data.user.role === 'RESELLER') {
      router.push('/reseller-dashboard');
    } else {
      router.push('/dashboard');
    }

  } catch (err) {
    console.error(err);
    alert("Échec de la connexion : Vérifiez vos identifiants.");
  } finally {
    loading.value = false;
  }
};
</script>

<style scoped>
/* Structure globale */
.login-container {
  display: flex;
  height: 100vh;
  font-family: 'ABeeZee', sans-serif;
}

/* Panneau Gauche : Noir */
.left-panel {
  width: 40%;
  background-color: #000000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.branding {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 40px;
  width: 100%;
}

.logo-rem {
  width: 550px;
  height: auto;
  margin-bottom: 30px;
}

.title {
  color: #FFFAFA;
  font-size: 2.2rem;
  letter-spacing: 2px;
  font-weight: 300;
  white-space: nowrap; /* Force sur une seule ligne */
  width: 100%;
  font-family: 'Ysabeau Office', sans-serif;
}

/* Panneau Droit : Blanc Neige */
.right-panel {
  flex: 1;
  background-color: #FFFAFA;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.form-wrapper { width: 100%; max-width: 400px; }
.form-title { font-size: 22px; font-weight: bold; margin-bottom: 24px; color: #000; }
.login-form label { font-weight: 600; margin-bottom: 5px; display: block; color: #333; }
.login-form input { width: 100%; padding: 12px; margin-bottom: 20px; border: 1px solid #ddd; border-radius: 8px; box-sizing: border-box; }
.login-form button { width: 100%; background-color: #000; color: #fff; padding: 15px; border: none; border-radius: 8px; font-weight: bold; cursor: pointer; }
.register-text { margin-top: 20px; text-align: center; color: #707070; }
.register-text a { color: #000; font-weight: bold; text-decoration: none; }

/* Responsive : Masquer le logo sur mobile pour laisser place au formulaire */
@media (max-width: 768px) {
  .left-panel { display: none; }
}
</style>