import {createClient} from "@libsql/client";

export function createDb({url,authToken}){
 if(!url)throw Error("Configure TURSO_DATABASE_URL (or a local file: URL for tests)");
 return createClient({url,authToken});
}

// Therapist account storage only. Child/session/report data never lands here — see Server/README.md.
export async function migrate(db){
 await db.execute(`CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  email_verified_at TEXT,
  password_hash TEXT NOT NULL,
  profile_ciphertext BLOB NOT NULL,
  profile_nonce BLOB NOT NULL,
  profile_key_salt BLOB NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
 )`);
 await db.execute(`CREATE TABLE IF NOT EXISTS email_verifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  consumed_at TEXT,
  created_at TEXT NOT NULL
 )`);
 await db.execute(`CREATE INDEX IF NOT EXISTS email_verifications_user_id_idx ON email_verifications(user_id)`);
 await db.execute(`CREATE TABLE IF NOT EXISTS sessions (
  token_digest TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
 )`);
}
