import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { fail } from './responses.js';

export function hashPassword(password) {
  return bcrypt.hash(password, 12);
}

export function comparePassword(password, hash) {
  return bcrypt.compare(password, hash);
}

export function createToken(user, secret) {
  return jwt.sign(
    { sub: user.auth_user_id, email: user.email, displayName: user.display_name },
    secret,
    { expiresIn: '8h' },
  );
}

export function requireUser(secret) {
  return async (req, res, next) => {
    const header = req.get('authorization');
    if (!header?.startsWith('Bearer ')) {
      return fail(res, 401, 'Bearer token is required');
    }
    try {
      const token = header.slice('Bearer '.length).trim();
      const claims = jwt.verify(token, secret);
      req.authUser = {
        id: claims.sub,
        email: claims.email,
        user_metadata: { display_name: claims.displayName },
      };
    } catch {
      return fail(res, 401, 'Invalid or expired access token');
    }
    return next();
  };
}
