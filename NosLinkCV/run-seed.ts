import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { Pool } from 'pg'; 

dotenv.config();

// Deteta automaticamente a string de ligação do seu .env
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

async function rodarSeed() {
  try {
    const seedPath = path.join(__dirname, 'seed.sql');
    const sql = fs.readFileSync(seedPath, 'utf8');
    
    console.log('⏳ A popular a base de dados do NôsLinkCV...');
    await pool.query(sql);
    console.log('✅ Dados de teste inseridos com absoluto sucesso!');
  } catch (error) {
    console.error('❌ Erro ao executar o seed:', error);
  } finally {
    await pool.end();
  }
}

rodarSeed();