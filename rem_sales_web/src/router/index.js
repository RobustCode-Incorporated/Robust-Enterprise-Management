import { createRouter, createWebHistory } from 'vue-router';
import Login from '../views/Login.vue';
import ResellerDashboard from '../views/ResellerDashboard.vue';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    // 🛡️ AJOUT : Redirection automatique de la racine vers le login
    { path: '/', redirect: '/login' }, 
    { path: '/login', component: Login },
    { path: '/register', component: () => import('../views/RegisterCompany.vue') },
    { path: '/reseller-dashboard', component: ResellerDashboard },
    { 
      path: '/dashboard', 
      component: () => import('../views/Dashboard.vue'),
      meta: { requiresAuth: true }
    }
  ]
});

// Le "Router Guard" : le videur de boîte de nuit
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token');
  if (to.meta.requiresAuth && !token) {
    next('/login'); // Pas de jeton ? Retour à la case login !
  } else {
    next();
  }
});

export default router;