# Prototype : globe GEV minimal (Option B)

Contexte complet dans `Resume by One.md` (dépôt `gods-eye-view`). Ce document
ne répète que ce qui concerne ce prototype précis.

## Ce qui a été fait

- Nouveau composant [rem_sales_web/src/components/GevGlobeMap.vue](../rem_sales_web/src/components/GevGlobeMap.vue) :
  un globe Cesium construit avec `gods-eye-view/application`
  (`createApplication`), en n'utilisant que :
  - `createApplicationViewer` (`gods-eye-view/application/viewer`) pour le
    viewer Cesium nu ;
  - `createEsriImagery` (`gods-eye-view/maps/imagery`) pour une imagerie de
    base gratuite, sans clé Cesium ion ;
  - `initAnnotations` (`gods-eye-view/annotations`) pour poser un pin par
    revendeur.
  - `createControls` et `createData` sont des no-op : ce prototype ne réutilise
    aucune couche métier de GEV (avions/navires/CCTV/etc.).
- Le composant appelle la **même API existante** que `ResellersMap.vue`
  (`GET /sales/resellers-location`), avec le même polling de 45 s — seul le
  moteur de rendu change (Cesium au lieu de Leaflet).
- Nouvelle vue [rem_sales_web/src/views/GlobePrototype.vue](../rem_sales_web/src/views/GlobePrototype.vue)
  et route `/globe-prototype`, ajoutées sans toucher aux routes existantes
  (`/dashboard`, `/reseller-dashboard`, etc.).
- Dépendances ajoutées dans `rem_sales_web/package.json` :
  `gods-eye-view` (github:bilawalsidhu/gods-eye-view), `cesium`, et en
  devDependency `vite-plugin-cesium` (branché dans `vite.config.js`).

## Ce qui n'a pas été fait (hors périmètre du prototype)

- Pas de mode heatmap (pas d'équivalent direct côté Cesium dans ce prototype).
- Pas de remplacement de `ResellersMap.vue` — les deux cartes coexistent.
- Le popup analytics (donut + top produits) n'a pas été porté sur le globe ;
  seul le pin + libellé (nom + dépôt) est affiché pour l'instant.

## Comment tester

```bash
cd rem_sales_web
npm install
npm run dev
```

Ouvrir `/globe-prototype` après connexion (le composant a besoin du `token`
et du `companyId` en `localStorage`, comme `ResellersMap.vue`).

## Suite possible

Voir la section "Prochaines étapes concrètes" de `Resume by One.md` :
décider si ce globe remplace Leaflet ou reste une bascule 2D/3D, puis porter
le popup analytics en overlay HTML au-dessus du canvas Cesium.
