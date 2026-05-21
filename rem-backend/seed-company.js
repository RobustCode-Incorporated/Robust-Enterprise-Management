const { Client } = require('pg');
require('dotenv').config();

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.error('❌ Erreur : La variable DATABASE_URL n\'est pas définie.');
  process.exit(1);
}

const client = new Client({ 
  connectionString, 
  ssl: { rejectUnauthorized: false } 
});

async function seed() {
  try {
    await client.connect();
    
    const companyUuid = 'bf30cd12-9c1d-4074-b4a0-000000000000';
    const clientUuid1 = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
    const clientUuid2 = 'f6e5d4c3-b2a1-0f9e-8d7c-6b5a4f3e2d1c';
    
    // 1. Assurer la présence de l'entreprise
    await client.query(
      'INSERT INTO companies (id, name, country, created_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (id) DO NOTHING;',
      [companyUuid, 'Boutique Africa Mobile Test', 'SN']
    );
    
    // 2. Insérer le Premier Client (pour le Devis)
    // Note : Ajustez les noms de colonnes (ex: name, company_id) selon votre structure réelle si besoin
    await client.query(
      'INSERT INTO clients (id, company_id, name, email, created_at) VALUES ($1, $2, $3, $4, NOW()) ON CONFLICT (id) DO NOTHING;',
      [clientUuid1, companyUuid, 'Malick Diop', 'malick@diop.sn']
    );

    // 3. Insérer le Deuxième Client (pour la Facture)
    await client.query(
      'INSERT INTO clients (id, company_id, name, email, created_at) VALUES ($1, $2, $3, $4, NOW()) ON CONFLICT (id) DO NOTHING;',
      [clientUuid2, companyUuid, 'Awa Ndiaye', 'awa@ndiaye.sn']
    );
    
    console.log('\n🌟 [DATABASE SUCCESS] Entreprise et Clients de test injectés !');
    console.log(`ID Entreprise : ${companyUuid}`);
    console.log(`ID Client 1  : ${clientUuid1}`);
    console.log(`ID Client 2  : ${clientUuid2}\n`);
  } catch (err) {
    console.error('❌ Échec de l\'insertion :', err.message);
  } finally {
    await client.end();
  }
}

seed();
