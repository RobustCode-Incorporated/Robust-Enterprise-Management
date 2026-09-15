import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import cesium from 'vite-plugin-cesium'

// https://vite.dev/config/
export default defineConfig({
  // cesium(): required to embed the prototype globe (Cesium's static
  // assets/workers) — see src/components/GevGlobeMap.vue.
  plugins: [vue(), cesium()],
})
