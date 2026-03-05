const { Pool } = require("pg");
const config = require("../config");

const pool = new Pool({ connectionString: config.databaseUrl });

async function query(text, params) {
  return pool.query(text, params);
}

async function healthcheck() {
  const r = await pool.query("SELECT 1 as ok");
  return r.rows?.[0]?.ok === 1;
}

module.exports = { pool, query, healthcheck };
