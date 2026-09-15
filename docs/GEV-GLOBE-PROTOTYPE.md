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

## Itération 2 : spécificités "recherche" de GEV, pour la logistique

Objectif : la plateforme évolue vers la logistique (déplacement de
marchandises entre revendeurs/dépôts), donc deux capacités de recherche de
`gods-eye-view/search` ont été branchées sur le prototype :

- **Recherche d'adresse** — `createDefaultPlaceSearch(...).geocode(query)`,
  keyless via Photon (OpenStreetMap) par défaut, aucune clé requise. Un champ
  texte + bouton "Localiser" pose un pin et recentre la caméra (`flyTo: true`)
  sur l'adresse trouvée. Utile pour localiser une nouvelle adresse de
  livraison ou un nouveau dépôt sans connaître ses coordonnées GPS.
- **Itinéraire logistique (revendeurs)** — deux menus déroulants (revendeurs
  actuels) + un mode (voiture/vélo/à pied) calculent un vrai trajet routier
  via l'annotation `{ type: 'route', points, mode }` du moteur GEV, qui
  affiche la distance et la durée.
- **Trajet entre deux adresses libres** — même capacité, mais pour une
  adresse X → une adresse Y tapées au clavier (pas forcément des revendeurs
  connus, ex: une nouvelle adresse de livraison). Chaque adresse est d'abord
  géocodée via `placeSearch.geocode()`, puis les coordonnées obtenues
  alimentent la même annotation `route` que ci-dessus. Les deux formulaires
  partagent une fonction interne commune (`runRoute`) : seule la résolution
  du point de départ/arrivée diffère (revendeur connu vs adresse à géocoder).

Dans les deux cas, si le calcul échoue, GEV dégrade honnêtement vers une
ligne droite étiquetée "itinéraire indisponible" plutôt que d'inventer un
trajet — ce comportement vient de `gods-eye-view` sans code ajouté ici.

Le routage a besoin d'un serveur qui parle le protocole attendu par
`gods-eye-view/search` (`{ ok, geometry, distanceM, durationS }`) — ce
protocole n'est pas exposé dans le package public de GEV (son propre proxy
`/api/route` est interne à son serveur standalone). Un petit proxy a donc été
ajouté côté `rem-backend` :
[src/controllers/route.controller.ts](../rem-backend/src/controllers/route.controller.ts)
+ [src/routes/route.routes.ts](../rem-backend/src/routes/route.routes.ts),
monté sur `GET /api/route`, qui interroge **router.project-osrm.org** (le
serveur de démonstration public d'OSRM) et reformate sa réponse.

⚠️ **router.project-osrm.org est un service de démo**, pas garanti pour de la
production (quotas, disponibilité). Pour la suite : pointer la variable
d'env `OSRM_URL` du backend vers une instance OSRM auto-hébergée, ou un
fournisseur commercial (Mapbox Directions, GraphHopper, etc.) — aucun autre
changement n'est nécessaire côté frontend, le contrat reste le même.

Conséquence sur le polling existant : `fetchResellers()` n'appelle plus
`annotations.clear()` avant de re-poser les pins — l'engine GEV de-dup un pin
identique au lieu de le dupliquer, donc le rafraîchissement de 45 s n'efface
plus une recherche d'adresse ou un itinéraire en cours (bug latent de
l'itération 1, corrigé ici).

## Ce qui n'a pas été fait (hors périmètre du prototype)

- Pas de mode heatmap (pas d'équivalent direct côté Cesium dans ce prototype).
- Pas de remplacement de `ResellersMap.vue` — les deux cartes coexistent.
- Le popup analytics (donut + top produits) n'a pas été porté sur le globe ;
  seul le pin + libellé (nom + dépôt) est affiché pour l'instant.
- Pas d'itinéraire multi-arrêts (tournée de livraison) : seulement un trajet
  A → B pour l'instant, alors que GEV supporte déjà des waypoints multiples
  (`points: [...]`) côté moteur — une extension naturelle, pas un nouveau
  concept à inventer.
- Pas de notion de "dépôt" distincte du champ texte `deposit_name` dans le
  schéma actuel (pas de coordonnées propres à un dépôt) — contournable pour
  l'instant via "Trajet entre deux adresses" en tapant l'adresse du dépôt,
  mais un vrai dépôt géolocalisé resterait plus fiable qu'un géocodage à
  chaque calcul.

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
