import { DatabaseSync } from 'node:sqlite';
import type { SQLiteDatabase } from 'expo-sqlite';

type Param = string | number | null;

function flat(params: unknown[]): Param[] {
  if (params.length === 1 && Array.isArray(params[0])) return params[0] as Param[];
  return params as Param[];
}

/**
 * The subset of expo-sqlite's async API that MochiNook uses, backed by Node's
 * built-in SQLite. Lets the real SQL in src/db run in plain Node tests.
 */
export function createTestDb(): SQLiteDatabase {
  const d = new DatabaseSync(':memory:');
  const api = {
    async execAsync(sql: string) {
      d.exec(sql);
    },
    async runAsync(sql: string, ...params: unknown[]) {
      const r = d.prepare(sql).run(...flat(params));
      return { changes: Number(r.changes), lastInsertRowId: Number(r.lastInsertRowid) };
    },
    async getFirstAsync<T>(sql: string, ...params: unknown[]) {
      return ((d.prepare(sql).get(...flat(params)) as T | undefined) ?? null) as T | null;
    },
    async getAllAsync<T>(sql: string, ...params: unknown[]) {
      return d.prepare(sql).all(...flat(params)) as T[];
    },
    async withTransactionAsync(task: () => Promise<void>) {
      d.exec('BEGIN');
      try {
        await task();
        d.exec('COMMIT');
      } catch (e) {
        d.exec('ROLLBACK');
        throw e;
      }
    },
  };
  return api as unknown as SQLiteDatabase;
}
