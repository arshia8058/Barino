/* بارینو - کلاینت استاتیک GitHub Pages. هیچ کلید محرمانه‌ای در این فایل نیست. */
(() => {
  'use strict';

  const $ = (selector, root = document) => root.querySelector(selector);
  const app = $('#app');
  const main = $('#main-content');
  const topbar = $('#topbar');
  const bottomNav = $('#bottom-nav');
  const modalRoot = $('#modal-root');
  const toastRegion = $('#toast-region');
  const CITY_LIST = ['تهران','کرج','قزوین','قم','سمنان','زنجان','رشت','ساری','گرگان','اردبیل','تبریز','ارومیه','سنندج','همدان','اراک','اصفهان','یزد','شیراز','بوشهر','بندرعباس','کیش','اهواز','خرم‌آباد','کرمانشاه','ایلام','شهرکرد','یاسوج','کرمان','زاهدان','بیرجند','مشهد','بجنورد','اردبیل'];
  const TRUCKS = ['نیسان بار','خاور','تک','جفت','تریلی کفی','تریلی چادری','تریلی یخچالی','تانکر','کمپرسی','بوژی'];
  const CARGO_TYPES = ['عمومی','مصالح ساختمانی','کشاورزی','مواد غذایی','یخچالی','صنعتی','مایعات','اثاثیه','خطرناک'];
  const EMAIL_COOLDOWN_STORAGE_KEY = 'barino.emailCooldownUntil';
  const state = { client: null, session: null, user: null, profile: null, isAdmin: false, route: 'home', authTab: 'login', signupRole: 'driver', pendingEmail: '', emailCooldownUntil: 0, emailCooldownTimer: null, admin: { tab: 'overview', usersPage: 1, loadsPage: 1, userFilters: { search: '', role: '', status: 'all' }, loadFilters: { search: '', status: '' } }, online: navigator.onLine, initialized: false };

  const icons = {
    truck: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 5h11v11H3z"/><path d="M14 8h4l3 3v5h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/></svg>',
    home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m3 11 9-8 9 8v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/><path d="M9 21v-6h6v6"/></svg>',
    list: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
    box: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m21 8-9 5-9-5 9-5z"/><path d="M3 8v8l9 5 9-5V8"/><path d="M12 13v8"/></svg>',
    user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>',
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>',
    chart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 3v18h18"/><path d="m7 16 4-5 3 3 5-7"/></svg>',
    shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10"/><path d="m9 12 2 2 4-4"/></svg>',
    clipboard: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V2h6v2M9 11h6M9 15h4"/></svg>',
    alert: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0"/><path d="M12 9v4M12 17h.01"/></svg>',
    location: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0"/><circle cx="12" cy="10" r="2"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.5c.9.4 1.8.6 2.8.7a2 2 0 0 1 1.8 2.1"/></svg>',
    logout: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10 17l5-5-5-5M15 12H3"/><path d="M21 3v18"/></svg>',
    menu: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg>',
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 11a8 8 0 1 0 2 5.3"/><path d="M20 4v7h-7"/></svg>',
    mail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/><path d="M12 14v3"/></svg>',
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12"/><circle cx="12" cy="12" r="2.5"/></svg>',
    eyeOff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m3 3 18 18"/><path d="M10.6 6.2A10.8 10.8 0 0 1 12 6c6.5 0 10 6 10 6a18.3 18.3 0 0 1-3.1 3.7M6.2 6.2C3.6 8 2 12 2 12s3.5 6 10 6c1.5 0 2.8-.3 4-.8"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>',
    arrow: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>'
  };

  function esc(value) { return String(value ?? '').replace(/[&<>'"]/g, char => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', "'":'&#39;', '"':'&quot;' }[char])); }
  function icon(name) { return icons[name] || ''; }
  function faNumber(value) { return new Intl.NumberFormat('fa-IR').format(Number(value || 0)); }
  function fare(value) { return value === null || value === undefined ? 'توافقی' : `${faNumber(value)} تومان`; }
  function dateFa(value, withTime = false) {
    if (!value) return '—';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return esc(value);
    return new Intl.DateTimeFormat('fa-IR', withTime ? { dateStyle: 'short', timeStyle: 'short' } : { dateStyle: 'medium' }).format(date);
  }
  function humanError(error) {
    const raw = String(error?.message || error || '');
    if (/Invalid login credentials/i.test(raw)) return 'ایمیل یا رمز عبور درست نیست.';
    if (/Email not confirmed|EMAIL_VERIFICATION_REQUIRED/i.test(raw)) return 'ابتدا ایمیل خود را تأیید کنید؛ سپس وارد شوید.';
    if (/code verifier|exchange.*code|invalid.*code|otp.*expired|token.*expired/i.test(raw)) return 'لینک تأیید یا بازیابی معتبر نیست یا منقضی شده است. یک لینک جدید درخواست کنید.';
    if (/EMAIL_CONFIRMATION_NOT_ENFORCED/i.test(raw)) return 'تأیید ایمیل در Supabase فعال نشده است. در Authentication → Sign In / Providers آن را فعال و ذخیره کنید.';
    if (/User already registered/i.test(raw)) return 'اگر قبلاً حساب ساخته‌اید، وارد شوید یا لینک تأیید را دوباره ارسال کنید.';
    if (/rate limit|over_email_send_rate_limit/i.test(raw)) return 'درخواست‌های ایمیل زیاد بوده است؛ چند دقیقه صبر کنید و دوباره تلاش کنید.';
    if (/Password should be at least|weak password/i.test(raw)) return 'رمز عبور انتخاب‌شده با سیاست امنیتی مجاز نیست.';
    if (/duplicate|unique/i.test(raw)) return 'این مورد قبلاً ثبت شده است.';
    if (/network|fetch/i.test(raw)) return 'ارتباط با اینترنت یا سرور برقرار نشد. دوباره تلاش کنید.';
    if (/حساب شما فعال نیست|account.*not.*active|blocked/i.test(raw)) return 'حساب شما فعال نیست یا توسط مدیر مسدود شده است.';
    if (/admin_(dashboard_summary|list_users|get_user_details|set_user_blocked|list_loads|get_load_details|set_load_status)|schema cache/i.test(raw)) return 'امکانات جدید پنل مدیریت هنوز در دیتابیس اعمال نشده‌اند. migration پنل مدیریت را از GitHub Actions اجرا کنید.';
    if (/permission|row-level|policy|not authorized|access denied/i.test(raw)) return 'شما اجازه انجام این عملیات را ندارید.';
    if (/not configured/i.test(raw)) return 'تنظیمات Supabase وارد نشده است.';
    return raw ? `عملیات انجام نشد: ${raw}` : 'عملیات انجام نشد. لطفاً دوباره تلاش کنید.';
  }
  function normalizeDigits(value) { return String(value || '').replace(/[۰-۹]/g, d => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d)).replace(/[٬,]/g, ''); }
  function statusLabel(status) { return ({ published:'منتشرشده', receiving_offers:'در حال دریافت پیشنهاد', agreed:'توافق‌شده', awaiting_pickup:'در انتظار بارگیری', in_transit:'در حال حمل', delivered:'تحویل‌شده', cancelled:'لغوشده', submitted:'ارسال‌شده', accepted:'پذیرفته‌شده', rejected:'ردشده', declined:'مختومه' })[status] || status || '—'; }
  function roleLabel(role) { return role === 'driver' ? 'راننده' : 'صاحب بار'; }
  function isConfigured() { const c = window.BARINO_SUPABASE_CONFIG; return !!(c && /^https:\/\//.test(c.url || '') && c.anonKey && !String(c.url).includes('YOUR_') && !String(c.anonKey).includes('YOUR_')); }
  // مسیر redirect را از URL واقعی مرورگر می‌سازیم تا GitHub Pages زیرشاخهٔ /Barino/ را از دست ندهد.
  function authRedirectUrl(destination = 'auth') {
    const path = window.location.pathname.endsWith('/') ? window.location.pathname : window.location.pathname.slice(0, window.location.pathname.lastIndexOf('/') + 1);
    return `${window.location.origin}${path}#${destination}`;
  }
  // callbackهای PKCE و implicit را خودمان مصرف می‌کنیم؛ این کار در GitHub Pages از از‌دست‌رفتن code جلوگیری می‌کند.
  async function consumeAuthCallback(client) {
    const url = new URL(window.location.href);
    const fragment = new URLSearchParams(window.location.hash.replace(/^#/, ''));
    const intent = window.location.hash.replace(/^#/, '') === 'reset-password' || fragment.get('type') === 'recovery' ? 'recovery' : 'signin';
    const code = url.searchParams.get('code');
    const accessToken = fragment.get('access_token');
    const refreshToken = fragment.get('refresh_token');
    const callbackError = url.searchParams.get('error_description') || fragment.get('error_description');
    if (callbackError) return { error: new Error(callbackError), intent };
    let result = null;
    if (code) result = await client.auth.exchangeCodeForSession(code);
    else if (accessToken && refreshToken) result = await client.auth.setSession({ access_token: accessToken, refresh_token: refreshToken });
    if (!result) return { session: null, intent: null };
    // token و code را از URL پاک می‌کنیم تا در history، اسکرین‌شات و ارجاع‌دهنده باقی نمانند.
    history.replaceState(null, '', `${url.pathname}${url.hash === '#reset-password' ? '#reset-password' : '#auth'}`);
    return { session: result.data?.session || null, error: result.error || null, intent };
  }
  function emailIsConfirmed(user) { return Boolean(user?.email_confirmed_at); }
  function readEmailCooldown() {
    try {
      const until = Number(window.sessionStorage.getItem(EMAIL_COOLDOWN_STORAGE_KEY));
      return Number.isFinite(until) && until > Date.now() ? until : 0;
    } catch (_) { return 0; }
  }
  function clearEmailCooldown() {
    state.emailCooldownUntil = 0;
    window.clearTimeout(state.emailCooldownTimer);
    state.emailCooldownTimer = null;
    try { window.sessionStorage.removeItem(EMAIL_COOLDOWN_STORAGE_KEY); } catch (_) { /* storage ممکن است در حالت خصوصی در دسترس نباشد. */ }
  }
  function emailCooldownSeconds() {
    const seconds = Math.max(0, Math.ceil((state.emailCooldownUntil - Date.now()) / 1000));
    if (!seconds && state.emailCooldownUntil) clearEmailCooldown();
    return seconds;
  }
  function refreshEmailCooldownButton() {
    const seconds = emailCooldownSeconds();
    const button = $('[data-email-cooldown]');
    if (button) {
      button.disabled = seconds > 0;
      button.textContent = seconds ? `ارسال دوباره تا ${faNumber(seconds)} ثانیه دیگر` : button.dataset.resendLabel;
    }
    return seconds;
  }
  function scheduleEmailCooldownRefresh() {
    window.clearTimeout(state.emailCooldownTimer);
    if (!refreshEmailCooldownButton()) return;
    state.emailCooldownTimer = window.setTimeout(scheduleEmailCooldownRefresh, 1000);
  }
  function restoreEmailCooldown() {
    state.emailCooldownUntil = readEmailCooldown();
    if (state.emailCooldownUntil) scheduleEmailCooldownRefresh();
  }
  function beginEmailCooldown(seconds = 60) {
    state.emailCooldownUntil = Date.now() + (Math.max(0, Number(seconds) || 0) * 1000);
    try { window.sessionStorage.setItem(EMAIL_COOLDOWN_STORAGE_KEY, String(state.emailCooldownUntil)); } catch (_) { /* محدودسازی سمت Supabase همچنان معتبر است. */ }
    scheduleEmailCooldownRefresh();
  }
  function resendButton(action, label) {
    const seconds = emailCooldownSeconds();
    return `<button type="button" class="button primary full auth-submit" data-action="${action}" data-email-cooldown data-resend-label="${esc(label)}" ${seconds ? 'disabled' : ''}>${seconds ? `ارسال دوباره تا ${faNumber(seconds)} ثانیه دیگر` : label}</button>`;
  }
  function profileReady() { return !!(state.profile?.display_name && state.profile?.phone && (state.profile.role !== 'driver' || state.profile.truck_type)); }
  function cityOptions() { return CITY_LIST.map(city => `<option value="${esc(city)}"></option>`).join(''); }
  function truckOptions(selected = '') { return `<option value="">انتخاب کنید</option>${TRUCKS.map(x => `<option value="${esc(x)}" ${x === selected ? 'selected' : ''}>${esc(x)}</option>`).join('')}`; }
  function cargoOptions(selected = '') { return `<option value="">انتخاب کنید</option>${CARGO_TYPES.map(x => `<option value="${esc(x)}" ${x === selected ? 'selected' : ''}>${esc(x)}</option>`).join('')}`; }
  function setBusy(button, busy, label) { if (!button) return; button.disabled = busy; button.dataset.original = button.dataset.original || button.innerHTML; button.innerHTML = busy ? 'در حال انجام…' : (button.dataset.original || label); }
  function toast(message, kind = 'info') { const t = document.createElement('div'); t.className = `toast ${kind}`; t.setAttribute('role', 'alert'); t.innerHTML = `<span>${kind === 'success' ? '✓' : kind === 'error' ? '!' : 'i'}</span><span>${esc(message)}</span>`; toastRegion.append(t); window.setTimeout(() => t.remove(), 4200); }
  function networkNotice() { return state.online ? '' : `<div class="offline-bar" role="status">اتصال اینترنت قطع است؛ اطلاعات تازه بارگذاری نمی‌شود.</div>`; }

  function renderShell() {
    const name = state.profile?.display_name || state.user?.email?.split('@')[0] || '';
    const configured = isConfigured();
    topbar.innerHTML = `
      <a class="brand" href="#home" data-route="home" aria-label="خانه بارینو"><span class="brand-mark">${icon('truck')}</span><span>بارینو</span></a>
      <div class="top-actions">
        ${!configured ? '<span class="top-status"><i></i> آماده‌سازی</span>' : state.user ? `<button class="avatar" type="button" data-route="profile" aria-label="پروفایل ${esc(name)}">${esc(name.slice(0,1) || 'ب')}</button>` : state.route === 'auth' ? `<button class="button ghost small" type="button" data-route="home">بازگشت</button>` : `<button class="button ghost small" type="button" data-route="auth">ورود</button>`}
      </div>`;
    if (!configured || !state.user) { bottomNav.innerHTML = ''; return; }
    const isOwner = state.profile?.role === 'cargo_owner';
    const nav = [
      ['home','خانه','home'], ['loads','بارها','list'], [isOwner ? 'create-load' : 'offers', isOwner ? 'ثبت بار' : 'پیشنهادها', isOwner ? 'plus' : 'clipboard'], ['shipments','سفارش‌ها','box'], [state.isAdmin ? 'admin' : 'profile', state.isAdmin ? 'مدیریت' : 'حساب', state.isAdmin ? 'shield' : 'user']
    ];
    bottomNav.innerHTML = nav.map(([route,label,ic]) => `<button type="button" class="nav-item ${state.route === route ? 'active' : ''}" data-route="${route}" aria-label="${label}">${icon(ic)}<span>${label}</span></button>`).join('');
  }

  async function init() {
    restoreEmailCooldown();
    renderShell();
    // در موبایل، زمان‌سنج‌های پس‌زمینه ممکن است متوقف شوند؛ با بازگشت به صفحه، زمان واقعی دوباره محاسبه می‌شود.
    document.addEventListener('visibilitychange', () => { if (!document.hidden) scheduleEmailCooldownRefresh(); });
    window.addEventListener('pageshow', () => { scheduleEmailCooldownRefresh(); });
    window.addEventListener('online', () => { state.online = true; render(); toast('اتصال اینترنت برقرار شد.', 'success'); });
    window.addEventListener('offline', () => { state.online = false; render(); });
    const hashRoute = location.hash.replace(/^#/, '');
    if (hashRoute) state.route = hashRoute.split('/')[0];
    window.addEventListener('hashchange', () => { const route = location.hash.replace(/^#/, '').split('/')[0] || 'home'; navigate(route, false); });
    if (!isConfigured()) { render(); return; }
    try {
      if (!window.supabase?.createClient) throw new Error('کتابخانه Supabase بارگذاری نشد');
      const { url, anonKey } = window.BARINO_SUPABASE_CONFIG;
      state.client = window.supabase.createClient(url, anonKey, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false, flowType: 'pkce' } });
      const callback = await consumeAuthCallback(state.client);
      if (callback.error) throw callback.error;
      const { data, error } = callback.session ? { data: { session: callback.session }, error: null } : await state.client.auth.getSession();
      if (error) throw error;
      if (callback.intent === 'recovery' && data.session) {
        await enterRecoverySession(data.session);
      } else {
        await setSession(data.session);
        if (callback.intent === 'signin' && data.session) toast('ایمیل شما با موفقیت تأیید شد.','success');
      }
      state.client.auth.onAuthStateChange(async (event, session) => {
        if (event === 'PASSWORD_RECOVERY') { await enterRecoverySession(session); return; }
        if (event === 'SIGNED_IN' || event === 'SIGNED_OUT' || event === 'TOKEN_REFRESHED') await setSession(session);
      });
    } catch (error) { toast(humanError(error), 'error'); }
    state.initialized = true;
    render();
  }

  async function setSession(session) {
    // دفاع دوم در کلاینت: نشست ایمیل تأییدنشده هرگز وارد رابط کاربری نمی‌شود.
    // RLS و RPCهای دیتابیس نیز همان شرط را مستقل از JavaScript اعمال می‌کنند.
    if (session?.user && !emailIsConfirmed(session.user)) {
      await state.client?.auth.signOut({ scope: 'local' });
      session = null;
      toast('برای ورود ابتدا ایمیل خود را تأیید کنید.', 'info');
    }
    state.session = session || null;
    state.user = session?.user || null;
    state.profile = null;
    state.isAdmin = false;
    if (state.user && state.client) {
      await loadProfile();
      await checkAdmin();
    }
    if (!state.user && ['create-load','offers','shipments','profile','admin'].includes(state.route)) state.route = 'home';
    renderShell();
    render();
  }
  async function enterRecoverySession(session) {
    if (!session) { state.authTab = 'login'; renderAuth(); return; }
    // نشست بازیابی هم باید همان بررسی ایمیل و بارگذاری پروفایل نشست عادی را داشته باشد.
    if (!emailIsConfirmed(session.user)) { await setSession(session); return; }
    state.session = session;
    state.user = session.user;
    state.profile = null;
    state.isAdmin = false;
    await loadProfile();
    await checkAdmin();
    state.route = 'auth';
    state.authTab = 'recovery';
    renderShell();
    render();
  }
  async function loadProfile() {
    const { data, error } = await state.client.from('profiles').select('*').eq('id', state.user.id).maybeSingle();
    if (error) { toast(humanError(error), 'error'); return; }
    state.profile = data;
  }
  async function checkAdmin() {
    const { data, error } = await state.client.rpc('is_admin');
    if (!error) state.isAdmin = data === true;
  }
  function navigate(route, changeHash = true) {
    const protectedRoutes = ['loads','create-load','offers','shipments','profile','admin'];
    if (protectedRoutes.includes(route) && !state.user) { state.route = 'auth'; state.authTab = 'login'; toast('برای ادامه ابتدا وارد حساب خود شوید.', 'info'); }
    else if (route === 'admin' && !state.isAdmin) { state.route = 'home'; toast('دسترسی به بخش مدیریت مجاز نیست.', 'error'); }
    else if (route === 'create-load' && state.profile?.role !== 'cargo_owner') { state.route = 'home'; toast('ثبت بار فقط برای صاحب بار در دسترس است.', 'error'); }
    else { state.route = route || 'home'; }
    if (changeHash) history.replaceState(null, '', `#${state.route}`);
    renderShell(); render();
    requestAnimationFrame(() => main.focus({ preventScroll: false }));
  }
  function render() {
    renderShell();
    if (!isConfigured()) { renderConfiguration(); return; }
    if (!state.online && !state.user) { renderOffline(); return; }
    if (state.user && !state.profile && state.initialized) { renderProfileMissing(); return; }
    const map = { home: renderHome, auth: renderAuth, loads: renderLoads, 'create-load': renderCreateLoad, offers: renderOffers, shipments: renderShipments, profile: renderProfile, admin: renderAdmin };
    (map[state.route] || renderHome)();
  }
  function renderConfiguration() {
    main.innerHTML = `${networkNotice()}<section class="setup-shell"><section class="setup-hero"><div class="setup-grid" aria-hidden="true"></div><div class="setup-topline"><span class="setup-eyebrow">بارینو / حمل‌ونقل هوشمند</span><span class="setup-state"><i></i> نسخه اولیه آماده است</span></div><div class="setup-content"><div class="setup-copy"><span class="setup-kicker">یک مسیر ساده برای هر بار</span><h1>بار مطمئن،<br><em>مسیر روشن.</em></h1><p>یک تجربه حرفه‌ای برای اتصال صاحبان بار و رانندگان؛ سریع، شفاف و با داده‌های محافظت‌شده.</p><div class="setup-pills"><span>${icon('shield')} حریم خصوصی</span><span>${icon('truck')} برای راننده و صاحب بار</span></div></div><div class="setup-visual" aria-hidden="true"><div class="visual-glow"></div><div class="map-ring ring-one"></div><div class="map-ring ring-two"></div><div class="route-line"><b></b><i></i><b></b></div><div class="truck-orb">${icon('truck')}</div><span class="map-point point-a"></span><span class="map-point point-b"></span></div></div><div class="setup-bottom"><span>سامانه حمل بار ایران</span><span>امنیت داده با Supabase</span></div></section><section class="setup-panel"><div class="panel-heading"><div class="panel-step">۰۱</div><div><span class="panel-kicker">یک مرحله تا فعال‌سازی</span><h2>اتصال امن بارینو</h2></div></div><div class="setup-warning"><span class="warning-icon">${icon('alert')}</span><p><strong>تنظیمات Supabase وارد نشده است.</strong><br>برای فعال‌شدن ورود و داده‌های واقعی، فقط پیکربندی عمومی پروژه را وارد کنید.</p></div><div class="config-file"><span class="file-mark">JS</span><div><strong>supabase-config.js</strong><small>نشانی پروژه و کلید عمومی مرورگر</small></div><span class="file-state">نیازمند تکمیل</span></div><div class="setup-steps"><div class="setup-step"><span>۱</span><p>در Supabase، <strong>Project URL</strong> و <strong>Publishable key</strong> را بردارید.</p></div><div class="setup-step"><span>۲</span><p>این دو مقدار را در فایل <code>supabase-config.js</code> وارد و Commit کنید.</p></div><div class="setup-step"><span>۳</span><p>پس از انتشار، ثبت‌نام، بارها و سفارش‌ها با داده واقعی فعال می‌شوند.</p></div></div><a class="button primary full setup-guide" href="https://github.com/arshia8058/Barino#readme" target="_blank" rel="noopener">راهنمای کامل راه‌اندازی <span>←</span></a><p class="setup-footnote">کلیدهای محرمانه و service_role هرگز در مرورگر قرار نمی‌گیرند.</p></section></section>`;
  }
  function renderOffline() { main.innerHTML = `<section class="empty"><div class="empty-icon">${icon('refresh')}</div><h2>اتصال اینترنت برقرار نیست</h2><p>برای ورود امن و دریافت داده‌های تازه، اتصال خود را بررسی و دوباره تلاش کنید.</p><button type="button" class="button primary" data-action="retry">تلاش دوباره</button></section>`; }
  function renderProfileMissing() { main.innerHTML = `<section class="empty"><div class="empty-icon">${icon('user')}</div><h2>در حال آماده‌سازی پروفایل</h2><p>پروفایل شما پس از ثبت‌نام ساخته می‌شود. اگر بیش از چند ثانیه گذشت، صفحه را تازه کنید.</p><button type="button" class="button primary" data-action="reload-profile">تلاش دوباره</button></section>`; }

  function renderHome() {
    if (!state.user) {
      main.innerHTML = `${networkNotice()}<section class="hero"><span class="badge">بازار حمل‌ونقل هوشمند</span><h1>بار مطمئن، مسیر روشن</h1><p>بارینو صاحبان بار و رانندگان حرفه‌ای را در یک مسیر امن و ساده به هم متصل می‌کند.</p><div class="hero-actions"><button type="button" class="button secondary" data-route="auth">ورود یا ثبت‌نام</button><button type="button" class="button ghost" data-route="loads">مشاهده بارها</button></div></section><section class="section"><div class="section-title"><h2>با بارینو چه می‌کنید؟</h2></div><div class="stats-grid"><article class="stat-card"><div class="stat-icon">${icon('box')}</div><strong class="stat-num">ثبت بار</strong><span class="stat-label">کوتاه و مرحله‌ای</span></article><article class="stat-card"><div class="stat-icon">${icon('truck')}</div><strong class="stat-num">پیشنهاد کرایه</strong><span class="stat-label">شفاف و قابل پیگیری</span></article><article class="stat-card"><div class="stat-icon">${icon('shield')}</div><strong class="stat-num">امنیت داده</strong><span class="stat-label">با RLS سوپابیس</span></article><article class="stat-card"><div class="stat-icon">${icon('clipboard')}</div><strong class="stat-num">پیگیری سفارش</strong><span class="stat-label">از توافق تا تحویل</span></article></div></section><section class="card section"><h2>شروع امن</h2><p class="muted">نقش خود را در زمان ثبت‌نام انتخاب کنید. شماره تماس و نشانی دقیق بار تا زمان مجاز، خصوصی باقی می‌ماند.</p><button class="button primary full" type="button" data-route="auth">ساخت حساب کاربری</button></section>`;
      return;
    }
    if (!profileReady()) { renderProfile(true); return; }
    renderDashboard();
  }
  function renderDashboard() {
    const owner = state.profile.role === 'cargo_owner';
    const title = owner ? `سلام ${esc(state.profile.display_name)}، بار بعدی را ثبت کنید` : `سلام ${esc(state.profile.display_name)}، مسیر بعدی را پیدا کنید`;
    main.innerHTML = `${networkNotice()}<section class="hero"><span class="badge">${owner ? 'پنل صاحب بار' : 'پنل راننده'}</span><h1>${title}</h1><p>${owner ? 'بار خود را ثبت کنید و پیشنهادهای رانندگان را در یک جای امن مقایسه کنید.' : 'بارهای متناسب با کامیون خود را ببینید و پیشنهاد کرایه‌تان را ثبت کنید.'}</p><div class="hero-actions"><button class="button secondary" type="button" data-route="${owner ? 'create-load' : 'loads'}">${owner ? 'ثبت بار جدید' : 'مشاهده بارها'}</button><button class="button ghost" type="button" data-route="${owner ? 'offers' : 'shipments'}">${owner ? 'پیشنهادهای دریافتی' : 'سفارش‌های من'}</button></div></section><section class="section"><div class="section-title"><h2>نمای کلی</h2><button type="button" class="text-link" data-action="refresh-dashboard">به‌روزرسانی</button></div><div class="stats-grid" id="dashboard-stats"><div class="skeleton"></div><div class="skeleton"></div><div class="skeleton"></div><div class="skeleton"></div></div></section><section class="section"><div class="section-title"><h2>${owner ? 'آخرین بارهای شما' : 'بارهای تازه'}</h2><button type="button" class="text-link" data-route="${owner ? 'offers' : 'loads'}">مشاهده همه</button></div><div id="recent-list" class="load-list">${skeletons(2)}</div></section>`;
    loadDashboardData();
  }
  function skeletons(count = 3) { return Array.from({length: count}, () => '<div class="skeleton"></div>').join(''); }
  async function loadDashboardData() {
    if (!state.client || !state.profile) return;
    const statsEl = $('#dashboard-stats'); const recent = $('#recent-list');
    const me = state.user.id; const owner = state.profile.role === 'cargo_owner';
    try {
      let metrics, recentQuery;
      if (owner) {
        metrics = await Promise.all([
          state.client.from('loads').select('*', { count: 'exact', head: true }).eq('owner_id', me),
          state.client.from('loads').select('*', { count: 'exact', head: true }).eq('owner_id', me).in('status', ['published','receiving_offers']),
          state.client.from('freight_offers').select('*', { count: 'exact', head: true }),
          state.client.from('shipments').select('*', { count: 'exact', head: true }).eq('owner_id', me).eq('status','in_transit')
        ]);
        recentQuery = state.client.from('loads').select('*').eq('owner_id', me).order('created_at',{ascending:false}).limit(4);
      } else {
        metrics = await Promise.all([
          state.client.from('loads').select('*', { count: 'exact', head: true }).in('status',['published','receiving_offers']),
          state.client.from('freight_offers').select('*', { count: 'exact', head: true }).eq('driver_id', me).eq('status','submitted'),
          state.client.from('shipments').select('*', { count: 'exact', head: true }).eq('driver_id', me).in('status',['agreed','awaiting_pickup','in_transit']),
          state.client.from('shipments').select('*', { count: 'exact', head: true }).eq('driver_id', me).eq('status','delivered')
        ]);
        recentQuery = state.client.from('loads').select('*').in('status',['published','receiving_offers']).order('created_at',{ascending:false}).limit(4);
      }
      const metricError = metrics.find(x => x.error)?.error; if (metricError) throw metricError;
      const labels = owner ? ['بارهای ثبت‌شده','بارهای فعال','پیشنهادهای دریافتی','در حال حمل'] : ['بارهای فعال','پیشنهادهای ارسال‌شده','سفارش‌های جاری','تکمیل‌شده'];
      if (statsEl) statsEl.innerHTML = metrics.map((x,i) => `<article class="stat-card"><div class="stat-icon">${[icon('box'),icon('clipboard'),icon('truck'),icon('chart')][i]}</div><strong class="stat-num">${faNumber(x.count || 0)}</strong><span class="stat-label">${labels[i]}</span></article>`).join('');
      const { data, error } = await recentQuery; if (error) throw error;
      if (recent) recent.innerHTML = data?.length ? data.map(loadCard).join('') : emptyHTML(owner ? 'هنوز باری ثبت نکرده‌اید' : 'فعلاً بار فعالی برای نمایش نیست', owner ? 'اولین بار را ثبت کنید تا پیشنهادها را دریافت کنید.' : 'برای دریافت بارهای جدید دوباره سر بزنید.', owner ? 'create-load' : 'loads', owner ? 'ثبت بار' : 'جست‌وجوی بار');
    } catch (error) { if (statsEl) statsEl.innerHTML = `<div class="notice danger wide">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; if (recent) recent.innerHTML = ''; }
  }

  function authShell(content) {
    return `${networkNotice()}<section class="auth-page"><aside class="auth-aside"><div class="auth-aside-brand"><span class="auth-aside-mark">${icon('truck')}</span><strong>بارینو</strong></div><div class="auth-aside-copy"><span class="auth-overline">حمل‌ونقل، ساده و امن</span><h1>همه مسیرها،<br><em>یک‌جا.</em></h1><p>حساب شما با احراز هویت واقعی و قواعد دسترسی دقیق محافظت می‌شود.</p></div><div class="auth-trust-list"><span>${icon('shield')} داده‌های خصوصی، فقط برای طرف مجاز</span><span>${icon('check')} ورود و بازیابی رمز امن</span></div><div class="auth-aside-orbit" aria-hidden="true"><i></i><b></b><span>${icon('location')}</span></div></aside><section class="auth-card">${content}</section></section>`;
  }
  function passwordField(id, name, label, autocomplete, placeholder) {
    return `<div class="field auth-field"><label for="${id}">${label} <span class="required">*</span></label><div class="password-control"><input id="${id}" name="${name}" class="input" type="password" autocomplete="${autocomplete}" required minlength="8" placeholder="${placeholder}"><button class="password-toggle" type="button" data-toggle-password="${id}" aria-label="نمایش رمز عبور" aria-pressed="false">${icon('eye')}</button></div><span class="field-error"></span></div>`;
  }
  function renderAuth() {
    if (state.user) { navigate('home'); return; }
    const tab = state.authTab;
    if (tab === 'recovery') { renderNewPassword(); return; }
    if (tab === 'forgot') { renderForgotPassword(); return; }
    if (tab === 'check-email') { renderCheckEmail(); return; }
    if (tab === 'recovery-sent') { renderRecoverySent(); return; }
    const title = tab === 'signup' ? 'ساخت حساب کاربری' : 'خوش آمدید';
    const text = tab === 'signup' ? 'در کمتر از یک دقیقه به بازار حرفه‌ای حمل بار بپیوندید.' : 'با ایمیل و رمز عبور وارد حساب بارینو شوید.';
    const tabs = `<div class="auth-tabs" role="tablist" aria-label="ورود یا ثبت‌نام"><button type="button" class="${tab === 'login' ? 'active' : ''}" data-auth-tab="login">ورود</button><button type="button" class="${tab === 'signup' ? 'active' : ''}" data-auth-tab="signup">ساخت حساب</button></div>`;
    main.innerHTML = authShell(`<div class="auth-card-head"><span class="auth-card-kicker">بارینو</span><h2>${title}</h2><p>${text}</p></div>${tabs}<div class="auth-form-area">${tab === 'signup' ? signupForm() : loginForm()}</div>`);
  }
  function loginForm() {
    return `<form id="login-form" class="form-grid auth-form" novalidate><div class="field auth-field"><label for="login-email">ایمیل <span class="required">*</span></label><div class="field-with-icon">${icon('mail')}<input id="login-email" name="email" class="input" type="email" autocomplete="email" inputmode="email" required placeholder="name@example.com" value="${esc(state.pendingEmail)}"></div><span class="field-error"></span></div>${passwordField('login-password','password','رمز عبور','current-password','رمز عبور خود را وارد کنید')}<div class="auth-form-links"><span>نشست شما روی این دستگاه حفظ می‌شود.</span><button class="text-link" type="button" data-action="forgot-password">فراموشی رمز</button></div><button type="submit" class="button primary full auth-submit">ورود به بارینو <span>←</span></button><p class="auth-legal">ورود فقط با ایمیل و رمز عبور انجام می‌شود؛ ورود پیامکی نمایشی نیست.</p></form>`;
  }
  function signupForm() {
    return `<form id="signup-form" class="form-grid auth-form" novalidate><div class="auth-role-heading"><span>نوع حساب را انتخاب کنید</span><small>بعداً قابل تغییر نیست.</small></div><div class="choice-cards auth-role-cards"><button type="button" class="choice-card ${state.signupRole === 'driver' ? 'selected' : ''}" data-signup-role="driver">${icon('truck')}<strong>راننده</strong><small>مشاهده بار و پیشنهاد کرایه</small></button><button type="button" class="choice-card ${state.signupRole === 'cargo_owner' ? 'selected' : ''}" data-signup-role="cargo_owner">${icon('box')}<strong>صاحب بار</strong><small>ثبت بار و انتخاب راننده</small></button></div><div class="field auth-field"><label for="signup-email">ایمیل <span class="required">*</span></label><div class="field-with-icon">${icon('mail')}<input id="signup-email" name="email" class="input" type="email" autocomplete="email" inputmode="email" required placeholder="name@example.com" value="${esc(state.pendingEmail)}"></div><span class="field-error"></span></div>${passwordField('signup-password','password','رمز عبور','new-password','حداقل ۸ کاراکتر، شامل حرف و عدد')}${passwordField('signup-password-confirmation','password_confirmation','تکرار رمز عبور','new-password','رمز عبور را دوباره وارد کنید')}<div class="auth-password-hint">${icon('shield')} حداقل ۸ کاراکتر و ترکیبی از حرف و عدد انتخاب کنید.</div><button type="submit" class="button primary full auth-submit">ساخت حساب و ارسال ایمیل تأیید <span>←</span></button><p class="auth-legal">نقش مدیر هرگز از این فرم ساخته نمی‌شود و فقط توسط پایگاه داده تعیین می‌گردد.</p></form>`;
  }
  function renderForgotPassword() {
    main.innerHTML = authShell(`<div class="auth-card-head"><button type="button" class="auth-back" data-auth-tab="login">${icon('arrow')} بازگشت به ورود</button><span class="auth-card-kicker">بازیابی امن</span><h2>رمز عبور را بازیابی کنید</h2><p>لینک تغییر رمز را به ایمیل حساب شما می‌فرستیم.</p></div><form id="forgot-password-form" class="form-grid auth-form" novalidate><div class="field auth-field"><label for="forgot-email">ایمیل حساب</label><div class="field-with-icon">${icon('mail')}<input id="forgot-email" name="email" class="input" type="email" autocomplete="email" inputmode="email" required placeholder="name@example.com" value="${esc(state.pendingEmail)}"></div><span class="field-error"></span></div><button type="submit" class="button primary full auth-submit">ارسال لینک بازیابی <span>←</span></button><p class="auth-legal">اگر حسابی با این ایمیل وجود داشته باشد، ایمیل بازیابی ارسال می‌شود.</p></form>`);
  }
  function renderCheckEmail() {
    main.innerHTML = authShell(`<div class="auth-confirm"><div class="auth-confirm-icon">${icon('mail')}</div><span class="auth-card-kicker">یک قدم تا شروع</span><h2>صندوق ایمیل را بررسی کنید</h2><p>لینک تأیید را به <strong dir="ltr">${esc(state.pendingEmail)}</strong> فرستادیم. لینک را باز کنید و سپس وارد بارینو شوید.</p><div class="auth-confirm-tips"><span>${icon('check')} پوشه Spam یا Junk را هم بررسی کنید.</span><span>${icon('check')} لینک فقط برای همین آدرس ایمیل معتبر است.</span></div>${resendButton('resend-confirmation','ارسال دوباره لینک تأیید')}<button type="button" class="button ghost full" data-auth-tab="login">بازگشت به ورود</button><button type="button" class="text-link auth-change-email" data-auth-tab="signup">ویرایش آدرس ایمیل</button></div>`);
  }
  function renderRecoverySent() {
    main.innerHTML = authShell(`<div class="auth-confirm"><div class="auth-confirm-icon">${icon('lock')}</div><span class="auth-card-kicker">لینک بازیابی ارسال شد</span><h2>رمز خود را بازنشانی کنید</h2><p>اگر حسابی با <strong dir="ltr">${esc(state.pendingEmail)}</strong> وجود داشته باشد، لینک امن تغییر رمز به آن ارسال شده است.</p><div class="auth-confirm-tips"><span>${icon('check')} پوشه Spam یا Junk را هم بررسی کنید.</span><span>${icon('check')} فقط از آخرین لینک ایمیل استفاده کنید.</span></div>${resendButton('resend-recovery','ارسال دوباره لینک بازیابی')}<button type="button" class="button ghost full" data-auth-tab="login">بازگشت به ورود</button></div>`);
  }
  function renderNewPassword() {
    main.innerHTML = authShell(`<div class="auth-card-head"><span class="auth-card-kicker">بازیابی امن</span><h2>رمز عبور جدید</h2><p>رمزی تازه انتخاب کنید که قبلاً استفاده نکرده‌اید.</p></div><form id="new-password-form" class="form-grid auth-form" novalidate>${passwordField('new-password','password','رمز عبور جدید','new-password','حداقل ۸ کاراکتر، شامل حرف و عدد')}${passwordField('new-password-confirmation','password_confirmation','تکرار رمز عبور','new-password','رمز عبور را دوباره وارد کنید')}<div class="auth-password-hint">${icon('shield')} از ترکیب حرف، عدد و یک رمز منحصربه‌فرد استفاده کنید.</div><button type="submit" class="button primary full auth-submit">ثبت رمز جدید <span>←</span></button></form>`);
  }

  function renderLoads() {
    main.innerHTML = `${networkNotice()}<div class="page-head"><div><h1>بارهای فعال</h1><p class="subtitle">فیلترها مستقیماً روی داده‌های مجاز پایگاه داده اعمال می‌شوند.</p></div><button class="icon-btn" type="button" data-action="refresh-loads" aria-label="تازه‌سازی">${icon('refresh')}</button></div><section class="card filter-card"><form id="load-filter-form" class="filters"><div class="field"><label for="filter-origin">مبدأ</label><input id="filter-origin" class="input" name="origin" list="iran-cities" placeholder="مثلاً تهران"></div><div class="field"><label for="filter-destination">مقصد</label><input id="filter-destination" class="input" name="destination" list="iran-cities" placeholder="مثلاً مشهد"></div><div class="field"><label for="filter-cargo">نوع بار</label><select id="filter-cargo" name="cargo_type">${cargoOptions()}</select></div><div class="field"><label for="filter-truck">نوع کامیون</label><select id="filter-truck" name="truck_type">${truckOptions()}</select></div><div class="field"><label for="filter-min-fare">حداقل کرایه</label><div class="input-group"><input id="filter-min-fare" class="input" name="min_fare" inputmode="numeric" placeholder="۰"><span class="unit">تومان</span></div></div><div class="field"><label for="filter-max-fare">حداکثر کرایه</label><div class="input-group"><input id="filter-max-fare" class="input" name="max_fare" inputmode="numeric" placeholder="بدون سقف"><span class="unit">تومان</span></div></div><div class="wide action-row"><button class="button secondary full" type="submit">${icon('search')} جست‌وجو و اعمال فیلتر</button></div></form><datalist id="iran-cities">${cityOptions()}</datalist></section><section><div id="loads-result" class="load-list two-col">${skeletons()}</div></section>`;
    loadLoads();
  }
  async function loadLoads(filters = {}) {
    const result = $('#loads-result'); if (!result || !state.client) return;
    result.innerHTML = skeletons(3);
    try {
      let query = state.client.from('loads').select('*').in('status',['published','receiving_offers']).order('created_at',{ascending:false}).limit(60);
      if (filters.origin) query = query.ilike('origin_city', `%${filters.origin.trim()}%`);
      if (filters.destination) query = query.ilike('destination_city', `%${filters.destination.trim()}%`);
      if (filters.cargo_type) query = query.eq('cargo_type', filters.cargo_type);
      if (filters.truck_type) query = query.eq('required_truck_type', filters.truck_type);
      if (filters.min_fare) query = query.gte('proposed_fare', filters.min_fare);
      if (filters.max_fare) query = query.lte('proposed_fare', filters.max_fare);
      const { data, error } = await query; if (error) throw error;
      result.innerHTML = data?.length ? data.map(loadCard).join('') : emptyHTML('باری با این شرایط پیدا نشد', 'فیلترها را تغییر دهید یا کمی بعد دوباره بررسی کنید.', null, null);
    } catch (error) { result.innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }
  function loadCard(load) { const canOffer = state.profile?.role === 'driver' && load.owner_id !== state.user?.id && profileReady(); return `<article class="load-card"><div class="load-top"><strong class="load-title">${esc(load.title)}</strong><span class="status ${esc(load.status)}">${statusLabel(load.status)}</span></div><div class="route"><span>${esc(load.origin_city)}</span><span class="arrow">←</span><span>${esc(load.destination_city)}</span></div><div class="meta-row"><span>${esc(load.cargo_type)}</span><span>${faNumber(load.weight_value)} ${esc(load.weight_unit)}</span><span>${esc(load.required_truck_type)}</span></div><div class="load-foot"><div><div class="price">${fare(load.proposed_fare)}</div><span class="time">بارگیری: ${dateFa(load.loading_date)} · ثبت: ${dateFa(load.created_at)}</span></div><div class="action-row"><button type="button" class="button ghost small" data-load-detail="${esc(load.id)}">جزئیات</button>${canOffer ? `<button type="button" class="button primary small" data-open-offer="${esc(load.id)}">پیشنهاد</button>` : ''}</div></div></article>`; }
  function emptyHTML(title, text, route, label) { return `<section class="empty"><div class="empty-icon">${icon('box')}</div><h2>${esc(title)}</h2><p>${esc(text)}</p>${route ? `<button class="button primary" type="button" data-route="${route}">${esc(label)}</button>` : ''}</section>`; }

  function renderCreateLoad() {
    main.innerHTML = `${networkNotice()}<div class="page-head"><div><h1>ثبت بار جدید</h1><p class="subtitle">اطلاعات دقیق نشانی فقط بعد از توافق در دسترس طرف مجاز قرار می‌گیرد.</p></div></div><form id="create-load-form" class="form-grid" novalidate><section class="card"><span class="kicker">۱. مشخصات بار</span><div class="form-grid" style="margin-top:12px"><div class="field"><label for="load-title">عنوان بار <span class="required">*</span></label><input id="load-title" class="input" name="title" maxlength="120" required placeholder="مثلاً حمل کاشی به مشهد"><span class="field-error"></span></div><div class="field"><label for="cargo-description">نام یا توضیح کالا</label><textarea id="cargo-description" name="cargo_description" maxlength="1500" placeholder="مثلاً کاشی سرامیکی، بسته‌بندی شده"></textarea></div><div class="form-grid two"><div class="field"><label for="cargo-type">نوع بار <span class="required">*</span></label><select id="cargo-type" name="cargo_type" required>${cargoOptions()}</select><span class="field-error"></span></div><div class="field"><label for="required-truck">نوع کامیون <span class="required">*</span></label><select id="required-truck" name="required_truck_type" required>${truckOptions()}</select><span class="field-error"></span></div></div><div class="form-grid two"><div class="field"><label for="weight-value">وزن <span class="required">*</span></label><input id="weight-value" class="input" name="weight_value" inputmode="decimal" required placeholder="مثلاً ۱۵"><span class="field-error"></span></div><div class="field"><label for="weight-unit">واحد وزن</label><select id="weight-unit" name="weight_unit"><option value="تن">تن</option><option value="کیلوگرم">کیلوگرم</option></select></div></div></div></section><section class="card"><span class="kicker">۲. مسیر و زمان</span><div class="form-grid" style="margin-top:12px"><div class="form-grid two"><div class="field"><label for="origin-city">شهر مبدأ <span class="required">*</span></label><input id="origin-city" class="input" name="origin_city" list="iran-cities" required placeholder="شهر بارگیری"><span class="field-error"></span></div><div class="field"><label for="destination-city">شهر مقصد <span class="required">*</span></label><input id="destination-city" class="input" name="destination_city" list="iran-cities" required placeholder="شهر تخلیه"><span class="field-error"></span></div></div><div class="field"><label for="pickup-address">نشانی یا محل بارگیری <span class="required">*</span></label><textarea id="pickup-address" name="pickup_address" required maxlength="1000" placeholder="این اطلاعات عمومی نمی‌شود."></textarea><span class="field-error"></span></div><div class="field"><label for="delivery-address">نشانی یا محل تخلیه <span class="required">*</span></label><textarea id="delivery-address" name="delivery_address" required maxlength="1000" placeholder="این اطلاعات عمومی نمی‌شود."></textarea><span class="field-error"></span></div><div class="field"><label for="loading-date">تاریخ بارگیری <span class="required">*</span></label><input id="loading-date" class="input" name="loading_date" type="date" required min="${new Date().toISOString().slice(0,10)}"><span class="field-error"></span></div></div></section><section class="card"><span class="kicker">۳. کرایه و توضیحات</span><div class="form-grid" style="margin-top:12px"><div class="field"><label for="proposed-fare">کرایه پیشنهادی (تومان) <span class="required">*</span></label><div class="input-group"><input id="proposed-fare" class="input" name="proposed_fare" inputmode="numeric" required placeholder="مثلاً ۱۵۰۰۰۰۰۰"><span class="unit">تومان</span></div><span class="field-error"></span></div><div class="field"><label for="load-notes">توضیحات تکمیلی</label><textarea id="load-notes" name="notes" maxlength="2000" placeholder="شرایط بارگیری یا نکته‌های مهم"></textarea></div></div><div class="notice info" style="margin-top:12px">${icon('shield')}<p>پس از انتشار، شهرها و ویژگی‌های عمومی بار دیده می‌شود؛ نشانی دقیق و شماره تماس بر اساس سیاست دسترسی خصوصی می‌ماند.</p></div><div class="form-actions"><button type="button" class="button ghost" data-route="home">انصراف</button><button type="submit" class="button primary">ثبت و انتشار بار</button></div></section><datalist id="iran-cities">${cityOptions()}</datalist></form>`;
  }

  function renderOffers() {
    const owner = state.profile?.role === 'cargo_owner';
    main.innerHTML = `${networkNotice()}<div class="page-head"><div><h1>${owner ? 'پیشنهادهای رانندگان' : 'پیشنهادهای من'}</h1><p class="subtitle">${owner ? 'پیشنهادها را مقایسه و فقط یک مورد را با اطمینان بپذیرید.' : 'وضعیت پیشنهادهای ثبت‌شده را اینجا پیگیری کنید.'}</p></div><button class="icon-btn" type="button" data-action="refresh-offers" aria-label="تازه‌سازی">${icon('refresh')}</button></div><div id="offers-result" class="load-list">${skeletons()}</div>`;
    loadOffers();
  }
  async function loadOffers() {
    const result = $('#offers-result'); if (!result) return;
    try {
      let query = state.client.from('freight_offers').select('*, loads(id,title,origin_city,destination_city,status,proposed_fare)').order('created_at',{ascending:false});
      if (state.profile.role === 'driver') query = query.eq('driver_id',state.user.id);
      const {data, error} = await query; if (error) throw error;
      let cards = [];
      if (state.profile.role === 'cargo_owner' && data?.length) {
        const drivers = [...new Set(data.map(x => x.driver_id))];
        const { data: people } = await state.client.from('driver_public_profiles').select('*').in('id',drivers);
        const names = new Map((people || []).map(x => [x.id,x]));
        cards = data.map(item => offerCard(item, names.get(item.driver_id)));
      } else cards = (data || []).map(item => offerCard(item));
      result.innerHTML = cards.length ? cards.join('') : emptyHTML(state.profile.role === 'driver' ? 'هنوز پیشنهادی نداده‌اید' : 'هنوز پیشنهادی دریافت نکرده‌اید', state.profile.role === 'driver' ? 'بار مناسب را پیدا کنید و پیشنهاد کرایه ثبت کنید.' : 'پس از ثبت بار، پیشنهادهای رانندگان در این بخش نمایش داده می‌شود.', state.profile.role === 'driver' ? 'loads' : 'create-load', state.profile.role === 'driver' ? 'مشاهده بارها' : 'ثبت بار');
    } catch (error) { result.innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }
  function offerCard(offer, driver) { const load = offer.loads || {}; const owner = state.profile?.role === 'cargo_owner'; return `<article class="load-card"><div class="offer-top"><div><strong>${esc(load.title || 'بار')}</strong><p class="muted" style="margin:2px 0 0">${esc(load.origin_city || '—')} ← ${esc(load.destination_city || '—')}</p></div><span class="status ${esc(offer.status)}">${statusLabel(offer.status)}</span></div><div class="divider"></div>${owner ? `<div class="meta-row"><span>راننده: ${esc(driver?.display_name || 'راننده بارینو')}</span><span>خودرو: ${esc(driver?.truck_type || 'ثبت نشده')}</span></div>` : `<div class="meta-row"><span>کرایه پیشنهادی صاحب بار: ${fare(load.proposed_fare)}</span></div>`}<div class="load-foot"><div><div class="price">پیشنهاد شما: ${fare(offer.offered_fare)}</div><span class="time">ثبت: ${dateFa(offer.created_at, true)}</span></div>${owner && offer.status === 'submitted' && ['published','receiving_offers'].includes(load.status) ? `<button type="button" class="button primary small" data-accept-offer="${esc(offer.id)}">پذیرش پیشنهاد</button>` : ''}</div>${offer.note ? `<p class="muted" style="margin:11px 0 0">${esc(offer.note)}</p>` : ''}</article>`; }

  function renderShipments() {
    main.innerHTML = `${networkNotice()}<div class="page-head"><div><h1>سفارش‌های حمل</h1><p class="subtitle">وضعیت حمل را مرحله‌به‌مرحله و با تاریخچه معتبر پیگیری کنید.</p></div><button class="icon-btn" type="button" data-action="refresh-shipments" aria-label="تازه‌سازی">${icon('refresh')}</button></div><div id="shipments-result" class="load-list">${skeletons()}</div>`;
    loadShipments();
  }
  async function loadShipments() {
    const result = $('#shipments-result'); if (!result) return;
    try {
      const {data, error} = await state.client.from('shipments').select('*, loads(id,title,origin_city,destination_city,weight_value,weight_unit,required_truck_type), freight_offers(offered_fare)').order('created_at',{ascending:false});
      if (error) throw error;
      result.innerHTML = data?.length ? data.map(shipmentCard).join('') : emptyHTML('هنوز سفارشی ندارید','پس از پذیرش یک پیشنهاد، سفارش حمل در این بخش ساخته می‌شود.','loads','مشاهده بارها');
    } catch (error) { result.innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }
  function nextAction(shipment) {
    const role = state.profile?.role;
    if (role === 'cargo_owner' && shipment.status === 'agreed') return ['awaiting_pickup','آماده بارگیری'];
    if (role === 'driver' && shipment.status === 'awaiting_pickup') return ['in_transit','شروع حمل'];
    if (role === 'driver' && shipment.status === 'in_transit') return ['delivered','ثبت تحویل'];
    return null;
  }
  function shipmentCard(s) { const load = s.loads || {}; const action = nextAction(s); return `<article class="load-card"><div class="load-top"><strong class="load-title">${esc(load.title || 'سفارش حمل')}</strong><span class="status ${esc(s.status)}">${statusLabel(s.status)}</span></div><div class="route"><span>${esc(load.origin_city || '—')}</span><span class="arrow">←</span><span>${esc(load.destination_city || '—')}</span></div><div class="meta-row"><span>${faNumber(load.weight_value)} ${esc(load.weight_unit || '')}</span><span>کرایه نهایی: ${fare(s.agreed_fare || s.freight_offers?.offered_fare)}</span></div><div class="load-foot"><span class="time">ایجاد سفارش: ${dateFa(s.created_at)}</span><div class="action-row"><button class="button ghost small" type="button" data-shipment-detail="${esc(s.id)}">پیگیری</button>${action ? `<button class="button primary small" type="button" data-shipment-status="${esc(s.id)}" data-next-status="${action[0]}">${action[1]}</button>` : ''}</div></div></article>`; }

  function renderProfile(forceComplete = false) {
    const p = state.profile || {}; const driver = p.role === 'driver';
    main.innerHTML = `${networkNotice()}<div class="page-head"><div><h1>${forceComplete ? 'تکمیل پروفایل' : 'حساب کاربری'}</h1><p class="subtitle">${forceComplete ? 'برای استفاده از امکانات، اطلاعات ضروری را کامل کنید.' : 'اطلاعات تماس و مشخصات خودرو را مدیریت کنید.'}</p></div></div>${!profileReady() ? `<div class="notice warning">${icon('alert')}<p>تا تکمیل نام، شماره تماس${driver ? ' و نوع کامیون' : ''}، عملیات اصلی حساب فعال نمی‌شود.</p></div>` : ''}<form id="profile-form" class="form-grid" novalidate><section class="card"><div class="profile-summary"><div class="avatar">${esc((p.display_name || state.user?.email || 'ب').slice(0,1))}</div><div><h2>${esc(p.display_name || 'کاربر بارینو')}</h2><p class="muted">${roleLabel(p.role)} · ${esc(state.user?.email || '')}</p></div></div><div class="divider"></div><div class="form-grid"><div class="field"><label for="display-name">نام و نام خانوادگی <span class="required">*</span></label><input id="display-name" class="input" name="display_name" maxlength="100" required value="${esc(p.display_name || '')}" placeholder="نام کامل"><span class="field-error"></span></div><div class="field"><label for="phone">شماره موبایل ایران <span class="required">*</span></label><input id="phone" class="input" name="phone" inputmode="tel" autocomplete="tel" required value="${esc(p.phone || '')}" placeholder="۰۹۱۲۱۲۳۴۵۶۷"><small>برای طرف سفارش، فقط بعد از توافق قابل مشاهده است.</small><span class="field-error"></span></div><div class="field"><label for="profile-city">شهر محل فعالیت</label><input id="profile-city" class="input" name="city" list="iran-cities" value="${esc(p.city || '')}" placeholder="مثلاً تهران"></div></div></section>${driver ? `<section class="card"><span class="kicker">مشخصات کامیون</span><div class="form-grid" style="margin-top:12px"><div class="field"><label for="profile-truck">نوع کامیون <span class="required">*</span></label><select id="profile-truck" name="truck_type" required>${truckOptions(p.truck_type)}</select><span class="field-error"></span></div><div class="form-grid two"><div class="field"><label for="truck-model">مدل یا برند</label><input id="truck-model" class="input" name="truck_model" maxlength="100" value="${esc(p.truck_model || '')}" placeholder="مثلاً ولوو FH"></div><div class="field"><label for="plate-number">پلاک</label><input id="plate-number" class="input" name="plate_number" maxlength="30" value="${esc(p.plate_number || '')}" placeholder="خصوصی"></div></div></div></section>` : ''}<div class="form-actions"><button type="submit" class="button primary">ذخیره اطلاعات</button></div></form>${!forceComplete ? `<section class="card section"><h2>امنیت حساب</h2><p class="muted">برای خروج از حساب فقط روی دستگاه شخصی اقدام کنید.</p><div class="action-row"><button type="button" class="button ghost" data-action="forgot-password">تغییر رمز عبور</button><button type="button" class="button danger" data-action="signout">${icon('logout')} خروج از حساب</button></div></section><section class="card section"><h2>گزارش مشکل</h2><p class="muted">در صورت تخلف یا شکایت مرتبط با سفارش، گزارش را برای بررسی مدیر سامانه ثبت کنید.</p><button type="button" class="button secondary" data-open-report="">ثبت گزارش</button></section>` : ''}<datalist id="iran-cities">${cityOptions()}</datalist>`;
  }

  function renderAdmin() {
    const tabs = [
      ['overview','داشبورد','chart'], ['users','کاربران','user'], ['loads','بارها','box'],
      ['shipments','سفارش‌ها','clipboard'], ['reports','گزارش‌ها','alert'], ['settings','تنظیمات','shield']
    ];
    main.innerHTML = `${networkNotice()}<div class="page-head admin-page-head"><div><span class="kicker">مدیریت امن</span><h1>مرکز مدیریت سامانه</h1><p class="subtitle">داده‌ها و عملیات حساس در هر درخواست توسط Supabase بررسی می‌شوند.</p></div><span class="badge">${icon('shield')} مدیر تأییدشده</span></div><section class="admin-layout"><aside class="admin-sidebar" aria-label="بخش‌های مدیریت">${tabs.map(([id,label,ic]) => `<button type="button" class="admin-tab ${state.admin.tab === id ? 'active' : ''}" data-admin-tab="${id}">${icon(ic)}<span>${label}</span></button>`).join('')}</aside><section class="admin-content"><div id="admin-result" aria-live="polite">${skeletons(4)}</div></section></section>`;
    loadAdmin(state.admin.tab);
  }

  function adminPagination(kind, page, total, pageSize = 15) {
    const pages = Math.max(1, Math.ceil(Number(total || 0) / pageSize));
    if (!total) return '';
    const label = `صفحه ${faNumber(page)} از ${faNumber(pages)} · ${faNumber(total)} مورد`;
    return `<div class="admin-pagination"><button type="button" class="button ghost small" data-admin-page-kind="${kind}" data-admin-page="${page - 1}" ${page <= 1 ? 'disabled' : ''}>قبلی</button><span>${label}</span><button type="button" class="button ghost small" data-admin-page-kind="${kind}" data-admin-page="${page + 1}" ${page >= pages ? 'disabled' : ''}>بعدی</button></div>`;
  }

  function adminActivityIcon(kind) { return ({ user_created: icon('user'), load_created: icon('box'), shipment_status: icon('truck'), report_created: icon('alert'), user_blocked: icon('lock'), user_unblocked: icon('check'), load_status_changed: icon('refresh') })[kind] || icon('clipboard'); }
  function adminLoadStatusOptions(selected, hasShipment) {
    const statuses = hasShipment ? ['agreed','awaiting_pickup','in_transit','delivered','cancelled'] : ['published','receiving_offers','cancelled'];
    return statuses.map(status => `<option value="${status}" ${status === selected ? 'selected' : ''}>${statusLabel(status)}</option>`).join('');
  }

  function renderAdminOverview(data) {
    const metrics = data?.metrics || {};
    const cards = [
      ['total_users','کاربر',icon('user')], ['drivers','راننده',icon('truck')], ['cargo_owners','صاحب بار',icon('box')], ['blocked_users','حساب مسدود',icon('lock')],
      ['total_loads','بار ثبت‌شده',icon('clipboard')], ['active_loads','بار فعال',icon('refresh')], ['active_shipments','سفارش جاری',icon('truck')], ['open_reports','گزارش باز',icon('alert')]
    ];
    const activity = Array.isArray(data?.recent_activity) ? data.recent_activity : [];
    return `<div class="admin-metrics">${cards.map(([key,label,ic]) => `<article class="stat-card"><div class="stat-icon">${ic}</div><strong class="stat-num">${faNumber(metrics[key] || 0)}</strong><span class="stat-label">${label}</span></article>`).join('')}</div><section class="card section"><div class="section-title"><div><span class="kicker">از دیتابیس واقعی</span><h2>آخرین فعالیت‌ها</h2></div><button type="button" class="text-link" data-admin-tab="overview">به‌روزرسانی</button></div>${activity.length ? `<div class="admin-activity">${activity.map(item => `<article class="admin-activity-item"><span class="activity-icon">${adminActivityIcon(item.kind)}</span><div><strong>${esc(item.title || 'فعالیت سامانه')}</strong><p>${esc(item.detail || '')}</p><time>${dateFa(item.created_at, true)}</time></div></article>`).join('')}</div>` : emptyHTML('فعالیتی برای نمایش نیست','پس از ثبت کاربر، بار، گزارش یا اقدام مدیریتی، رویدادها اینجا نشان داده می‌شوند.',null,null)}</section><section class="notice info section">${icon('shield')}<p>آمار و فعالیت‌ها از RPC محافظت‌شده خوانده می‌شوند؛ حساب مسدود یا کاربر عادی حتی با دست‌کاری رابط به این داده‌ها دسترسی ندارد.</p></section>`;
  }

  function renderAdminUsers(data, filters, page) {
    const users = Array.isArray(data) ? data : [];
    const total = Number(users[0]?.total_count || 0);
    return `<section class="admin-toolbar card"><div><span class="kicker">مدیریت کاربران</span><h2>کاربران و وضعیت حساب</h2><p class="muted">جست‌وجوی ایمیل فقط در RPC محافظت‌شده مدیر انجام می‌شود.</p></div><form id="admin-users-filter" class="admin-filter-form" novalidate><input class="input" name="search" maxlength="100" value="${esc(filters.search)}" placeholder="نام، ایمیل یا موبایل"><select name="role"><option value="">همه نقش‌ها</option><option value="driver" ${filters.role === 'driver' ? 'selected' : ''}>راننده</option><option value="cargo_owner" ${filters.role === 'cargo_owner' ? 'selected' : ''}>صاحب بار</option></select><select name="status"><option value="all" ${filters.status === 'all' ? 'selected' : ''}>همه وضعیت‌ها</option><option value="active" ${filters.status === 'active' ? 'selected' : ''}>فعال</option><option value="blocked" ${filters.status === 'blocked' ? 'selected' : ''}>مسدود</option></select><button type="submit" class="button secondary">${icon('search')} جست‌وجو</button></form></section>${users.length ? `<div class="table-list admin-list">${users.map(user => `<article class="table-row admin-row"><div class="admin-row-main"><div class="admin-user-mark">${esc((user.display_name || user.email || 'ب').slice(0,1))}</div><div><strong>${esc(user.display_name || 'پروفایل تکمیل نشده')}</strong><p dir="ltr">${esc(user.email || '—')}</p><div class="meta-row"><span>${roleLabel(user.role)}</span><span>${esc(user.city || 'بدون شهر')}</span><span>${faNumber(user.load_count)} بار</span>${user.role === 'driver' ? `<span>${faNumber(user.offer_count)} پیشنهاد</span>` : ''}</div></div></div><div class="admin-row-actions"><span class="status ${user.is_blocked ? 'cancelled' : 'delivered'}">${user.is_blocked ? 'مسدود' : 'فعال'}</span><button type="button" class="button ghost small" data-admin-user-detail="${esc(user.id)}">جزئیات</button><button type="button" class="button ${user.is_blocked ? 'secondary' : 'danger'} small" data-admin-user-block="${esc(user.id)}" data-current-blocked="${user.is_blocked ? '1' : '0'}" ${user.id === state.user?.id ? 'disabled title="حساب فعلی را نمی‌توان مسدود کرد"' : ''}>${user.is_blocked ? 'فعال‌سازی' : 'مسدودسازی'}</button></div></article>`).join('')}</div>${adminPagination('users', page, total)}` : emptyHTML('کاربری با این فیلتر پیدا نشد','عبارت جست‌وجو یا فیلترها را تغییر دهید.',null,null)}`;
  }

  function renderAdminLoads(data, filters, page) {
    const loads = Array.isArray(data) ? data : [];
    const total = Number(loads[0]?.total_count || 0);
    return `<section class="admin-toolbar card"><div><span class="kicker">مدیریت بارها</span><h2>همه بارهای ثبت‌شده</h2><p class="muted">حذف فیزیکی بار انجام نمی‌شود؛ بار نامعتبر به‌صورت امن غیرفعال می‌شود.</p></div><form id="admin-loads-filter" class="admin-filter-form" novalidate><input class="input" name="search" maxlength="100" value="${esc(filters.search)}" placeholder="عنوان، مسیر، نام یا ایمیل صاحب بار"><select name="status"><option value="">همه وضعیت‌ها</option>${['published','receiving_offers','agreed','awaiting_pickup','in_transit','delivered','cancelled'].map(status => `<option value="${status}" ${filters.status === status ? 'selected' : ''}>${statusLabel(status)}</option>`).join('')}</select><button type="submit" class="button secondary">${icon('search')} جست‌وجو</button></form></section>${loads.length ? `<div class="table-list admin-list">${loads.map(load => `<article class="table-row admin-row"><div class="admin-row-main"><div class="admin-load-mark">${icon('box')}</div><div><strong>${esc(load.title)}</strong><p>${esc(load.origin_city)} ← ${esc(load.destination_city)} · ${fare(load.proposed_fare)}</p><div class="meta-row"><span>صاحب بار: ${esc(load.owner_name || 'تکمیل نشده')}</span><span dir="ltr">${esc(load.owner_email || '')}</span><span>${faNumber(load.offer_count)} پیشنهاد</span></div></div></div><div class="admin-row-actions"><span class="status ${esc(load.status)}">${statusLabel(load.status)}</span><button type="button" class="button ghost small" data-admin-load-detail="${esc(load.id)}">جزئیات</button>${load.status !== 'cancelled' ? `<button type="button" class="button danger small" data-admin-load-deactivate="${esc(load.id)}">غیرفعال‌سازی</button>` : ''}</div></article>`).join('')}</div>${adminPagination('loads', page, total)}` : emptyHTML('باری با این فیلتر پیدا نشد','عنوان، مسیر یا وضعیت را تغییر دهید.',null,null)}`;
  }

  function renderAdminSettings() {
    return `<section class="card admin-settings"><span class="kicker">تنظیمات و مرز دسترسی</span><h2>حساب مدیریت</h2><div class="detail-grid"><div class="detail-cell"><span>حساب واردشده</span><strong dir="ltr">${esc(state.user?.email || '—')}</strong></div><div class="detail-cell"><span>وضعیت بررسی</span><strong>مدیر فعال و تأییدشده</strong></div></div><div class="notice info section">${icon('shield')}<p>این پنل امکان ساخت مدیر جدید، تغییر نقش کاربر یا نمایش رازهای Supabase را ندارد. مدیر فقط با درج مورد اعتماد در جدول خصوصی <code>app_admins</code> تعیین می‌شود.</p></div><div class="notice warning section">${icon('alert')}<p>مسدودسازی کاربر و تغییر وضعیت بار، علاوه بر تأیید نهایی در رابط، در RPC سمت دیتابیس با بررسی <code>is_admin()</code> و <code>is_active_user()</code> اعتبارسنجی می‌شوند.</p></div></section>`;
  }

  async function loadAdmin(tab = state.admin.tab, options = {}) {
    if (!state.isAdmin) return;
    state.admin.tab = tab;
    document.querySelectorAll('[data-admin-tab]').forEach(button => button.classList.toggle('active', button.dataset.adminTab === tab));
    const target = $('#admin-result'); if (!target) return;
    target.innerHTML = skeletons(4);
    try {
      if (tab === 'overview') {
        const { data, error } = await state.client.rpc('admin_dashboard_summary'); if (error) throw error;
        target.innerHTML = renderAdminOverview(data);
      } else if (tab === 'users') {
        const filters = options.filters || state.admin.userFilters;
        const page = Number(options.page || state.admin.usersPage || 1);
        state.admin.userFilters = filters; state.admin.usersPage = page;
        const { data, error } = await state.client.rpc('admin_list_users', { p_search: filters.search || null, p_role: filters.role || null, p_status: filters.status || 'all', p_page: page, p_page_size: 15 }); if (error) throw error;
        target.innerHTML = renderAdminUsers(data, filters, page);
      } else if (tab === 'loads') {
        const filters = options.filters || state.admin.loadFilters;
        const page = Number(options.page || state.admin.loadsPage || 1);
        state.admin.loadFilters = filters; state.admin.loadsPage = page;
        const { data, error } = await state.client.rpc('admin_list_loads', { p_search: filters.search || null, p_status: filters.status || null, p_page: page, p_page_size: 15 }); if (error) throw error;
        target.innerHTML = renderAdminLoads(data, filters, page);
      } else if (tab === 'shipments') {
        const { data, error } = await state.client.from('shipments').select('*,loads(title,origin_city,destination_city)').order('created_at',{ascending:false}).limit(80); if (error) throw error;
        target.innerHTML = adminList(data, x => `<div class="table-row"><div><strong>${esc(x.loads?.title || 'سفارش')}</strong><p>${esc(x.loads?.origin_city||'—')} ← ${esc(x.loads?.destination_city||'—')} · ${dateFa(x.created_at)}</p></div><span class="status ${esc(x.status)}">${statusLabel(x.status)}</span></div>`, 'سفارشی برای نمایش نیست');
      } else if (tab === 'reports') {
        const { data, error } = await state.client.from('reports').select('*').order('created_at',{ascending:false}).limit(80); if (error) throw error;
        target.innerHTML = adminList(data, x => `<div class="table-row"><div><strong>${esc(x.subject || 'گزارش')}</strong><p>${esc(x.description)} · ${dateFa(x.created_at)}</p></div>${x.status === 'open' ? `<button class="button secondary small" type="button" data-resolve-report="${esc(x.id)}">مختومه</button>` : `<span class="status delivered">مختومه</span>`}</div>`, 'گزارش بازی برای نمایش نیست');
      } else if (tab === 'settings') {
        target.innerHTML = renderAdminSettings();
      }
    } catch (error) { target.innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }
  function adminList(data, mapper, empty) { return data?.length ? `<div class="table-list">${data.map(mapper).join('')}</div>` : emptyHTML(empty,'',null,null); }

  async function openAdminUserDetails(id) {
    showModal(`<div class="modal-head"><h2>جزئیات کاربر</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div>${skeletons(2)}`);
    try {
      const { data, error } = await state.client.rpc('admin_get_user_details', { p_user_id: id }); if (error) throw error;
      const loads = Array.isArray(data.recent_loads) ? data.recent_loads : [];
      modalRoot.querySelector('.modal').innerHTML = `<div class="modal-head"><h2>جزئیات کاربر</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div><section class="detail-hero"><span class="status ${data.is_blocked ? 'cancelled' : 'delivered'}">${data.is_blocked ? 'مسدود' : 'فعال'}</span><h2>${esc(data.display_name || 'پروفایل تکمیل نشده')}</h2><p class="muted" dir="ltr">${esc(data.email || '—')}</p></section><div class="detail-grid"><div class="detail-cell"><span>نقش</span><strong>${roleLabel(data.role)}</strong></div><div class="detail-cell"><span>موبایل</span><strong dir="ltr">${esc(data.phone || '—')}</strong></div><div class="detail-cell"><span>شهر</span><strong>${esc(data.city || '—')}</strong></div><div class="detail-cell"><span>کامیون</span><strong>${esc(data.truck_type || '—')}</strong></div><div class="detail-cell"><span>بار ثبت‌شده</span><strong>${faNumber(data.load_count)}</strong></div><div class="detail-cell"><span>پیشنهاد / سفارش</span><strong>${faNumber(data.offer_count)} / ${faNumber(data.shipment_count)}</strong></div></div>${data.role === 'driver' ? `<section class="card section"><h3>مشخصات کامیون</h3><p class="muted">مدل: ${esc(data.truck_model || '—')}<br>پلاک: ${esc(data.plate_number || '—')}</p></section>` : ''}<section class="card section"><h3>بارهای اخیر این کاربر</h3>${loads.length ? `<div class="compact-list">${loads.map(load => `<div><strong>${esc(load.title)}</strong><span>${esc(load.origin_city)} ← ${esc(load.destination_city)} · ${statusLabel(load.status)}</span></div>`).join('')}</div>` : '<p class="muted">باری ثبت نشده است.</p>'}</section>`;
    } catch (error) { modalRoot.querySelector('.modal').innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }

  async function openAdminLoadDetails(id) {
    showModal(`<div class="modal-head"><h2>جزئیات مدیریتی بار</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div>${skeletons(2)}`);
    try {
      const { data, error } = await state.client.rpc('admin_get_load_details', { p_load_id: id }); if (error) throw error;
      const load = data.load || {}; const owner = data.owner || {}; const details = data.private_details; const offers = Array.isArray(data.offers) ? data.offers : []; const shipment = data.shipment;
      modalRoot.querySelector('.modal').innerHTML = `<div class="modal-head"><h2>جزئیات مدیریتی بار</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div><section class="detail-hero"><span class="status ${esc(load.status)}">${statusLabel(load.status)}</span><h2>${esc(load.title || 'بار')}</h2><div class="route"><span>${esc(load.origin_city || '—')}</span><span class="arrow">←</span><span>${esc(load.destination_city || '—')}</span></div></section><section class="card section"><h3>صاحب بار</h3><p class="muted">${esc(owner.display_name || 'تکمیل نشده')}<br><span dir="ltr">${esc(owner.email || '—')}</span><br><span dir="ltr">${esc(owner.phone || '—')}</span>${owner.is_blocked ? '<br><strong>این حساب مسدود است.</strong>' : ''}</p></section><div class="detail-grid"><div class="detail-cell"><span>کالا</span><strong>${esc(load.cargo_type || '—')}</strong></div><div class="detail-cell"><span>وزن</span><strong>${faNumber(load.weight_value)} ${esc(load.weight_unit || '')}</strong></div><div class="detail-cell"><span>خودروی لازم</span><strong>${esc(load.required_truck_type || '—')}</strong></div><div class="detail-cell"><span>کرایه پیشنهادی</span><strong>${fare(load.proposed_fare)}</strong></div><div class="detail-cell"><span>تاریخ بارگیری</span><strong>${dateFa(load.loading_date)}</strong></div><div class="detail-cell"><span>سفارش حمل</span><strong>${shipment ? statusLabel(shipment.status) : 'ایجاد نشده'}</strong></div></div>${details ? `<section class="card section"><h3>${icon('location')} اطلاعات خصوصی مسیر</h3><p class="muted">بارگیری: ${esc(details.pickup_address)}<br>تخلیه: ${esc(details.delivery_address)}</p></section>` : ''}<section class="card section"><h3>پیشنهادها</h3>${offers.length ? `<div class="compact-list">${offers.map(offer => `<div><strong>${esc(offer.driver_name || 'راننده')}</strong><span>${fare(offer.offered_fare)} · ${statusLabel(offer.status)} · ${esc(offer.truck_type || 'کامیون ثبت نشده')}</span></div>`).join('')}</div>` : '<p class="muted">پیشنهادی ثبت نشده است.</p>'}</section><form id="admin-load-status-form" class="form-grid section" data-load-id="${esc(load.id)}"><section class="card"><span class="kicker">اقدام مدیریتی ثبت‌شونده</span><h3>تغییر وضعیت بار</h3><div class="field"><label>وضعیت جدید</label><select name="load_status">${adminLoadStatusOptions(load.status, Boolean(shipment))}</select></div><div class="field"><label>دلیل اقدام (اختیاری، حداکثر ۵۰۰ کاراکتر)</label><textarea name="reason" maxlength="500" placeholder="برای ثبت در گزارش فعالیت مدیریتی"></textarea></div><button type="submit" class="button danger full">ثبت تغییر وضعیت</button></section></form>`;
    } catch (error) { modalRoot.querySelector('.modal').innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }

  async function adminSetUserBlocked(id, currentlyBlocked) {
    const action = currentlyBlocked ? 'فعال‌سازی' : 'مسدودسازی';
    if (!confirm(`از ${action} این حساب مطمئن هستید؟ این اقدام در گزارش فعالیت مدیریت ثبت می‌شود.`)) return;
    try {
      const { error } = await state.client.rpc('admin_set_user_blocked', { p_user_id: id, p_blocked: !currentlyBlocked }); if (error) throw error;
      toast(currentlyBlocked ? 'حساب کاربر فعال شد.' : 'حساب کاربر مسدود شد.', 'success');
      loadAdmin('users');
    } catch (error) { toast(humanError(error), 'error'); }
  }

  async function adminSetLoadStatus(id, status, reason = '') {
    if (!confirm(`وضعیت بار به «${statusLabel(status)}» تغییر کند؟ این اقدام قابل ثبت در تاریخچه و گزارش مدیریت است.`)) return;
    try {
      const { error } = await state.client.rpc('admin_set_load_status', { p_load_id: id, p_new_status: status, p_reason: reason.trim() || null }); if (error) throw error;
      closeModal(); toast('وضعیت بار با موفقیت تغییر کرد.', 'success'); loadAdmin('loads');
    } catch (error) { toast(humanError(error), 'error'); }
  }

  function showModal(content) { modalRoot.innerHTML = `<div class="modal-backdrop" data-close-modal><section class="modal" role="dialog" aria-modal="true">${content}</section></div>`; const first = modalRoot.querySelector('input,textarea,select,button'); first?.focus(); }
  function closeModal() { modalRoot.innerHTML = ''; }
  function openOffer(id) {
    showModal(`<div class="modal-head"><h2>ثبت پیشنهاد کرایه</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div><form id="offer-form" class="form-grid" data-load-id="${esc(id)}" novalidate><div class="notice info">${icon('shield')}<p>یک پیشنهاد فعال برای هر بار مجاز است. مبلغ را به تومان وارد کنید.</p></div><div class="field"><label for="offered-fare">مبلغ پیشنهادی <span class="required">*</span></label><div class="input-group"><input id="offered-fare" class="input" name="offered_fare" inputmode="numeric" required placeholder="مثلاً ۱۳۵۰۰۰۰۰"><span class="unit">تومان</span></div><span class="field-error"></span></div><div class="field"><label for="offer-note">توضیح (اختیاری)</label><textarea id="offer-note" name="note" maxlength="1000" placeholder="مثلاً امکان بارگیری در تاریخ اعلام‌شده را دارم."></textarea></div><button type="submit" class="button primary full">ارسال پیشنهاد</button></form>`);
  }
  async function openLoadDetail(id) {
    showModal(`<div class="modal-head"><h2>جزئیات بار</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div>${skeletons(2)}`);
    try {
      const {data: load,error}=await state.client.from('loads').select('*').eq('id',id).single(); if(error) throw error;
      let privateData = null;
      const {data: details} = await state.client.from('load_private_details').select('*').eq('load_id',id).maybeSingle(); privateData=details;
      modalRoot.querySelector('.modal').innerHTML = `<div class="modal-head"><h2>جزئیات بار</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div><section class="detail-hero"><span class="status ${esc(load.status)}">${statusLabel(load.status)}</span><h2 style="margin:10px 0 0">${esc(load.title)}</h2><div class="route"><span>${esc(load.origin_city)}</span><span class="arrow">←</span><span>${esc(load.destination_city)}</span></div></section><div class="detail-grid"><div class="detail-cell"><span>کالا</span><strong>${esc(load.cargo_type)}</strong></div><div class="detail-cell"><span>وزن</span><strong>${faNumber(load.weight_value)} ${esc(load.weight_unit)}</strong></div><div class="detail-cell"><span>خودروی موردنیاز</span><strong>${esc(load.required_truck_type)}</strong></div><div class="detail-cell"><span>کرایه پیشنهادی</span><strong>${fare(load.proposed_fare)}</strong></div><div class="detail-cell"><span>تاریخ بارگیری</span><strong>${dateFa(load.loading_date)}</strong></div><div class="detail-cell"><span>زمان ثبت</span><strong>${dateFa(load.created_at, true)}</strong></div></div>${load.cargo_description ? `<section class="card section"><h3>توضیح کالا</h3><p class="muted">${esc(load.cargo_description)}</p></section>` : ''}${load.notes ? `<section class="card section"><h3>توضیحات تکمیلی</h3><p class="muted">${esc(load.notes)}</p></section>` : ''}${privateData ? `<section class="card section"><h3>${icon('location')} اطلاعات خصوصی مسیر</h3><p class="muted">بارگیری: ${esc(privateData.pickup_address)}<br>تخلیه: ${esc(privateData.delivery_address)}</p></section>` : `<div class="notice info section">${icon('shield')}<p>نشانی دقیق فقط برای صاحب بار و طرف‌های سفارش توافق‌شده نمایش داده می‌شود.</p></div>`}<div class="form-actions">${state.profile?.role === 'driver' && load.owner_id !== state.user.id && ['published','receiving_offers'].includes(load.status) && profileReady() ? `<button class="button primary" type="button" data-open-offer="${esc(load.id)}">ثبت پیشنهاد کرایه</button>` : ''}${state.profile?.role === 'cargo_owner' && load.owner_id === state.user.id && ['published','receiving_offers'].includes(load.status) ? `<button class="button ghost" type="button" data-edit-load="${esc(load.id)}">ویرایش</button><button class="button danger" type="button" data-cancel-load="${esc(load.id)}">لغو بار</button>` : ''}</div>`;
    } catch(error) { modalRoot.querySelector('.modal').innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }
  async function openEditLoad(id) {
    showModal(`<div class="modal-head"><h2>ویرایش بار</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div>${skeletons(2)}`);
    try {
      const [{data: load,error}, {data: details}] = await Promise.all([
        state.client.from('loads').select('*').eq('id',id).single(),
        state.client.from('load_private_details').select('*').eq('load_id',id).maybeSingle()
      ]);
      if (error) throw error;
      if (!details) throw new Error('جزئیات خصوصی بار برای ویرایش در دسترس نیست');
      modalRoot.querySelector('.modal').innerHTML = `<div class="modal-head"><h2>ویرایش بار</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div><form id="edit-load-form" class="form-grid" data-load-id="${esc(id)}" novalidate><div class="field"><label>عنوان بار <span class="required">*</span></label><input class="input" name="title" required maxlength="120" value="${esc(load.title)}"></div><div class="form-grid two"><div class="field"><label>مبدأ <span class="required">*</span></label><input class="input" name="origin_city" required list="iran-cities" value="${esc(load.origin_city)}"></div><div class="field"><label>مقصد <span class="required">*</span></label><input class="input" name="destination_city" required list="iran-cities" value="${esc(load.destination_city)}"></div></div><div class="form-grid two"><div class="field"><label>نوع بار <span class="required">*</span></label><select name="cargo_type" required>${cargoOptions(load.cargo_type)}</select></div><div class="field"><label>نوع کامیون <span class="required">*</span></label><select name="required_truck_type" required>${truckOptions(load.required_truck_type)}</select></div></div><div class="form-grid two"><div class="field"><label>وزن <span class="required">*</span></label><input class="input" name="weight_value" inputmode="decimal" required value="${esc(load.weight_value)}"></div><div class="field"><label>واحد</label><select name="weight_unit"><option value="تن" ${load.weight_unit==='تن'?'selected':''}>تن</option><option value="کیلوگرم" ${load.weight_unit==='کیلوگرم'?'selected':''}>کیلوگرم</option></select></div></div><div class="field"><label>کرایه پیشنهادی <span class="required">*</span></label><div class="input-group"><input class="input" name="proposed_fare" inputmode="numeric" required value="${esc(load.proposed_fare)}"><span class="unit">تومان</span></div></div><div class="field"><label>تاریخ بارگیری <span class="required">*</span></label><input class="input" name="loading_date" type="date" required value="${esc(load.loading_date)}"></div><div class="field"><label>نشانی بارگیری <span class="required">*</span></label><textarea name="pickup_address" required>${esc(details.pickup_address)}</textarea></div><div class="field"><label>نشانی تخلیه <span class="required">*</span></label><textarea name="delivery_address" required>${esc(details.delivery_address)}</textarea></div><div class="field"><label>توضیح کالا</label><textarea name="cargo_description">${esc(load.cargo_description||'')}</textarea></div><div class="field"><label>توضیحات تکمیلی</label><textarea name="notes">${esc(load.notes||'')}</textarea></div><datalist id="iran-cities">${cityOptions()}</datalist><button type="submit" class="button primary full">ذخیره تغییرات</button></form>`;
    } catch (error) { modalRoot.querySelector('.modal').innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }
  async function openShipmentDetail(id) {
    showModal(`<div class="modal-head"><h2>پیگیری سفارش</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div>${skeletons(2)}`);
    try {
      const [{data: shipment,error}, {data: history}] = await Promise.all([
        state.client.from('shipments').select('*, loads(title,origin_city,destination_city)').eq('id',id).single(),
        state.client.from('shipment_status_history').select('*').eq('shipment_id',id).order('created_at',{ascending:false})
      ]); if(error) throw error;
      const action=nextAction(shipment); const h = history || [];
      modalRoot.querySelector('.modal').innerHTML = `<div class="modal-head"><h2>پیگیری سفارش</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div><section class="detail-hero"><span class="status ${esc(shipment.status)}">${statusLabel(shipment.status)}</span><div class="route"><span>${esc(shipment.loads?.origin_city||'—')}</span><span class="arrow">←</span><span>${esc(shipment.loads?.destination_city||'—')}</span></div><p class="muted" style="margin:0">${esc(shipment.loads?.title||'')}</p></section><section class="card section"><h3>تاریخچه وضعیت</h3><div class="timeline">${h.length ? h.map(x=>`<div class="timeline-item"><strong>${statusLabel(x.new_status)}</strong><p>${esc(x.note||'تغییر وضعیت سفارش')}</p><time>${dateFa(x.created_at,true)}</time></div>`).join('') : '<p class="muted">تاریخچه‌ای ثبت نشده است.</p>'}</div></section><section id="private-shipment-info" class="card section"><p class="muted">در حال دریافت اطلاعات مجاز سفارش…</p></section>${action ? `<button class="button primary full" type="button" data-shipment-status="${esc(id)}" data-next-status="${action[0]}">${action[1]}</button>` : ''}`;
      loadShipmentPrivate(id);
    } catch(error) { modalRoot.querySelector('.modal').innerHTML = `<div class="notice danger">${icon('alert')}<p>${esc(humanError(error))}</p></div>`; }
  }
  async function loadShipmentPrivate(id) {
    const slot = $('#private-shipment-info'); if (!slot) return;
    try { const {data,error}=await state.client.rpc('get_shipment_private_details',{p_shipment_id:id}); if(error) throw error; const x = Array.isArray(data) ? data[0] : data; if(!x) throw new Error('اطلاعاتی پیدا نشد'); slot.innerHTML = `<h3>اطلاعات مجاز طرفین و مسیر</h3><p class="muted">طرف مقابل: ${esc(x.counterparty_name || '—')}<br>شماره تماس: <a dir="ltr" href="tel:${esc(x.counterparty_phone || '')}">${esc(x.counterparty_phone || '—')}</a><br>محل بارگیری: ${esc(x.pickup_address || '—')}<br>محل تخلیه: ${esc(x.delivery_address || '—')}</p>`; } catch (_) { slot.innerHTML = `<div class="notice info">${icon('shield')}<p>اطلاعات خصوصی پس از ایجاد سفارش و فقط برای طرف‌های مجاز نمایش داده می‌شود.</p></div>`; }
  }
  function openReport(targetId = '') { showModal(`<div class="modal-head"><h2>ثبت گزارش یا شکایت</h2><button class="modal-close" type="button" data-close-modal aria-label="بستن">×</button></div><form id="report-form" class="form-grid" data-target-id="${esc(targetId)}"><div class="field"><label for="report-subject">موضوع <span class="required">*</span></label><input id="report-subject" class="input" name="subject" maxlength="140" required placeholder="مثلاً تأخیر در تحویل"></div><div class="field"><label for="report-description">توضیحات <span class="required">*</span></label><textarea id="report-description" name="description" maxlength="2000" required placeholder="جزئیات گزارش را بنویسید."></textarea></div><button type="submit" class="button primary full">ارسال گزارش برای بررسی</button></form>`); }

  function clearFormErrors(form) { form.querySelectorAll('.field-error').forEach(x => x.textContent = ''); form.querySelectorAll('[aria-invalid]').forEach(x => x.removeAttribute('aria-invalid')); }
  function formValid(form, rules = {}) {
    clearFormErrors(form); let okay = true; let first;
    form.querySelectorAll('[required]').forEach(input => { let message = ''; const value = input.value.trim(); if(!value) message='تکمیل این بخش الزامی است.'; else if(input.type==='email' && !/^\S+@\S+\.\S+$/.test(value)) message='ایمیل معتبر وارد کنید.'; else if(input.minLength>0 && value.length<input.minLength) message=`حداقل ${faNumber(input.minLength)} کاراکتر وارد کنید.`; else if(rules[input.name]) message=rules[input.name](value) || ''; if(message) { okay=false; input.setAttribute('aria-invalid','true'); const err=input.closest('.field')?.querySelector('.field-error'); if(err) err.textContent=message; first ||= input; } });
    if (!okay) { first?.focus(); toast('لطفاً خطاهای فرم را اصلاح کنید.','error'); }
    return okay;
  }
  function phoneValid(v) { return /^(?:\+98|0098|0)?9\d{9}$/.test(normalizeDigits(v).replace(/[\s-]/g,'')) ? '' : 'شماره موبایل ایران را درست وارد کنید.'; }
  function positiveNumber(v, message = 'مقدار معتبر و بزرگ‌تر از صفر وارد کنید.') { const n=Number(normalizeDigits(v)); return Number.isFinite(n) && n>0 ? '' : message; }
  function strongPasswordValid(value) { return /[A-Za-zآ-ی]/.test(value) && /\d/.test(value) ? '' : 'رمز باید دست‌کم یک حرف و یک عدد داشته باشد.'; }
  function showFieldError(form, name, message) { const input = form.elements[name]; if (!input) return; input.setAttribute('aria-invalid','true'); input.closest('.field')?.querySelector('.field-error')?.replaceChildren(document.createTextNode(message)); input.focus(); }
  function passwordsMatch(form) { const password = String(form.elements.password?.value || ''); const confirmation = String(form.elements.password_confirmation?.value || ''); if (password === confirmation) return true; showFieldError(form,'password_confirmation','تکرار رمز با رمز عبور یکسان نیست.'); toast('لطفاً تکرار رمز عبور را اصلاح کنید.','error'); return false; }

  async function onSubmit(event) {
    const form = event.target;
    if (!(form instanceof HTMLFormElement)) return;
    event.preventDefault();
    if (form.id === 'login-form') {
      if(!formValid(form)) return;
      const button=$('[type="submit"]',form); setBusy(button,true);
      try {
        const f=new FormData(form);
        const email = f.get('email').trim().toLowerCase();
        state.pendingEmail = email;
        const {data,error}=await state.client.auth.signInWithPassword({email,password:f.get('password')});
        if(error) throw error;
        if (!emailIsConfirmed(data.user)) {
          await state.client.auth.signOut({ scope: 'local' });
          throw new Error('EMAIL_VERIFICATION_REQUIRED');
        }
        toast('با موفقیت وارد شدید.','success');
      } catch(e){toast(humanError(e),'error');setBusy(button,false);}
      return;
    }
    if (form.id === 'signup-form') {
      if(!formValid(form,{password:strongPasswordValid}) || !passwordsMatch(form)) return;
      const button=$('[type="submit"]',form); setBusy(button,true);
      try {
        const f=new FormData(form);
        const email=f.get('email').trim().toLowerCase();
        const {data,error}=await state.client.auth.signUp({
          email,
          password:f.get('password'),
          options:{ emailRedirectTo: authRedirectUrl(), data:{signup_role:state.signupRole} }
        });
        if(error) throw error;
        // با Confirm email صحیح، Supabase نباید session برگرداند. این بررسی از پیکربندی ناامن جلوگیری می‌کند.
        if (data.session) {
          await state.client.auth.signOut({ scope: 'local' });
          throw new Error('EMAIL_CONFIRMATION_NOT_ENFORCED');
        }
        state.pendingEmail=email;
        beginEmailCooldown();
        state.authTab='check-email';
        renderAuth();
        toast('ایمیل تأیید ارسال شد. صندوق ورودی خود را بررسی کنید.','success');
      } catch(e){toast(humanError(e),'error');setBusy(button,false);}
      return;
    }
    if (form.id === 'forgot-password-form') { await sendRecovery(form); return; }
    if (form.id === 'new-password-form') {
      if(!formValid(form,{password:strongPasswordValid}) || !passwordsMatch(form))return;
      const button=$('[type="submit"]',form); setBusy(button,true);
      try{
        const {error}=await state.client.auth.updateUser({password:new FormData(form).get('password')});
        if(error)throw error;
        toast('رمز عبور با موفقیت تغییر کرد.','success');
        state.authTab='login';
        navigate('home');
      }catch(e){toast(humanError(e),'error');setBusy(button,false);}
      return;
    }
    if (form.id === 'admin-users-filter') {
      const f = new FormData(form);
      await loadAdmin('users', { page: 1, filters: { search: String(f.get('search') || '').trim(), role: String(f.get('role') || ''), status: String(f.get('status') || 'all') } });
      return;
    }
    if (form.id === 'admin-loads-filter') {
      const f = new FormData(form);
      await loadAdmin('loads', { page: 1, filters: { search: String(f.get('search') || '').trim(), status: String(f.get('status') || '') } });
      return;
    }
    if (form.id === 'admin-load-status-form') {
      const f = new FormData(form);
      await adminSetLoadStatus(form.dataset.loadId, String(f.get('load_status') || ''), String(f.get('reason') || ''));
      return;
    }
    if(form.id === 'profile-form') { await saveProfile(form); return; }
    if(form.id === 'create-load-form') { await createLoad(form); return; }
    if(form.id === 'edit-load-form') { await updateLoad(form); return; }
    if(form.id === 'load-filter-form') { const f=new FormData(form); const min=normalizeDigits(f.get('min_fare'));const max=normalizeDigits(f.get('max_fare'));if(min&&positiveNumber(min)){toast('حداقل کرایه معتبر وارد کنید.','error');return;}if(max&&positiveNumber(max)){toast('حداکثر کرایه معتبر وارد کنید.','error');return;}if(min&&max&&Number(min)>Number(max)){toast('حداقل کرایه نمی‌تواند بیشتر از حداکثر باشد.','error');return;}loadLoads({origin:f.get('origin'),destination:f.get('destination'),cargo_type:f.get('cargo_type'),truck_type:f.get('truck_type'),min_fare:min,max_fare:max});return; }
    if(form.id === 'offer-form') { await submitOffer(form); return; }
    if(form.id === 'report-form') { await submitReport(form); return; }
  }
  async function saveProfile(form) {
    if(!formValid(form,{phone:phoneValid}))return; const button=$('[type="submit"]',form);setBusy(button,true);try{const f=new FormData(form); const payload={display_name:f.get('display_name').trim(),phone:normalizeDigits(f.get('phone')).replace(/[\s-]/g,''),city:f.get('city').trim()||null};if(state.profile.role==='driver')Object.assign(payload,{truck_type:f.get('truck_type'),truck_model:f.get('truck_model').trim()||null,plate_number:f.get('plate_number').trim()||null});const {error}=await state.client.from('profiles').update(payload).eq('id',state.user.id);if(error)throw error;await loadProfile();toast('پروفایل با موفقیت ذخیره شد.','success');navigate('home');}catch(e){toast(humanError(e),'error');setBusy(button,false);}
  }
  async function createLoad(form) {
    const rules={weight_value:v=>positiveNumber(v,'وزن معتبر و بزرگ‌تر از صفر وارد کنید.'),proposed_fare:v=>positiveNumber(v,'کرایه باید بزرگ‌تر از صفر باشد.')}; if(!formValid(form,rules)) return; const button=$('[type="submit"]',form);setBusy(button,true);try{const f=new FormData(form); const payload={title:f.get('title').trim(),cargo_description:f.get('cargo_description').trim()||null,cargo_type:f.get('cargo_type'),required_truck_type:f.get('required_truck_type'),weight_value:Number(normalizeDigits(f.get('weight_value'))),weight_unit:f.get('weight_unit'),origin_city:f.get('origin_city').trim(),destination_city:f.get('destination_city').trim(),pickup_address:f.get('pickup_address').trim(),delivery_address:f.get('delivery_address').trim(),loading_date:f.get('loading_date'),proposed_fare:Number(normalizeDigits(f.get('proposed_fare'))),notes:f.get('notes').trim()||null};const {data,error}=await state.client.rpc('create_load_with_private_details',{p_payload:payload});if(error)throw error;toast('بار با موفقیت ثبت و منتشر شد.','success');navigate('offers');}catch(e){toast(humanError(e),'error');setBusy(button,false);}
  }
  async function updateLoad(form) {
    const rules={weight_value:v=>positiveNumber(v,'وزن معتبر و بزرگ‌تر از صفر وارد کنید.'),proposed_fare:v=>positiveNumber(v,'کرایه باید بزرگ‌تر از صفر باشد.')};
    if(!formValid(form,rules)) return;
    const button=$('[type="submit"]',form);setBusy(button,true);
    try { const f=new FormData(form); const payload={title:f.get('title').trim(),cargo_description:f.get('cargo_description').trim()||null,cargo_type:f.get('cargo_type'),required_truck_type:f.get('required_truck_type'),weight_value:Number(normalizeDigits(f.get('weight_value'))),weight_unit:f.get('weight_unit'),origin_city:f.get('origin_city').trim(),destination_city:f.get('destination_city').trim(),pickup_address:f.get('pickup_address').trim(),delivery_address:f.get('delivery_address').trim(),loading_date:f.get('loading_date'),proposed_fare:Number(normalizeDigits(f.get('proposed_fare'))),notes:f.get('notes').trim()||null}; const {error}=await state.client.rpc('update_load_with_private_details',{p_load_id:form.dataset.loadId,p_payload:payload});if(error)throw error;closeModal();toast('تغییرات بار ذخیره شد.','success');render(); } catch(e) {toast(humanError(e),'error');setBusy(button,false);}
  }
  async function submitOffer(form) {
    if(!formValid(form,{offered_fare:v=>positiveNumber(v,'مبلغ پیشنهادی باید بزرگ‌تر از صفر باشد.')}))return;const button=$('[type="submit"]',form);setBusy(button,true);try{const f=new FormData(form);const {error}=await state.client.rpc('submit_freight_offer',{p_load_id:form.dataset.loadId,p_offered_fare:Number(normalizeDigits(f.get('offered_fare'))),p_note:f.get('note').trim()||null});if(error)throw error;closeModal();toast('پیشنهاد کرایه شما ثبت شد.','success');navigate('offers');}catch(e){toast(humanError(e),'error');setBusy(button,false);}
  }
  async function submitReport(form) {if(!formValid(form))return;const b=$('[type="submit"]',form);setBusy(b,true);try{const f=new FormData(form);const {error}=await state.client.from('reports').insert({reporter_id:state.user.id,subject:f.get('subject').trim(),description:f.get('description').trim(),target_id:form.dataset.targetId||null});if(error)throw error;closeModal();toast('گزارش شما برای بررسی ثبت شد.','success');}catch(e){toast(humanError(e),'error');setBusy(b,false);}}

  document.addEventListener('click', async event => {
    const target = event.target.closest('button,a'); if(!target) return;
    if(target.dataset.route){ event.preventDefault();navigate(target.dataset.route);return; }
    if(target.dataset.authTab){state.authTab=target.dataset.authTab;renderAuth();return;}
    if(target.dataset.signupRole){state.signupRole=target.dataset.signupRole;renderAuth();return;}
    if(target.dataset.togglePassword){const input=document.getElementById(target.dataset.togglePassword);if(!input)return;const show=input.type==='password';input.type=show?'text':'password';target.setAttribute('aria-pressed',String(show));target.setAttribute('aria-label',show?'پنهان‌کردن رمز عبور':'نمایش رمز عبور');target.innerHTML=icon(show?'eyeOff':'eye');return;}
    if(target.dataset.closeModal !== undefined || (target.dataset.closeModal!==undefined && event.target.classList.contains('modal-backdrop'))){closeModal();return;}
    if(target.classList.contains('modal-backdrop')){closeModal();return;}
    if(target.dataset.openOffer){closeModal();openOffer(target.dataset.openOffer);return;}
    if(target.dataset.loadDetail){openLoadDetail(target.dataset.loadDetail);return;}
    if(target.dataset.editLoad){openEditLoad(target.dataset.editLoad);return;}
    if(target.dataset.shipmentDetail){openShipmentDetail(target.dataset.shipmentDetail);return;}
    if(target.dataset.openReport !== undefined){openReport(target.dataset.openReport);return;}
    if(target.dataset.action==='retry'){location.reload();return;}
    if(target.dataset.action==='reload-profile'){await loadProfile();render();return;}
    if(target.dataset.action==='refresh-dashboard'){loadDashboardData();return;}
    if(target.dataset.action==='refresh-loads'){loadLoads();return;}
    if(target.dataset.action==='refresh-offers'){loadOffers();return;}
    if(target.dataset.action==='refresh-shipments'){loadShipments();return;}
    if(target.dataset.action==='forgot-password'){state.authTab='forgot';renderAuth();return;}
    if(target.dataset.action==='resend-confirmation'){await resendConfirmation(target);return;}
    if(target.dataset.action==='resend-recovery'){await resendRecovery(target);return;}
    if(target.dataset.action==='signout'){await signOut();return;}
    if(target.dataset.cancelLoad){await cancelLoad(target.dataset.cancelLoad);return;}
    if(target.dataset.acceptOffer){await acceptOffer(target.dataset.acceptOffer);return;}
    if(target.dataset.shipmentStatus){await changeShipmentStatus(target.dataset.shipmentStatus,target.dataset.nextStatus);return;}
    if(target.dataset.adminTab){await loadAdmin(target.dataset.adminTab);return;}
    if(target.dataset.adminUserDetail){await openAdminUserDetails(target.dataset.adminUserDetail);return;}
    if(target.dataset.adminUserBlock){await adminSetUserBlocked(target.dataset.adminUserBlock,target.dataset.currentBlocked==='1');return;}
    if(target.dataset.adminLoadDetail){await openAdminLoadDetails(target.dataset.adminLoadDetail);return;}
    if(target.dataset.adminLoadDeactivate){await adminSetLoadStatus(target.dataset.adminLoadDeactivate,'cancelled','غیرفعال‌سازی بار نامعتبر توسط مدیر');return;}
    if(target.dataset.adminPageKind){const page=Number(target.dataset.adminPage);if(!Number.isInteger(page)||page<1)return;if(target.dataset.adminPageKind==='users')await loadAdmin('users',{page});else if(target.dataset.adminPageKind==='loads')await loadAdmin('loads',{page});return;}
    if(target.dataset.resolveReport){await resolveReport(target.dataset.resolveReport);return;}
  });
  document.addEventListener('submit', onSubmit);
  document.addEventListener('keydown', e => { if(e.key==='Escape')closeModal(); });
  async function sendRecovery(form){
    if(!formValid(form))return;
    const button=$('[type="submit"]',form);setBusy(button,true);
    try{
      const email=new FormData(form).get('email').trim().toLowerCase();
      const {error}=await state.client.auth.resetPasswordForEmail(email,{redirectTo:authRedirectUrl('reset-password')});
      if(error)throw error;
      state.pendingEmail=email;
      beginEmailCooldown();
      state.authTab='recovery-sent';
      renderAuth();
      toast('اگر حسابی با این ایمیل وجود داشته باشد، لینک بازیابی ارسال شد.','success');
    }catch(e){toast(humanError(e),'error');setBusy(button,false);}
  }
  async function resendRecovery(button){
    if(!state.pendingEmail){state.authTab='forgot';renderAuth();return;}
    const seconds=emailCooldownSeconds(); if(seconds){toast(`برای ارسال دوباره ${faNumber(seconds)} ثانیه صبر کنید.`,'info');return;}
    setBusy(button,true);
    try{
      const {error}=await state.client.auth.resetPasswordForEmail(state.pendingEmail,{redirectTo:authRedirectUrl('reset-password')});
      if(error)throw error;
      beginEmailCooldown();
      renderAuth();
      toast('لینک بازیابی دوباره ارسال شد.','success');
    }catch(e){toast(humanError(e),'error');setBusy(button,false);}
  }
  async function resendConfirmation(button){
    const email=state.pendingEmail;
    if(!email){state.authTab='signup';renderAuth();toast('ابتدا ایمیل خود را در فرم ثبت‌نام وارد کنید.','info');return;}
    const seconds=emailCooldownSeconds(); if(seconds){toast(`برای ارسال دوباره ${faNumber(seconds)} ثانیه صبر کنید.`,'info');return;}
    setBusy(button,true);
    try{
      const {error}=await state.client.auth.resend({type:'signup',email,options:{emailRedirectTo:authRedirectUrl()}});
      if(error)throw error;
      beginEmailCooldown();
      renderAuth();
      toast('لینک تأیید دوباره ارسال شد.','success');
    }catch(e){toast(humanError(e),'error');setBusy(button,false);}
  }
  async function signOut(){try{const {error}=await state.client.auth.signOut();if(error)throw error;toast('از حساب خارج شدید.','success');navigate('home');}catch(e){toast(humanError(e),'error');}}
  async function cancelLoad(id){if(!confirm('از لغو این بار مطمئن هستید؟ پس از توافق امکان لغو از این مسیر وجود ندارد.'))return;try{const {error}=await state.client.from('loads').update({status:'cancelled'}).eq('id',id);if(error)throw error;closeModal();toast('بار لغو شد.','success');render();}catch(e){toast(humanError(e),'error');}}
  async function acceptOffer(id){if(!confirm('با پذیرش این پیشنهاد، سفارش حمل ایجاد و سایر پیشنهادها مختومه می‌شوند. ادامه می‌دهید؟'))return;try{const {error}=await state.client.rpc('accept_freight_offer',{p_offer_id:id});if(error)throw error;toast('پیشنهاد پذیرفته و سفارش حمل ایجاد شد.','success');navigate('shipments');}catch(e){toast(humanError(e),'error');}}
  async function changeShipmentStatus(id,next){const labels={awaiting_pickup:'آماده بارگیری',in_transit:'در حال حمل',delivered:'تحویل‌شده'};if(!confirm(`وضعیت سفارش به «${labels[next]}» تغییر کند؟`))return;try{const {error}=await state.client.rpc('change_shipment_status',{p_shipment_id:id,p_new_status:next,p_note:null});if(error)throw error;closeModal();toast('وضعیت سفارش به‌روزرسانی شد.','success');render();}catch(e){toast(humanError(e),'error');}}
  async function resolveReport(id){if(!confirm('از مختومه‌کردن این گزارش مطمئن هستید؟ این اقدام در سوابق گزارش ثبت می‌شود.'))return;try{const {error}=await state.client.from('reports').update({status:'resolved',resolved_at:new Date().toISOString(),resolved_by:state.user.id}).eq('id',id);if(error)throw error;toast('گزارش مختومه شد.','success');loadAdmin('reports');}catch(e){toast(humanError(e),'error');}}

  init();
})();
