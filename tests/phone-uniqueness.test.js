const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const appSource = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
const migrationPath = path.join(root, 'supabase/migrations/20261102140000_unique_profile_phone.sql');
const migration = fs.readFileSync(migrationPath, 'utf8');

function loadPhoneHelpers() {
  const normalizePhone = appSource.match(/^  function normalizePhone\(value\) \{[\s\S]*?^  \}/m)?.[0];
  const canonicalPhone = appSource.match(/^  function canonicalPhone\(value\) \{[\s\S]*?^  \}/m)?.[0];
  const phoneValid = appSource.split('\n').find(line => line.startsWith('  function phoneValid('));
  assert.ok(normalizePhone, 'normalizePhone helper must exist in app.js');
  assert.ok(canonicalPhone, 'canonicalPhone helper must exist in app.js');
  assert.ok(phoneValid, 'phoneValid helper must exist in app.js');

  const context = vm.createContext({});
  vm.runInContext(`${normalizePhone}\n${canonicalPhone}\n${phoneValid}\nglobalThis.phoneHelpers = { normalizePhone, canonicalPhone, phoneValid };`, context);
  return context.phoneHelpers;
}

test('phone forms converge to one Iranian national-format key', () => {
  const { normalizePhone, canonicalPhone, phoneValid } = loadPhoneHelpers();
  const forms = [
    '09123456789',
    '+989123456789',
    '00989123456789',
    '۰۹۱۲ ۳۴۵ ۶۷۸۹',
    '+٩٨٩١٢٣٤٥٦٧٨٩',
    '۰۰۹۸-۹۱۲-۳۴۵-۶۷۸۹',
  ];

  for (const form of forms) {
    assert.equal(canonicalPhone(form), '09123456789', `canonical form for ${form}`);
    assert.equal(phoneValid(form), '', `valid form for ${form}`);
  }
});

test('phone validation does not silently discard punctuation or malformed values', () => {
  const { normalizePhone, canonicalPhone, phoneValid } = loadPhoneHelpers();
  assert.equal(normalizePhone('0912,1234567'), '0912,1234567');
  assert.equal(canonicalPhone('9123456789'), '9123456789');
  assert.notEqual(phoneValid('0912,1234567'), '');
  assert.notEqual(phoneValid('0912345678'), '');
  assert.notEqual(phoneValid('9123456789'), '');
});

test('database migration enforces global canonical uniqueness and fails safely on existing conflicts', () => {
  assert.match(migration, /create or replace function public\.canonical_profile_phone\(p_phone text\)[\s\S]*?immutable/i);
  assert.match(migration, /translate\(p_phone, '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'\)/);
  assert.match(migration, /v_phone ~ '\^9\[0-9\]\{9\}\$'/);
  assert.match(migration, /create trigger profiles_phone_normalize\s+before insert or update of phone on public\.profiles/i);
  assert.match(migration, /group by public\.canonical_profile_phone\(p\.phone\)\s+having count\(\*\) > 1/i);
  assert.match(migration, /duplicate canonical phone numbers exist/i);
  assert.match(migration, /create unique index if not exists profiles_phone_canonical_unique_idx\s+on public\.profiles \(public\.canonical_profile_phone\(phone\)\)/i);
  assert.ok(migration.indexOf('create unique index') < migration.indexOf('create trigger profiles_phone_normalize'), 'the unique index should protect writes before the normalizing trigger is replaced');
  assert.match(migration, /to authenticated, service_role/i);
  assert.doesNotMatch(migration, /update\s+public\.profiles\s+set\s+phone/i, 'existing profile data must not be rewritten by the migration');
});

test('app canonicalizes before saving and the full schema includes the migration', () => {
  assert.match(appSource, /phone:canonicalPhone\(f\.get\('phone'\)\)/);
  assert.match(appSource, /profiles_phone_canonical_unique_idx/);

  const fullSchema = fs.readFileSync(path.join(root, 'supabase_schema.sql'), 'utf8');
  assert.ok(fullSchema.trimEnd().endsWith(migration.trim()), 'supabase_schema.sql should include the migration verbatim');
});
