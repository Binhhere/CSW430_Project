import pg from 'pg';

export function createDatabase(connectionString) {
  const pool = new pg.Pool({ connectionString, max: 10 });
  return {
    query: (text, params) => pool.query(text, params),
    close: () => pool.end(),
  };
}
