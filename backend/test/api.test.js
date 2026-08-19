import assert from 'node:assert/strict';
import test from 'node:test';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { createApp } from '../src/app.js';

function fakeDatabase() {
  const customers = new Map([['22222222-2222-4222-8222-222222222222', {
    id: '22222222-2222-4222-8222-222222222222', owner_auth_user_id: '11111111-1111-4111-8111-111111111111', name: 'Private Customer', contact_name: null, email: null, phone: null, archived_at: null, created_at: new Date(), updated_at: new Date(),
  }]]);
  const profile = { auth_user_id: '11111111-1111-4111-8111-111111111111', email: 'demo@example.com', display_name: 'Demo User', created_at: new Date(), updated_at: new Date() };
  return {
    async query(sql, params = []) {
      if (sql === 'SELECT 1') return { rowCount: 1, rows: [{ '?column?': 1 }] };
      if (sql.includes('FROM profiles p JOIN')) return { rowCount: 1, rows: [{ id: profile.auth_user_id, email: profile.email, display_name: profile.display_name, created_at: profile.created_at, updated_at: profile.updated_at }] };
      if (sql.includes('UPDATE profiles')) { profile.display_name = params[1]; return { rowCount: 1, rows: [{ id: profile.auth_user_id, display_name: profile.display_name, created_at: profile.created_at, updated_at: new Date() }] }; }
      if (sql.includes('SELECT * FROM customers')) return { rowCount: customers.has(params[0]) ? 1 : 0, rows: customers.has(params[0]) ? [customers.get(params[0])] : [] };
      if (sql.startsWith('INSERT INTO customers')) { const row = { id: '22222222-2222-4222-8222-222222222222', owner_auth_user_id: params[0], name: params[1], contact_name: params[2], email: params[3], phone: params[4], archived_at: null, created_at: new Date(), updated_at: new Date() }; customers.set(row.id, row); return { rowCount: 1, rows: [row] }; }
      if (sql.startsWith('SELECT id, owner_auth_user_id')) { const row = customers.get(params[0]); return { rowCount: row?.owner_auth_user_id === params[1] ? 1 : 0, rows: row?.owner_auth_user_id === params[1] ? [row] : [] }; }
      if (sql.startsWith('SELECT ') && sql.includes('FROM customers WHERE owner_auth_user_id')) return { rowCount: 0, rows: [] };
      if (sql.startsWith('DELETE FROM customers')) { const row = customers.get(params[0]); if (!row || row.owner_auth_user_id !== params[1]) return { rowCount: 0, rows: [] }; customers.delete(params[0]); return { rowCount: 1, rows: [{ id: params[0] }] }; }
      return { rowCount: 0, rows: [] };
    },
  };
}

const secret = 'test-secret';
const validToken = jwt.sign({ sub: '11111111-1111-4111-8111-111111111111', email: 'demo@example.com' }, secret);
const otherToken = jwt.sign({ sub: '33333333-3333-4333-8333-333333333333', email: 'other@example.com' }, secret);

function app() { return createApp({ db: fakeDatabase(), jwtSecret: secret }); }

test('health check confirms API and database', async () => {
  const response = await request(app()).get('/health').expect(200);
  assert.equal(response.body.success, true);
  assert.equal(response.body.data.database, 'healthy');
});

test('customer routes reject requests without a bearer token', async () => {
  const response = await request(app()).get('/api/v1/customers').expect(401);
  assert.equal(response.body.success, false);
});

test('customer creation validates and returns JSON envelope', async () => {
  const agent = request(app());
  await agent.post('/api/v1/customers').set('Authorization', `Bearer ${validToken}`).send({ name: '' }).expect(400);
  const response = await agent.post('/api/v1/customers').set('Authorization', `Bearer ${validToken}`).send({ name: 'Athena Events', email: 'events@example.com' }).expect(201);
  assert.equal(response.body.success, true);
  assert.equal(response.body.data.name, 'Athena Events');
});

test('customer detail cannot be read by another owner', async () => {
  const response = await request(app()).get('/api/v1/customers/22222222-2222-4222-8222-222222222222').set('Authorization', `Bearer ${otherToken}`).expect(404);
  assert.equal(response.body.message, 'Customer not found');
});
