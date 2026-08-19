import express from 'express';
import { randomUUID } from 'node:crypto';
import { ZodError } from 'zod';
import { comparePassword, createToken, hashPassword, requireUser } from './auth.js';
import { fail, ok } from './responses.js';
import { customerListSchema, customerSchema, loginSchema, profileSchema, registerSchema } from './validation.js';

const customerColumns = `id, owner_auth_user_id, name, contact_name, email, phone, created_at, updated_at, archived_at`;

function asCustomer(row) {
  return { ...row, active_transfer_count: 0 };
}

function zodBody(schema) {
  return (req, _res, next) => {
    req.validatedBody = schema.parse(req.body);
    next();
  };
}

export function createApp({ db, jwtSecret }) {
  const app = express();
  app.use(express.json({ limit: '32kb' }));

  app.get('/health', async (_req, res, next) => {
    try {
      await db.query('SELECT 1');
      ok(res, { api: 'healthy', database: 'healthy' }, 'Health check passed');
    } catch (error) { next(error); }
  });

  app.post('/api/v1/auth/register', zodBody(registerSchema), async (req, res, next) => {
    try {
      const input = req.validatedBody;
      const userId = randomUUID();
      const passwordHash = await hashPassword(input.password);
      await db.query(
        'INSERT INTO app_users (auth_user_id, email, password_hash) VALUES ($1, $2, $3)',
        [userId, input.email.toLowerCase(), passwordHash],
      );
      await db.query(
        'INSERT INTO profiles (auth_user_id, display_name) VALUES ($1, $2)',
        [userId, input.displayName],
      );
      const user = { auth_user_id: userId, email: input.email.toLowerCase(), display_name: input.displayName };
      return ok(res, {
        user: { id: userId, email: user.email, displayName: user.display_name },
        session: { accessToken: createToken(user, jwtSecret) },
      }, 'Registration completed', 201);
    } catch (error) { next(error); }
  });

  app.post('/api/v1/auth/login', zodBody(loginSchema), async (req, res, next) => {
    try {
      const { email, password } = req.validatedBody;
      const result = await db.query(
        `SELECT u.auth_user_id, u.email, u.password_hash, p.display_name
         FROM app_users u JOIN profiles p ON p.auth_user_id = u.auth_user_id
         WHERE u.email = $1`,
        [email.toLowerCase()],
      );
      const user = result.rows[0];
      if (!user || !user.password_hash || !(await comparePassword(password, user.password_hash))) {
        return fail(res, 401, 'Invalid email or password');
      }
      return ok(res, {
        user: { id: user.auth_user_id, email: user.email, displayName: user.display_name },
        session: { accessToken: createToken(user, jwtSecret) },
      }, 'Login completed');
    } catch (error) { next(error); }
  });

  const authenticated = requireUser(jwtSecret);
  app.get('/api/v1/profile', authenticated, async (req, res, next) => {
    try {
      const result = await db.query(
        `SELECT p.auth_user_id AS id, u.email, p.display_name, p.created_at, p.updated_at
         FROM profiles p JOIN app_users u ON u.auth_user_id = p.auth_user_id WHERE p.auth_user_id = $1`,
        [req.authUser.id],
      );
      if (result.rowCount === 0) return fail(res, 404, 'Profile not found');
      return ok(res, result.rows[0]);
    } catch (error) { next(error); }
  });

  app.put('/api/v1/profile', authenticated, zodBody(profileSchema), async (req, res, next) => {
    try {
      const result = await db.query(
        `UPDATE profiles SET display_name = $2, updated_at = NOW() WHERE auth_user_id = $1
         RETURNING auth_user_id AS id, display_name, created_at, updated_at`,
        [req.authUser.id, req.validatedBody.displayName],
      );
      if (result.rowCount === 0) return fail(res, 404, 'Profile not found');
      return ok(res, result.rows[0], 'Profile updated');
    } catch (error) { next(error); }
  });

  app.get('/api/v1/companies', authenticated, async (req, res, next) => {
    try {
      const result = await db.query(
        `SELECT id, name, 'OWNER' AS role FROM companies WHERE owner_auth_user_id = $1 ORDER BY name`,
        [req.authUser.id],
      );
      return ok(res, result.rows);
    } catch (error) { next(error); }
  });

  app.get('/api/v1/customers', authenticated, async (req, res, next) => {
    try {
      const input = customerListSchema.parse(req.query);
      const filter = input.archiveScope === 'ARCHIVED' ? 'archived_at IS NOT NULL' : 'archived_at IS NULL';
      const query = input.query ? `%${input.query}%` : null;
      const result = await db.query(
        `SELECT ${customerColumns} FROM customers WHERE owner_auth_user_id = $1 AND ${filter}
         AND ($2::text IS NULL OR name ILIKE $2 OR contact_name ILIKE $2)
         ORDER BY name ASC, id ASC LIMIT $3`,
        [req.authUser.id, query, input.limit],
      );
      return ok(res, result.rows.map(asCustomer));
    } catch (error) { next(error); }
  });

  app.get('/api/v1/customers/:customerId', authenticated, async (req, res, next) => {
    try {
      const result = await db.query(
        `SELECT ${customerColumns} FROM customers WHERE id = $1 AND owner_auth_user_id = $2`,
        [req.params.customerId, req.authUser.id],
      );
      if (result.rowCount === 0) return fail(res, 404, 'Customer not found');
      return ok(res, asCustomer(result.rows[0]));
    } catch (error) { next(error); }
  });

  app.post('/api/v1/customers', authenticated, zodBody(customerSchema), async (req, res, next) => {
    try {
      const value = req.validatedBody;
      const result = await db.query(
        `INSERT INTO customers (owner_auth_user_id, name, contact_name, email, phone, archived_at)
         VALUES ($1, $2, $3, $4, $5, CASE WHEN $6 THEN NOW() ELSE NULL END) RETURNING ${customerColumns}`,
        [req.authUser.id, value.name, value.contactName || null, value.email || null, value.phone || null, value.archived ?? false],
      );
      return ok(res, asCustomer(result.rows[0]), 'Customer created', 201);
    } catch (error) { next(error); }
  });

  app.put('/api/v1/customers/:customerId', authenticated, zodBody(customerSchema.partial()), async (req, res, next) => {
    try {
      const current = await db.query('SELECT * FROM customers WHERE id = $1 AND owner_auth_user_id = $2', [req.params.customerId, req.authUser.id]);
      if (current.rowCount === 0) return fail(res, 404, 'Customer not found');
      const value = { ...current.rows[0], ...req.validatedBody };
      const archivedAt = req.validatedBody.archived === undefined ? current.rows[0].archived_at : (req.validatedBody.archived ? new Date() : null);
      const result = await db.query(
        `UPDATE customers SET name = $3, contact_name = $4, email = $5, phone = $6, archived_at = $7, updated_at = NOW()
         WHERE id = $1 AND owner_auth_user_id = $2 RETURNING ${customerColumns}`,
        [req.params.customerId, req.authUser.id, value.name, value.contactName || null, value.email || null, value.phone || null, archivedAt],
      );
      return ok(res, asCustomer(result.rows[0]), 'Customer updated');
    } catch (error) { next(error); }
  });

  app.delete('/api/v1/customers/:customerId', authenticated, async (req, res, next) => {
    try {
      const result = await db.query('DELETE FROM customers WHERE id = $1 AND owner_auth_user_id = $2 RETURNING id', [req.params.customerId, req.authUser.id]);
      if (result.rowCount === 0) return fail(res, 404, 'Customer not found');
      return ok(res, { id: result.rows[0].id }, 'Customer deleted');
    } catch (error) { next(error); }
  });

  app.use((error, _req, res, _next) => {
    if (error instanceof ZodError) return fail(res, 400, 'Invalid request data', error.issues);
    console.error(error);
    return fail(res, 500, 'Unexpected server error');
  });
  return app;
}
