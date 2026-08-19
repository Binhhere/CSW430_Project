import 'dotenv/config';
const required = ['DATABASE_URL', 'JWT_SECRET'];

export function loadConfig(env = process.env) {
  const usableEnvironment = Object.fromEntries(
    Object.entries(env).filter(([, value]) => value?.trim() && !value.trim().startsWith('your_')),
  );
  const merged = {
    ...usableEnvironment,
  };
  const missing = required.filter((key) => !merged[key]?.trim());
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  return {
    port: Number(merged.PORT ?? 3000),
    databaseUrl: merged.DATABASE_URL,
    jwtSecret: merged.JWT_SECRET,
  };
}
