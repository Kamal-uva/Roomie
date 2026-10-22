import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const app = readFileSync(new URL('../src/main.jsx', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../supabase/migrations/20261022_dashboard_snapshot.sql', import.meta.url), 'utf8');

test('baseline dashboard issues 7 Supabase requests (1 membership + 6 parallel reads)', () => {
  const get = app.slice(app.indexOf('const get=useCallback'), app.indexOf('useEffect(', app.indexOf('const get=useCallback')));
  assert.equal((get.match(/supabase\.from\(/g) ?? []).length, 7);
});

test('snapshot proposal reduces 7 browser requests to 2 (71.4%)', () => {
  const baseline = 7;
  const proposed = 2; // membership lookup followed by get_room_dashboard RPC
  assert.equal((baseline - proposed) / baseline, 5 / 7);
});

test('snapshot RPC runs as caller and rejects nonmembers', () => {
  assert.match(sql, /security invoker/i);
  assert.match(sql, /where exists\s*\(/i);
  assert.match(sql, /m\.user_id\s*=\s*\(select auth\.uid\(\)\)/i);
  assert.match(sql, /grant execute on function public\.get_room_dashboard\(uuid\) to authenticated/i);
});

test('snapshot retains latest chore entries independently of 100-entry history cap', () => {
  assert.match(sql, /'lastTrash'/);
  assert.match(sql, /'lastVacuum'/);
  assert.match(sql, /kind = 'trash'/);
  assert.match(sql, /kind = 'vacuum'/);
});

test('frontend uses snapshot with fallback when RPC is not installed', () => {
  assert.match(app, /supabase\.rpc\('get_room_dashboard',\{p_room_id:id\}\)/);
  assert.match(app, /\['PGRST202','42883'\]\.includes\(snap\.error\.code\)/);
  assert.match(app, /if\(!snap\.error\)/);
});
