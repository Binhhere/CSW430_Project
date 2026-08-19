INSERT INTO app_users (auth_user_id, email, password_hash)
VALUES (
  '11111111-1111-4111-8111-111111111111',
  'demo@csw430.local',
  '$2b$12$ArNeiFrxZHXx2L6LcKijE.AJ4iREEtRYNUvDW/INKvBdW54T947sK'
)
ON CONFLICT (auth_user_id) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO profiles (auth_user_id, display_name)
VALUES ('11111111-1111-4111-8111-111111111111', 'CSW430 Demo User')
ON CONFLICT (auth_user_id) DO UPDATE SET display_name = EXCLUDED.display_name;

INSERT INTO companies (id, owner_auth_user_id, name)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'CSW430 Demo Rentals')
ON CONFLICT (id) DO NOTHING;

INSERT INTO customers (owner_auth_user_id, name, contact_name, email, phone)
VALUES
  ('11111111-1111-4111-8111-111111111111', 'Northstar Events', 'Linh Nguyen', 'linh@example.local', '+84 900 000 001'),
  ('11111111-1111-4111-8111-111111111111', 'Brightline Productions', 'Minh Tran', 'minh@example.local', '+84 900 000 002')
ON CONFLICT DO NOTHING;
