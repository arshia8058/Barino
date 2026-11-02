const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

function loadAppHelpers() {
  const noop = () => {};
  const document = {
    querySelector: () => null,
    querySelectorAll: () => [],
    addEventListener: noop,
    createElement: () => ({ setAttribute: noop, append: noop, remove: noop })
  };
  const window = {
    addEventListener: noop,
    setTimeout,
    clearTimeout,
    sessionStorage: { getItem: () => null, setItem: noop, removeItem: noop }
  };
  const context = vm.createContext({
    window,
    document,
    navigator: { onLine: true },
    location: { hash: '', href: 'https://example.test/Barino/', pathname: '/Barino/', origin: 'https://example.test' },
    history: { replaceState: noop },
    URL,
    URLSearchParams,
    Intl,
    Date,
    Math,
    Number,
    String,
    Boolean,
    Array,
    Object,
    Error,
    RegExp,
    JSON,
    Promise,
    setTimeout,
    clearTimeout,
    requestAnimationFrame: noop,
    HTMLFormElement: function HTMLFormElement() {},
    confirm: () => true,
    globalThis: null
  });
  context.globalThis = context;
  const source = read('app.js').replace(
    /\n  init\(\);\n\}\)\(\);\s*$/,
    '\n  globalThis.__barinoTest = { normalizeDigits, normalizePhone, phoneValid, positiveNumber, positiveInteger, humanError, statusLabel };\n})();\n'
  );
  vm.runInContext(source, context, { filename: 'app.js' });
  return context.__barinoTest;
}

test('phone validation accepts only the three documented Iranian formats', () => {
  const helpers = loadAppHelpers();
  const valid = [
    '09121234567',
    '+989123456789',
    '00989123456789',
    '۰۹۱۲ ۱۲۳-۴۵۶۷',
    '+۹۸۹۱۲۳۴۵۶۷۸۹',
    '٠٠٩٨٩١٢٣٤٥٦٧٨٩'
  ];
  const invalid = ['9121234567', '0912123456', '+98912345678x', '989123456789', '0912,1234567', '001234'];
  for (const phone of valid) assert.equal(helpers.phoneValid(phone), '', phone);
  for (const phone of invalid) assert.notEqual(helpers.phoneValid(phone), '', phone);
  assert.equal(helpers.normalizePhone('۰۹۱۲ ۱۲۳-۴۵۶۷'), '09121234567');
});

test('numeric form validation preserves bigint-sized fares without accepting invalid values', () => {
  const helpers = loadAppHelpers();
  assert.equal(helpers.positiveNumber('۱۲٫۵۰'), '');
  assert.notEqual(helpers.positiveNumber('1e3'), '');
  assert.notEqual(helpers.positiveNumber('0'), '');
  assert.notEqual(helpers.positiveNumber('10000000000'), '');
  assert.equal(helpers.positiveInteger('900719925474099321'), '');
  assert.notEqual(helpers.positiveInteger('12.5'), '');
  assert.notEqual(helpers.positiveInteger('000000000000000000'), '');
});

test('public error messages do not echo unknown database internals', () => {
  const helpers = loadAppHelpers();
  const message = helpers.humanError({ message: 'syntax error at or near "sensitive_table"' });
  assert.equal(message, 'عملیات انجام نشد. لطفاً اتصال اینترنت را بررسی کنید و دوباره تلاش کنید.');
  assert.match(helpers.humanError({ message: 'duplicate key value violates unique constraint' }), /قبلاً ثبت شده/);
});

test('database hardening migration protects phone format, reports, and RPC search paths', () => {
  const sql = read('supabase/migrations/20261102130000_validation_and_abuse_controls.sql');
  assert.match(sql, /\^\(09\[0-9\]\{9\}\|\[\+\]989\[0-9\]\{9\}\|00989\[0-9\]\{9\}\)\$/);
  assert.match(sql, /add constraint profiles_phone_iran_format_check/);
  assert.match(sql, /create or replace function public\.normalize_profile_phone\(\)/);
  assert.match(sql, /translate\(new\.phone, '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'\)/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /reports_reporter_created_idx/);
  assert.match(sql, /set search_path = pg_catalog, public, auth/);
  const functionBodies = [...sql.matchAll(/create or replace function\s+public\.[\s\S]*?\n\$\$;/gi)].map(match => match[0]);
  for (const body of functionBodies.filter(body => /security definer/i.test(body))) {
    assert.match(body, /set search_path = pg_catalog/i);
  }
  assert.match(sql, /revoke all on function public\.guard_report_insert\(\) from public, anon, authenticated/);
  assert.match(sql, /create or replace function public\.cancel_load\(p_load_id uuid\)/);
  assert.match(sql, /revoke update on table public\.loads from authenticated/);
  assert.match(sql, /grant execute on function public\.cancel_load\(uuid\) to authenticated/);
  assert.match(sql, /for update/);
  const app = read('app.js');
  assert.match(app, /\.rpc\('cancel_load',\{p_load_id:id\}\)/);
  assert.doesNotMatch(app, /\.from\('loads'\)\.update\(\{status:'cancelled'\}\)/);
});

test('public and admin entry pages retain the Persian RTL static shell', () => {
  const pages = [
    ['index.html', 'app.js', 'styles.css'],
    ['admin.html', 'admin.js', 'admin.css']
  ];
  for (const [page, script, stylesheet] of pages) {
    const html = read(page);
    assert.match(html, /<html[^>]+lang="fa"[^>]+dir="rtl"|<html[^>]+dir="rtl"[^>]+lang="fa"/i, page);
    assert.match(html, new RegExp(`(?:src|href)="(?:\\./)?${script.replace('.', '\\.')}`), page);
    assert.match(html, new RegExp(`(?:src|href)="(?:\\./)?${stylesheet.replace('.', '\\.')}`), page);
  }
});

test('browser assets do not contain server or provisioning secrets', () => {
  const browserAssets = ['app.js', 'admin.js', 'index.html', 'admin.html', 'supabase-config.js']
    .map(read)
    .join('\n');
  assert.doesNotMatch(browserAssets, /SUPABASE_DB_PASSWORD|SUPABASE_INITIAL_ADMIN_EMAIL|sb_secret_|postgresql:\/\/postgres\./i);
  assert.doesNotMatch(browserAssets, /service_role\s*[:=]\s*['"]/i);
  const workflow = read('.github/workflows/deploy-supabase-schema.yml');
  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /provision_initial_admin:/);
  assert.match(workflow, /SUPABASE_INITIAL_ADMIN_EMAIL: \$\{\{ secrets\.SUPABASE_INITIAL_ADMIN_EMAIL \}\}/);
});
