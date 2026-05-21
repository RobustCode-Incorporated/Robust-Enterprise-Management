const { Client } = require('pg');
require('dotenv').config();
const client = new Client({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
async function run() {
  try {
    await client.connect();
    const co = 'bf30cd12-9c1d-4074-b4a0-000000000000';
    const c1 = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
    const c2 = 'f6e5d4c3-b2a1-0f9e-8d7c-6b5a4f3e2d1c';
    await client.query('INSERT INTO companies (id, name, country, created_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (id) DO NOTHING;', [co, 'Boutique Africa Mobile Test', 'SN']);
    await client.query('INSERT INTO clients (id, company_id, name, email, created_at) VALUES ($1, $2, $3, $4, NOW()) ON CONFLICT (id) DO NOTHING;', [c1, co, 'Malick Diop', 'malick@diop.sn']);
    await client.query('INSERT INTO clients (id, company_id, name, email, created_at) VALUES ($1, $2, $3, $4, NOW()) ON CONFLICT (id) DO NOTHING;', [c2, co, 'Awa Ndiaye', 'awa@ndiaye.sn']);
    console.log('DATABASE_SUCCESS');
  } catch (e) { console.error('Erreur SQL:', e.message); }
  finally { await client.end(); }
}
run();
