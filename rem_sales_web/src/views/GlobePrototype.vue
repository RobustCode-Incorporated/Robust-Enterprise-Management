<template>
  <div class="globe-prototype-page">
    <header class="proto-banner">
      Prototype Option B — voir docs/GEV-GLOBE-PROTOTYPE.md
    </header>
    <GevGlobeMap />
  </div>
</template>

<script setup>
import GevGlobeMap from '../components/GevGlobeMap.vue';
</script>

<style scoped>
.globe-prototype-page {
  padding: 24px;
  max-width: 1100px;
  margin: 0 auto;
}
.proto-banner {
  background: #fff7ed;
  border: 1px solid #fed7aa;
  color: #9a3412;
  padding: 10px 16px;
  border-radius: 4px;
  font-size: 0.8rem;
  margin-bottom: 16px;
}
</style>
