/* Barino admin console. Every data read/write goes through admin-only database RPCs. */
(() => {
  'use strict';

  const root = document.getElementById('admin-root');
  const toastRegion = document.getElementById('admin-toast-region');
  const modalRoot = document.getElementById('admin-modal-root');
  const PAGE_SIZE = 20;
  const APP_VERSION = '2026.11-admin.1';
  const state = {
    client: null,
    subscription: null,
    user: null,
    session: null,
    adminInfo: null,
    access: 'checking',
    dbConnected: false,
    online: navigator.onLine,
    tab: 'overview',
    verifying: null,
    collapsed: false,
    mobileNavOpen: false,
    pages: { users: 0, loads: 0, shipments: 0, reports: 0 },
    filters: {
      users: { search: '', role: 'all', status: 'all' },
      loads: { search: '', status: 'all' },
      shipments: { search: '', status: 'all' },
      reports: { search: '', status: 'all' }
    }
  };

  const icons = {
    dashboard: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="3" width="8" height="5" rx="2"/><rect x="13" y="10" width="8" height="11" rx="2"/><rect x="3" y="13" width="8" height="8" rx="2"/></svg>',
    users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"/><circle cx="9.5" cy="7" r="4"/><path d="M20 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
    loads: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m3 7 9-4 9 4-9 4z"/><path d="M3 7v10l9 4 9-4V7M12 11v10M7.5 5l9 4"/></svg>',
    shipments: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 6h11v12H3zM14 10h4l3 3v5h-7z"/><circle cx="7.5" cy="19" r="2"/><circle cx="18" cy="19" r="2"/></svg>',
    reports: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3 2.8 19a1.7 1.7 0 0 0 1.5 2.5h15.4a1.7 1.7 0 0 0 1.5-2.5z"/><path d="M12 9v5M12 17h.01"/></svg>',
    security: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10"/><path d="m9 12 2 2 4-4"/></svg>',
    settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="3"/><path d="m19.4 15 .1.1a1.7 1.7 0 0 1-2.4 2.4l-.1-.1a1.7 1.7 0 0 0-2.9 1.2v.2a1.7 1.7 0 0 1-3.4 0v-.2a1.7 1.7 0 0 0-2.9-1.2l-.1.1a1.7 1.7 0 0 1-2.4-2.4l.1-.1a1.7 1.7 0 0 0-1.2-2.9H4a1.7 1.7 0 0 1 0-3.4h.2a1.7 1.7 0 0 0 1.2-2.9l-.1-.1a1.7 1.7 0 0 1 2.4-2.4l.1.1a1.7 1.7 0 0 0 2.9-1.2V2a1.7 1.7 0 0 1 3.4 0v.2a1.7 1.7 0 0 0 2.9 1.2l.1-.1a1.7 1.7 0 0 1 2.4 2.4l-.1.1a1.7 1.7 0 0 0 1.2 2.9h.2a1.7 1.7 0 0 1 0 3.4h-.2a1.7 1.7 0 0 0-1.2 2.9z"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg>',
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 11a8 8 0 1 0 2 5.3"/><path d="M20 4v7h-7"/></svg>',
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12"/><circle cx="12" cy="12" r="2.5"/></svg>',
    eyeOff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m3 3 18 18"/><path d="M10.6 6.2A10.8 10.8 0 0 1 12 6c6.5 0 10 6 10 6a18.3 18.3 0 0 1-3.1 3.7M6.2 6.2C3.6 8 2 12 2 12s3.5 6 10 6c1.5 0 2.8-.3 4-.8"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/></svg>',
    logout: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10 17l5-5-5-5M15 12H3"/><path d="M21 3v18"/></svg>',
    menu: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg>',
    close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m18 6-12 12M6 6l12 12"/></svg>',
    arrow: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
    shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10"/><path d="m9 12 2 2 4-4"/></svg>',
    database: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14c0 1.7 4 3 9 3s9-1.3 9-3V5M3 12c0 1.7 4 3 9 3s9-1.3 9-3"/></svg>',
    mail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>',
    alert: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0"/><path d="M12 9v4M12 17h.01"/></svg>',
    truck: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 5h11v11H3z"/><path d="M14 8h4l3 3v5h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/></svg>',
    box: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m21 8-9 5-9-5 9-5z"/><path d="M3 8v8l9 5 9-5V8M12 13v8"/></svg>',
    chart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 3v18h18"/><path d="m7 16 4-5 3 3 5-7"/></svg>'
  };

  const tabs = [
    { id: 'overview', label: 'نمای کلی', icon: 'dashboard' },
    { id: 'users', label: 'مدیریت کاربران', icon: 'users' },
    { id: 'loads', label: 'مدیریت بارها', icon: 'loads' },
    { id: 'shipments', label: 'سفارش‌ها', icon: 'shipments' },
    { id: 'reports', label: 'گزارش‌ها', icon: 'reports' },
    { id: 'security', label: 'امنیت و نشست', icon: 'security' },
    { id: 'settings', label: 'تنظیمات سرویس', icon: 'settings' }
  ];

  const $ = (selector, scope = document) => scope.querySelector(selector);
  const esc = value => String(value ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
  const numberFa = value => new Intl.NumberFormat('fa-IR').format(Number(value || 0));
  const shortId = value => value ? `${String(value).slice(0, 8)}…` : '—';
  const statusLabels = {
    published: 'منتشرشده', receiving_offers: 'دریافت پیشنهاد', agreed: 'توافق‌شده', awaiting_pickup: 'در انتظار بارگیری',
    in_transit: 'در حال حمل', delivered: 'تحویل‌شده', cancelled: 'لغوشده', open: 'باز', resolved: 'رسیدگی‌شده',
    dismissed: 'مختومه', active: 'فعال', blocked: 'مسدود', unverified: 'تأییدنشده', submitted: 'ارسال‌شده',
    accepted: 'پذیرفته‌شده', declined: 'مختومه', rejected: 'ردشده'
  };
  const roleLabels = { driver: 'راننده', cargo_owner: 'صاحب بار' };
  const actionLabels = {
    user_blocked: 'مسدودسازی کاربر', user_unblocked: 'رفع مسدودی کاربر', user_role_changed: 'تغییر نقش کاربر',
    load_cancelled: 'غیرفعال‌سازی بار', load_status_changed: 'تغییر وضعیت بار',
    report_resolved: 'رسیدگی به گزارش', report_dismissed: 'مختومه‌کردن گزارش', report_reopened: 'بازگشایی گزارش'
  };

  function icon(name) { return icons[name] || ''; }
  function statusLabel(value) { return statusLabels[value] || String(value || '—'); }
  function roleLabel(value) { return roleLabels[value] || '—'; }
  function dateFa(value, withTime = false) {
    if (!value) return '—';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '—';
    return new Intl.DateTimeFormat('fa-IR', withTime ? { dateStyle: 'medium', timeStyle: 'short' } : { dateStyle: 'medium' }).format(date);
  }
  function dateFromUnix(seconds) { return seconds ? dateFa(Number(seconds) * 1000, true) : '—'; }
  function safeErrorMessage(error) {
    if (!state.online || /network|fetch|timeout/i.test(String(error?.message || ''))) return 'ارتباط با Supabase برقرار نشد. وضعیت اینترنت یا تنظیمات اتصال را بررسی کنید.';
    if (error?.code === '42501' || /ADMIN_ACCESS_DENIED|not authorized|permission denied/i.test(String(error?.message || ''))) return 'نشست مدیریتی معتبر نیست یا دسترسی مدیر لغو شده است.';
    if (error?.code === 'P0002') return 'مورد درخواستی پیدا نشد یا دیگر در دسترس نیست.';
    if (error?.code === '22023') return 'درخواست با وضعیت فعلی این مورد سازگار نیست.';
    return 'عملیات انجام نشد. اتصال سرویس و migrationهای پایگاه داده را بررسی و دوباره تلاش کنید.';
  }
  function isAccessError(error) { return error?.code === '42501' || /ADMIN_ACCESS_DENIED/i.test(String(error?.message || '')); }

  function toast(message, type = 'success') {
    const node = document.createElement('div');
    node.className = `toast ${type}`;
    node.setAttribute('role', 'status');
    node.innerHTML = `${type === 'error' ? icon('alert') : type === 'info' ? icon('clock') : icon('check')}<span>${esc(message)}</span>`;
    toastRegion.append(node);
    window.setTimeout(() => node.remove(), 4200);
  }
  function closeModal() { modalRoot.innerHTML = ''; }
  function showModal(title, subtitle, content, actions = '') {
    modalRoot.innerHTML = `<div class="modal-root" data-modal-backdrop><section class="admin-modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><header class="modal-head"><div><h2 id="modal-title">${esc(title)}</h2>${subtitle ? `<p>${esc(subtitle)}</p>` : ''}</div><button class="modal-close" type="button" data-action="modal-close" aria-label="بستن">×</button></header>${content}${actions ? `<div class="modal-actions">${actions}</div>` : ''}</section></div>`;
    $('[data-action="modal-close"]', modalRoot)?.focus();
  }
  function callRpc(name, params = {}) {
    if (!state.client) return Promise.reject(new Error('Client is not configured'));
    return state.client.rpc(name, params).then(({ data, error }) => {
      if (error) {
        if (isAccessError(error)) {
          state.access = 'denied';
          state.adminInfo = null;
          renderDenied();
        }
        throw error;
      }
      state.dbConnected = true;
      updateConnectionPill();
      return data;
    });
  }
  function showServiceError(error, retry = true) {
    const target = $('#admin-view');
    if (!target) return;
    state.dbConnected = false;
    updateConnectionPill();
    target.innerHTML = `<div class="state-card"><div class="state-icon danger">${icon('alert')}</div><h1>اتصال مدیریتی برقرار نشد</h1><p>${esc(safeErrorMessage(error))}</p><div class="state-actions">${retry ? '<button class="admin-button primary" type="button" data-action="retry-tab">تلاش دوباره</button>' : ''}<button class="admin-button ghost" type="button" data-action="logout">خروج امن</button></div></div>`;
  }

  function renderLogin(message = '') {
    state.access = 'login';
    root.innerHTML = `<main class="admin-login-page" id="admin-main"><section class="login-brand-panel"><div class="login-brand-top"><span class="brand-symbol">B</span><span>Barino <small>مدیریت سامانه</small></span></div><div class="login-brand-content"><span class="eyebrow">${icon('security')} فضای اختصاصی مدیر</span><h1>مدیریت شفاف،<br />کنترل امن.</h1><p>دسترسی این داشبورد با حساب کاربری تأییدشده و مجوزی که مالک پروژه در پایگاه داده ثبت کرده کنترل می‌شود.</p><div class="login-security-list"><div class="login-security-item"><span>${icon('shield')}</span><span>مجوز مدیر از جدول خصوصی پایگاه داده تأیید می‌شود.</span></div><div class="login-security-item"><span>${icon('database')}</span><span>عملیات مدیریتی در PostgreSQL و RLS دوباره بررسی می‌شوند.</span></div><div class="login-security-item"><span>${icon('check')}</span><span>این صفحه ثبت‌نام یا ساخت حساب مدیر ندارد.</span></div></div></div><footer class="login-brand-footer">© Barino · پنل مدیریت امن</footer></section><section class="login-form-panel"><div class="login-form-wrap"><div class="mini-brand">پنل اختصاصی مالک پروژه</div><h2>ورود مدیر</h2><p class="lead">با حساب تأییدشده‌ای که مالک پروژه برای مدیریت مجاز کرده وارد شوید.</p><form class="login-form" id="admin-login-form" novalidate><div class="admin-field"><label for="admin-email">ایمیل حساب مدیر</label><input id="admin-email" name="email" type="email" autocomplete="username" inputmode="email" maxlength="254" required placeholder="name@example.com" dir="ltr" /></div><div class="admin-field"><label for="admin-password">رمز عبور</label><div class="password-control"><input id="admin-password" name="password" type="password" autocomplete="current-password" minlength="8" required placeholder="رمز عبور حساب" dir="ltr" /><button class="password-eye" type="button" data-action="toggle-password" aria-label="نمایش رمز عبور" aria-pressed="false">${icon('eye')}</button></div></div><div id="login-error" class="login-error ${message ? 'visible' : ''}" role="alert">${esc(message)}</div><button class="admin-button primary" type="submit" id="login-submit">ورود امن ${icon('arrow')}</button></form><p class="login-help">حساب مدیر از قبل باید در Supabase Auth تأیید شده و توسط مالک پروژه در <code>app_admins</code> ثبت شده باشد.</p><a class="login-back" href="./">${icon('arrow')} بازگشت به سامانه عمومی</a></div></section></main>`;
  }
  function renderDenied() {
    state.access = 'denied';
    state.adminInfo = null;
    root.innerHTML = `<main class="state-screen" id="admin-main"><section class="state-card"><div class="state-icon danger">${icon('security')}</div><h1>دسترسی غیرمجاز</h1><p>این حساب مدیر فعال و تأییدشدهٔ پروژه نیست. داشبورد و اطلاعات مدیریتی بارگذاری نشده‌اند.</p><div class="state-actions"><a class="admin-button secondary" href="./">بازگشت به سامانه</a><button class="admin-button ghost" type="button" data-action="logout">خروج از حساب</button></div></section></main>`;
  }
  function renderConfigurationError(message) {
    root.innerHTML = `<main class="state-screen" id="admin-main"><section class="state-card"><div class="state-icon danger">${icon('database')}</div><h1>پنل هنوز پیکربندی نشده است</h1><p>${esc(message)}</p><div class="state-actions"><a class="admin-button secondary" href="./">بازگشت به سامانه</a></div></section></main>`;
  }
  function renderConnectionFailure(error) {
    state.access = 'unavailable';
    root.innerHTML = `<main class="state-screen" id="admin-main"><section class="state-card"><div class="state-icon danger">${icon('alert')}</div><h1>بررسی مجوز مدیر ممکن نشد</h1><p>${esc(safeErrorMessage(error))}</p><div class="state-actions"><button class="admin-button primary" type="button" data-action="retry-access">تلاش دوباره</button><a class="admin-button ghost" href="./">بازگشت به سامانه</a></div><p class="login-help">تا زمان تأیید مجوز از سمت پایگاه داده، هیچ داده مدیریتی نمایش داده نمی‌شود.</p></section></main>`;
  }

  function renderShell() {
    const title = tabs.find(tab => tab.id === state.tab)?.label || 'نمای کلی';
    const account = state.adminInfo?.email || state.user?.email || 'مدیر';
    root.innerHTML = `<div class="admin-shell ${state.collapsed ? 'sidebar-collapsed' : ''} ${state.mobileNavOpen ? 'mobile-nav-open' : ''}" id="admin-shell"><aside class="admin-sidebar" aria-label="ناوبری مدیریت"><div class="sidebar-head"><a class="sidebar-brand" href="./" aria-label="بازگشت به Barino"><span class="brand-symbol">B</span><span class="sidebar-brand-copy"><strong>Barino</strong><small>مدیریت سامانه</small></span></a><button class="sidebar-toggle" type="button" data-action="toggle-sidebar" aria-label="جمع یا بازکردن منو">${icon('arrow')}</button></div><div class="sidebar-label">فضای مدیریت</div><nav class="sidebar-nav">${tabs.map(tab => `<button type="button" class="${state.tab === tab.id ? 'active' : ''}" data-tab="${tab.id}" aria-current="${state.tab === tab.id ? 'page' : 'false'}">${icon(tab.icon)}<span class="nav-copy">${tab.label}</span></button>`).join('')}</nav><div class="sidebar-spacer"></div><div class="sidebar-profile"><span class="sidebar-avatar">${esc((account[0] || 'م').toUpperCase())}</span><span class="sidebar-account"><strong>${esc(account)}</strong><small>مدیر تأییدشده</small></span><button class="sidebar-logout" type="button" data-action="logout" aria-label="خروج از حساب">${icon('logout')}</button></div></aside><button class="nav-backdrop" type="button" data-action="close-sidebar" aria-label="بستن منو"></button><section class="admin-main"><header class="admin-topbar"><div class="topbar-left"><button class="mobile-menu" type="button" data-action="toggle-mobile-nav" aria-label="بازکردن منو">${icon('menu')}</button><div class="top-title"><strong>${esc(title)}</strong><small>فضای امن مدیریت Barino</small></div></div><div class="topbar-right"><span class="connection-pill ${state.online && state.dbConnected ? '' : 'offline'}" id="connection-pill"><i></i><span>${state.online ? (state.dbConnected ? 'سرویس متصل' : 'در انتظار اتصال') : 'بدون اینترنت'}</span></span><div class="admin-top-account"><span class="sidebar-avatar">${icon('shield')}</span><span class="top-account-copy"><strong>${esc(account)}</strong><small>نشست مدیر</small></span></div></div></header><main class="content-wrap" id="admin-main" tabindex="-1"><div id="admin-view"></div></main></section></div>`;
  }
  function updateConnectionPill() {
    const pill = $('#connection-pill');
    if (!pill) return;
    pill.classList.toggle('offline', !state.online || !state.dbConnected);
    const text = $('span', pill);
    if (text) text.textContent = !state.online ? 'بدون اینترنت' : state.dbConnected ? 'سرویس متصل' : 'در انتظار اتصال';
  }
  function heading(title, description, action = '') {
    return `<header class="page-heading"><div><h1>${esc(title)}</h1><p>${esc(description)}</p></div>${action ? `<div class="heading-actions">${action}</div>` : ''}</header>`;
  }
  function loadingView(lines = 4) {
    return `<div class="loading-block" aria-label="در حال بارگذاری">${Array.from({ length: lines }, () => '<div class="loading-line"></div>').join('')}</div>`;
  }
  function emptyView(title, text) {
    return `<div class="empty-state"><div class="state-icon">${icon('search')}</div><h3>${esc(title)}</h3><p>${esc(text)}</p></div>`;
  }
  function errorView(error) {
    return `<div class="error-banner">${icon('alert')}<p>${esc(safeErrorMessage(error))}</p></div>`;
  }
  function statusBadge(status) {
    const value = String(status || '');
    return `<span class="status-badge ${esc(value)}">${esc(statusLabel(value))}</span>`;
  }
  function roleBadge(role) { return `<span class="admin-tag">${esc(roleLabel(role))}</span>`; }
  function amount(value) { return value === null || value === undefined ? 'توافقی' : `${numberFa(value)} تومان`; }

  function metricCard(label, value, foot, iconName, tone = '') {
    return `<article class="summary-card ${tone}"><div class="summary-card-header"><span class="summary-label">${esc(label)}</span><span class="summary-icon">${icon(iconName)}</span></div><strong class="summary-value">${numberFa(value)}</strong><span class="summary-foot">${esc(foot)}</span></article>`;
  }
  function activityLabel(item) {
    if (item.event_type === 'admin_action') return actionLabels[item.description] || 'رویداد مدیریتی';
    if (item.event_type === 'load_created') return 'بار جدید ثبت شد';
    if (item.event_type === 'shipment_status') return `وضعیت سفارش به «${statusLabel(item.description)}» تغییر کرد`;
    if (item.event_type === 'report_created') return 'گزارش جدید ارسال شد';
    return 'فعالیت سامانه';
  }
  function activityList(items, limit = 8) {
    if (!items?.length) return emptyView('هنوز فعالیتی ثبت نشده است', 'فعالیت‌های جدید کاربران و مدیران پس از ثبت در اینجا نمایش داده می‌شود.');
    return `<div class="activity-list">${items.slice(0, limit).map(item => {
      const symbol = item.event_type === 'admin_action' ? 'security' : item.event_type === 'load_created' ? 'loads' : item.event_type === 'shipment_status' ? 'shipments' : 'reports';
      return `<article class="activity-item"><span class="activity-icon">${icon(symbol)}</span><div class="activity-copy"><strong>${esc(activityLabel(item))}</strong><p>${esc(item.event_type === 'admin_action' ? 'ثبت‌شده در گزارش مدیریتی' : item.actor_id ? `شناسه عامل ${shortId(item.actor_id)}` : 'رویداد سامانه')}</p></div><time class="activity-time">${esc(dateFa(item.occurred_at, true))}</time></article>`;
    }).join('')}</div>`;
  }

  async function renderOverview() {
    const target = $('#admin-view');
    if (!target) return;
    target.innerHTML = loadingView(5);
    try {
      const [summary, activity] = await Promise.all([
        callRpc('admin_get_dashboard_summary'),
        callRpc('admin_list_activity', { p_limit: 8 })
      ]);
      if (!$('#admin-view')) return;
      target.innerHTML = `${heading('نمای کلی', 'وضعیت کاربران، بارها و فعالیت‌های اخیر سامانه را بررسی کنید.', `<button class="admin-button ghost" type="button" data-action="refresh-tab">${icon('refresh')} به‌روزرسانی</button>`)}<section class="summary-grid" aria-label="آمار سامانه">${metricCard('کل کاربران', summary.users_total, 'حساب‌های ثبت‌شده', 'users')}${metricCard('رانندگان', summary.drivers_total, 'پروفایل با نقش راننده', 'truck', 'tone-blue')}${metricCard('صاحبان بار', summary.cargo_owners_total, 'پروفایل با نقش صاحب بار', 'users', 'tone-purple')}${metricCard('بارهای ثبت‌شده', summary.loads_total, `${numberFa(summary.loads_open)} مورد باز`, 'loads', 'tone-amber')}${metricCard('سفارش‌های جاری', summary.shipments_active, 'در حال انجام', 'shipments', 'tone-blue')}${metricCard('گزارش‌های باز', summary.reports_open, 'نیازمند بررسی', 'reports', 'tone-red')}</section><div class="content-grid"><section class="admin-panel"><div class="panel-heading"><div><h2>فعالیت‌های اخیر</h2><p>رویدادهای مهم ثبت‌شده در سرویس</p></div><button class="admin-button ghost small" type="button" data-tab="security">گزارش امنیت</button></div>${activityList(activity)}</section><section class="admin-panel"><div class="panel-heading"><div><h2>وضعیت سرویس</h2><p>اتصال فعلی به سرویس‌های اصلی</p></div></div><div class="health-list"><div class="health-row"><span class="health-mark">${icon('database')}</span><div><strong>پایگاه داده Supabase</strong><small>${state.dbConnected ? 'پاسخ‌گو و متصل' : 'نیازمند بررسی اتصال'}</small></div></div><div class="health-row"><span class="health-mark">${icon('mail')}</span><div><strong>Supabase Auth</strong><small>نشست مدیر تأیید شده است</small></div></div><div class="health-row"><span class="health-mark">${icon('security')}</span><div><strong>مجوز مدیر</strong><small>درخواست‌ها با عضویت دیتابیس دوباره بررسی می‌شوند</small></div></div><div class="health-row"><span class="health-mark">${icon('clock')}</span><div><strong>آخرین بررسی</strong><small>${esc(dateFa(summary.checked_at, true))}</small></div></div></div></section></div>`;
    } catch (error) {
      if (state.access === 'denied') return;
      if ($('#admin-view')) showServiceError(error);
    }
  }

  function filterToolbar(type, filters) {
    const isUsers = type === 'users';
    const statusOptions = isUsers
      ? [['all', 'همه وضعیت‌ها'], ['active', 'فعال و تأییدشده'], ['blocked', 'مسدود'], ['unverified', 'تأییدنشده']]
      : type === 'loads'
        ? [['all', 'همه وضعیت‌ها'], ['published', 'منتشرشده'], ['receiving_offers', 'دریافت پیشنهاد'], ['agreed', 'توافق‌شده'], ['awaiting_pickup', 'در انتظار بارگیری'], ['in_transit', 'در حال حمل'], ['delivered', 'تحویل‌شده'], ['cancelled', 'لغوشده']]
        : type === 'shipments'
          ? [['all', 'همه وضعیت‌ها'], ['agreed', 'توافق‌شده'], ['awaiting_pickup', 'در انتظار بارگیری'], ['in_transit', 'در حال حمل'], ['delivered', 'تحویل‌شده'], ['cancelled', 'لغوشده']]
          : [['all', 'همه وضعیت‌ها'], ['open', 'باز'], ['resolved', 'رسیدگی‌شده'], ['dismissed', 'مختومه']];
    const roleField = isUsers ? `<div class="admin-field compact"><label for="filter-role">نقش</label><select id="filter-role" class="admin-select" name="role"><option value="all" ${filters.role === 'all' ? 'selected' : ''}>همه نقش‌ها</option><option value="driver" ${filters.role === 'driver' ? 'selected' : ''}>راننده</option><option value="cargo_owner" ${filters.role === 'cargo_owner' ? 'selected' : ''}>صاحب بار</option></select></div>` : '';
    const statusField = `<div class="admin-field compact"><label for="filter-status">وضعیت</label><select id="filter-status" class="admin-select" name="status">${statusOptions.map(([value, label]) => `<option value="${value}" ${filters.status === value ? 'selected' : ''}>${label}</option>`).join('')}</select></div>`;
    const placeholder = isUsers ? 'نام، ایمیل، شماره یا شناسه' : type === 'loads' ? 'عنوان، مسیر، صاحب بار یا شناسه' : type === 'shipments' ? 'عنوان بار، مسیر یا طرفین' : 'موضوع، متن یا گزارش‌دهنده';
    return `<form class="toolbar" data-filter-form="${type}"><div class="admin-field"><label for="filter-search">جست‌وجو</label><div class="search-control">${icon('search')}<input id="filter-search" class="admin-input" name="search" value="${esc(filters.search)}" maxlength="160" placeholder="${esc(placeholder)}" autocomplete="off" /></div></div>${roleField}${statusField}<button class="admin-button primary" type="submit">اعمال فیلتر</button><button class="admin-button ghost" type="button" data-action="clear-filter" data-list="${type}">پاک‌کردن</button></form>`;
  }
  function pagination(type, total, page) {
    const pages = Math.max(1, Math.ceil(Number(total || 0) / PAGE_SIZE));
    const start = total ? (page * PAGE_SIZE) + 1 : 0;
    const end = Math.min((page + 1) * PAGE_SIZE, total || 0);
    return `<footer class="pagination"><span>نمایش ${numberFa(start)} تا ${numberFa(end)} از ${numberFa(total)} مورد</span><div class="pagination-actions"><button class="admin-button ghost small" type="button" data-action="page" data-list="${type}" data-direction="prev" ${page <= 0 ? 'disabled' : ''}>قبلی</button><span>صفحه ${numberFa(page + 1)} از ${numberFa(pages)}</span><button class="admin-button ghost small" type="button" data-action="page" data-list="${type}" data-direction="next" ${page + 1 >= pages ? 'disabled' : ''}>بعدی</button></div></footer>`;
  }
  function tableEmptyRow(columns, text) { return `<tr><td colspan="${columns}">${emptyView('موردی پیدا نشد', text)}</td></tr>`; }
  function renderListPage(type, title, description, data, rowRenderer, columns, emptyText) {
    const filters = state.filters[type];
    const rows = data?.items || [];
    const page = state.pages[type] || 0;
    const total = Number(data?.total || 0);
    const content = rows.length ? rows.map(rowRenderer).join('') : tableEmptyRow(columns, emptyText);
    return `${heading(title, description, `<button class="admin-button ghost" type="button" data-action="refresh-tab">${icon('refresh')} به‌روزرسانی</button>`)}${filterToolbar(type, filters)}<section class="table-card"><div class="table-scroll"><table class="admin-table"><thead><tr>${type === 'users' ? '<th>کاربر</th><th>نقش</th><th>وضعیت</th><th>عضویت</th><th>اقدام</th>' : type === 'loads' ? '<th>بار / مسیر</th><th>صاحب بار</th><th>وضعیت</th><th>تاریخ ثبت</th><th>اقدام</th>' : type === 'shipments' ? '<th>سفارش / مسیر</th><th>صاحب بار</th><th>راننده</th><th>وضعیت</th><th>اقدام</th>' : '<th>گزارش</th><th>گزارش‌دهنده</th><th>وضعیت</th><th>تاریخ ثبت</th><th>اقدام</th>'}</tr></thead><tbody>${content}</tbody></table></div>${pagination(type, total, page)}</section>`;
  }

  async function loadUsers() {
    const target = $('#admin-view');
    if (!target) return;
    target.innerHTML = loadingView(5);
    const filters = state.filters.users;
    try {
      const data = await callRpc('admin_list_users', { p_search: filters.search || null, p_role: filters.role, p_status: filters.status, p_limit: PAGE_SIZE, p_offset: (state.pages.users || 0) * PAGE_SIZE });
      if (!$('#admin-view')) return;
      target.innerHTML = renderListPage('users', 'مدیریت کاربران', 'مشاهده و جست‌وجوی حساب‌ها؛ نقش مدیر از این صفحه قابل تغییر نیست.', data, user => {
        const userStatus = user.is_blocked ? 'blocked' : user.email_confirmed_at ? 'active' : 'unverified';
        const mainLine = user.display_name || 'پروفایل تکمیل نشده';
        const subline = `${user.email || 'بدون ایمیل'} · ${user.phone || 'بدون شماره'}`;
        const adminTag = user.is_admin ? ' <span class="admin-tag">مدیر</span>' : '';
        const blockButton = user.is_admin ? '<span class="table-secondary">عضویت مدیر فقط با دسترسی مالک پروژه تغییر می‌کند.</span>' : `<button class="admin-button ${user.is_blocked ? 'secondary' : 'danger'} small" type="button" data-action="toggle-user" data-user-id="${esc(user.user_id)}" data-blocked="${user.is_blocked ? 'true' : 'false'}">${user.is_blocked ? 'رفع مسدودی' : 'مسدودسازی'}</button>`;
        return `<tr><td><span class="table-primary">${esc(mainLine)}${adminTag}</span><span class="table-secondary" dir="ltr">${esc(subline)}</span></td><td>${roleBadge(user.role)}</td><td>${statusBadge(userStatus)}</td><td><span class="table-primary">${esc(dateFa(user.created_at))}</span><span class="table-secondary">ورود اخیر: ${esc(dateFa(user.last_sign_in_at))}</span></td><td><div class="table-actions"><button class="admin-button ghost small" type="button" data-action="user-detail" data-user-id="${esc(user.user_id)}">جزئیات</button>${blockButton}</div></td></tr>`;
      }, 5, 'با این فیلتر کاربری پیدا نشد.');
    } catch (error) { if (state.access !== 'denied' && $('#admin-view')) showServiceError(error); }
  }
  async function loadLoads() {
    const target = $('#admin-view');
    if (!target) return;
    target.innerHTML = loadingView(5);
    const filters = state.filters.loads;
    try {
      const data = await callRpc('admin_list_loads', { p_search: filters.search || null, p_status: filters.status, p_limit: PAGE_SIZE, p_offset: (state.pages.loads || 0) * PAGE_SIZE });
      if (!$('#admin-view')) return;
      target.innerHTML = renderListPage('loads', 'مدیریت بارها', 'جست‌وجوی بارهای ثبت‌شده و غیرفعال‌سازی مورد نامعتبر؛ حذف دائمی انجام نمی‌شود.', data, load => {
        const route = `${load.origin_city || '—'} ← ${load.destination_city || '—'}`;
        const deactivate = ['published', 'receiving_offers'].includes(load.status) ? `<button class="admin-button danger small" type="button" data-action="cancel-load" data-load-id="${esc(load.load_id)}" data-load-title="${esc(load.title)}">غیرفعال‌سازی</button>` : '';
        return `<tr><td><span class="table-primary">${esc(load.title || 'بار بدون عنوان')}</span><span class="table-secondary">${esc(route)} · ${esc(amount(load.proposed_fare))}</span></td><td><span class="table-primary">${esc(load.owner_name || '—')}</span><span class="table-secondary">${esc(load.owner_email || '')}</span></td><td>${statusBadge(load.status)}</td><td>${esc(dateFa(load.created_at))}</td><td><div class="table-actions"><button class="admin-button ghost small" type="button" data-action="load-detail" data-load-id="${esc(load.load_id)}">جزئیات</button>${deactivate}</div></td></tr>`;
      }, 5, 'با این فیلتر باری پیدا نشد.');
    } catch (error) { if (state.access !== 'denied' && $('#admin-view')) showServiceError(error); }
  }
  async function loadShipments() {
    const target = $('#admin-view');
    if (!target) return;
    target.innerHTML = loadingView(5);
    const filters = state.filters.shipments;
    try {
      const data = await callRpc('admin_list_shipments', { p_search: filters.search || null, p_status: filters.status, p_limit: PAGE_SIZE, p_offset: (state.pages.shipments || 0) * PAGE_SIZE });
      if (!$('#admin-view')) return;
      target.innerHTML = renderListPage('shipments', 'مدیریت سفارش‌ها', 'نمایش وضعیت حمل و اطلاعات لازم برای پیگیری سفارش‌ها.', data, shipment => {
        const route = `${shipment.origin_city || '—'} ← ${shipment.destination_city || '—'}`;
        return `<tr><td><span class="table-primary">${esc(shipment.load_title || 'سفارش حمل')}</span><span class="table-secondary">${esc(route)} · ${esc(amount(shipment.agreed_fare))}</span></td><td><span class="table-primary">${esc(shipment.owner_name || '—')}</span><span class="table-secondary">${esc(shipment.owner_email || '')}</span></td><td><span class="table-primary">${esc(shipment.driver_name || '—')}</span><span class="table-secondary">${esc(shipment.driver_email || '')}</span></td><td>${statusBadge(shipment.status)}</td><td><span class="table-primary">${esc(dateFa(shipment.created_at))}</span><span class="table-secondary" dir="ltr">${esc(shortId(shipment.shipment_id))}</span></td></tr>`;
      }, 5, 'با این فیلتر سفارشی پیدا نشد.');
    } catch (error) { if (state.access !== 'denied' && $('#admin-view')) showServiceError(error); }
  }
  async function loadReports() {
    const target = $('#admin-view');
    if (!target) return;
    target.innerHTML = loadingView(5);
    const filters = state.filters.reports;
    try {
      const data = await callRpc('admin_list_reports', { p_search: filters.search || null, p_status: filters.status, p_limit: PAGE_SIZE, p_offset: (state.pages.reports || 0) * PAGE_SIZE });
      if (!$('#admin-view')) return;
      target.innerHTML = renderListPage('reports', 'مدیریت گزارش‌ها', 'گزارش‌های کاربران را بررسی و نتیجه رسیدگی را ثبت کنید.', data, report => {
        const resolveActions = report.status === 'open' ? `<button class="admin-button secondary small" type="button" data-action="resolve-report" data-resolution="resolved" data-report-id="${esc(report.report_id)}">رسیدگی شد</button><button class="admin-button ghost small" type="button" data-action="resolve-report" data-resolution="dismissed" data-report-id="${esc(report.report_id)}">مختومه</button>` : '';
        return `<tr><td><span class="table-primary">${esc(report.subject)}</span><span class="table-secondary">${esc(report.description)}</span></td><td><span class="table-primary">${esc(report.reporter_name || '—')}</span><span class="table-secondary">${esc(report.reporter_email || '')}</span></td><td>${statusBadge(report.status)}</td><td>${esc(dateFa(report.created_at))}</td><td><div class="table-actions"><button class="admin-button ghost small" type="button" data-action="report-detail" data-report-id="${esc(report.report_id)}">جزئیات</button>${resolveActions}</div></td></tr>`;
      }, 5, 'گزارشی برای نمایش نیست.');
    } catch (error) { if (state.access !== 'denied' && $('#admin-view')) showServiceError(error); }
  }

  async function renderSecurity() {
    const target = $('#admin-view');
    if (!target) return;
    target.innerHTML = loadingView(4);
    try {
      const events = await callRpc('admin_list_activity', { p_limit: 30 });
      if (!$('#admin-view')) return;
      const expires = dateFromUnix(state.session?.expires_at);
      target.innerHTML = `${heading('امنیت و نشست', 'وضعیت نشست فعلی مدیر و رویدادهای مهم ثبت‌شده در دیتابیس.', `<button class="admin-button ghost" type="button" data-action="refresh-tab">${icon('refresh')} به‌روزرسانی</button>`)}<section class="admin-panel"><div class="panel-heading"><div><h2>نشست مدیریتی فعلی</h2><p>اطلاعاتی که در نشست احراز هویت جاری در دسترس است.</p></div>${statusBadge('active')}</div><div class="session-grid"><div class="session-detail"><span>حساب تأییدشده</span><strong>${esc(state.adminInfo?.email || '—')}</strong></div><div class="session-detail"><span>شناسه نشست کاربر</span><strong dir="ltr">${esc(state.adminInfo?.user_id || '—')}</strong></div><div class="session-detail"><span>تأیید ایمیل</span><strong>${state.adminInfo?.email_verified ? 'تأیید شده' : 'تأیید نشده'}</strong></div><div class="session-detail"><span>انقضای نشست محلی</span><strong>${esc(expires)}</strong></div><div class="session-detail"><span>اتصال دیتابیس</span><strong>${state.dbConnected ? 'متصل' : 'نیازمند بررسی'}</strong></div><div class="session-detail"><span>آخرین تأیید مجوز سمت سرور</span><strong>${esc(dateFa(state.adminInfo?.checked_at, true))}</strong></div></div><div class="security-note">${icon('shield')}<span>هر درخواست مدیریتی در PostgreSQL دوباره با عضویت خصوصی مدیر و فعال‌بودن حساب بررسی می‌شود. خروج از این پنل نشست Supabase را خاتمه می‌دهد.</span></div></section><section class="admin-panel stacked"><div class="panel-heading"><div><h2>رویدادهای مدیریتی و فعالیت</h2><p>رمز عبور، access token و refresh token در این گزارش ذخیره نمی‌شوند.</p></div></div>${activityList(events, 30)}</section>`;
    } catch (error) { if (state.access !== 'denied' && $('#admin-view')) showServiceError(error); }
  }
  function renderSettings() {
    const config = window.BARINO_SUPABASE_CONFIG;
    let projectHost = 'نامشخص';
    try { projectHost = new URL(config.url).host; } catch (_) { /* پیکربندی پس از ورود بررسی می‌شود. */ }
    const rows = [
      ['نسخه پنل', APP_VERSION],
      ['میزبانی رابط', 'GitHub Pages / فایل‌های استاتیک'],
      ['بک‌اند و پایگاه داده', 'Supabase Auth + PostgreSQL + RLS'],
      ['نشانی عمومی پروژه', projectHost],
      ['کلید محرمانه سمت سرور', 'در مرورگر وجود ندارد و این پنل به آن نیاز ندارد'],
      ['وضعیت اتصال در این نشست', state.dbConnected ? 'متصل' : 'در انتظار بررسی'],
      ['حساب مدیر جاری', state.adminInfo?.email || '—']
    ];
    return `${heading('تنظیمات سرویس', 'وضعیت پیکربندی غیرحساس و معماری پنل مدیریت.', `<button class="admin-button ghost" type="button" data-action="refresh-tab">${icon('refresh')} بررسی اتصال</button>`)}<section class="admin-panel"><div class="panel-heading"><div><h2>وضعیت اتصال و نسخه</h2><p>این بخش فقط وضعیت را نمایش می‌دهد و تنظیم امنیتی را از مرورگر تغییر نمی‌دهد.</p></div></div><div class="settings-list">${rows.map(([label, value]) => `<div class="settings-row"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`).join('')}</div><div class="security-note">${icon('shield')}<span>برای GitHub Pages هیچ بک‌اند Node دائمی لازم نیست: احراز هویت در Supabase Auth و مجوزدهی/عملیات مدیریتی در RPC و RLS پایگاه داده اجرا می‌شود.</span></div></section>`;
  }

  async function loadTab(tab = state.tab) {
    if (state.access !== 'admin') return;
    state.tab = tabs.some(item => item.id === tab) ? tab : 'overview';
    if (!$('#admin-shell')) renderShell();
    else {
      document.querySelectorAll('[data-tab]').forEach(button => {
        const active = button.dataset.tab === state.tab;
        button.classList.toggle('active', active);
        button.setAttribute('aria-current', active ? 'page' : 'false');
      });
      const title = $('.top-title strong');
      if (title) title.textContent = tabs.find(item => item.id === state.tab)?.label || 'نمای کلی';
      const shell = $('#admin-shell');
      shell?.classList.remove('mobile-nav-open');
      state.mobileNavOpen = false;
    }
    if (state.tab === 'overview') return renderOverview();
    if (state.tab === 'users') return loadUsers();
    if (state.tab === 'loads') return loadLoads();
    if (state.tab === 'shipments') return loadShipments();
    if (state.tab === 'reports') return loadReports();
    if (state.tab === 'security') return renderSecurity();
    const target = $('#admin-view');
    if (target) target.innerHTML = renderSettings();
  }

  async function verifyAdmin() {
    if (state.verifying) return state.verifying;
    if (!state.client) return false;
    state.verifying = (async () => {
      const wasAuthorized = state.access === 'admin' && Boolean($('#admin-shell'));
      const { data, error } = await state.client.rpc('admin_get_session_info');
      if (error) {
        state.dbConnected = false;
        updateConnectionPill();
        if (isAccessError(error)) {
          state.access = 'denied';
          state.adminInfo = null;
          renderDenied();
        } else {
          renderConnectionFailure(error);
        }
        return false;
      }
      state.dbConnected = true;
      state.adminInfo = data;
      state.access = 'admin';
      updateConnectionPill();
      if (!wasAuthorized) {
        renderShell();
        await loadTab(state.tab);
      }
      return true;
    })();
    try { return await state.verifying; }
    finally { state.verifying = null; }
  }

  async function signOut() {
    if (!state.client) { renderLogin(); return; }
    try {
      const { error } = await state.client.auth.signOut({ scope: 'local' });
      if (error) throw error;
      state.user = null;
      state.session = null;
      state.adminInfo = null;
      state.access = 'login';
      state.dbConnected = false;
      closeModal();
      renderLogin();
      toast('از نشست مدیریتی خارج شدید.');
    } catch (error) {
      toast(safeErrorMessage(error), 'error');
    }
  }

  async function showUserDetail(userId) {
    try {
      const user = await callRpc('admin_get_user_detail', { p_user_id: userId });
      const fields = [
        ['ایمیل', user.email || '—'], ['شناسه کاربر', user.user_id || '—'], ['نقش حساب', roleLabel(user.role)],
        ['وضعیت', user.is_blocked ? 'مسدود' : user.email_confirmed_at ? 'فعال و تأییدشده' : 'ایمیل تأییدنشده'],
        ['ایمیل تأییدشده در', dateFa(user.email_confirmed_at, true)], ['آخرین ورود', dateFa(user.last_sign_in_at, true)],
        ['نام', user.display_name || '—'], ['شماره تماس', user.phone || '—'], ['شهر', user.city || '—'],
        ['نوع کامیون', user.truck_type || '—'], ['مدل کامیون', user.truck_model || '—'], ['پلاک', user.plate_number || '—'],
        ['تاریخ عضویت', dateFa(user.created_at, true)], ['مدیر پروژه', user.is_admin ? 'بله — عضویت فقط توسط مالک تغییر می‌کند' : 'خیر']
      ];
      showModal('جزئیات حساب کاربری', user.display_name || user.email || shortId(user.user_id), `<div class="detail-grid">${fields.map(([label, value]) => `<div class="detail-cell"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`).join('')}</div>`);
    } catch (error) { if (state.access !== 'denied') toast(safeErrorMessage(error), 'error'); }
  }
  async function showLoadDetail(loadId) {
    try {
      const data = await callRpc('admin_get_load_detail', { p_load_id: loadId });
      const load = data.load || {};
      const owner = data.owner || {};
      const details = data.private_details || {};
      const fields = [
        ['عنوان بار', load.title], ['وضعیت', statusLabel(load.status)], ['مبدأ', load.origin_city], ['مقصد', load.destination_city],
        ['وزن', `${numberFa(load.weight_value)} ${load.weight_unit || ''}`], ['نوع بار', load.cargo_type],
        ['نوع کامیون موردنیاز', load.required_truck_type], ['کرایه پیشنهادی', amount(load.proposed_fare)],
        ['تاریخ بارگیری', dateFa(load.loading_date)], ['زمان ثبت', dateFa(load.created_at, true)],
        ['صاحب بار', owner.display_name], ['ایمیل صاحب بار', owner.email], ['شماره تماس', owner.phone],
        ['نشانی بارگیری', details.pickup_address], ['نشانی تخلیه', details.delivery_address]
      ];
      const wideFields = new Set(['نشانی بارگیری', 'نشانی تخلیه']);
      const content = `<div class="detail-grid">${fields.map(([label, value]) => `<div class="detail-cell ${wideFields.has(label) ? 'wide' : ''}"><span>${esc(label)}</span><strong>${esc(value || '—')}</strong></div>`).join('')}</div>${load.cargo_description ? `<section class="modal-section"><h3>توضیحات محموله</h3><p>${esc(load.cargo_description)}</p></section>` : ''}${load.notes ? `<section class="modal-section"><h3>یادداشت</h3><p>${esc(load.notes)}</p></section>` : ''}`;
      const actions = ['published', 'receiving_offers'].includes(load.status) ? `<button class="admin-button danger" type="button" data-action="cancel-load" data-load-id="${esc(loadId)}" data-load-title="${esc(load.title)}">غیرفعال‌سازی بار</button>` : '';
      showModal('جزئیات بار', load.title || shortId(loadId), content, actions);
    } catch (error) { if (state.access !== 'denied') toast(safeErrorMessage(error), 'error'); }
  }
  async function showReportDetail(reportId) {
    try {
      const row = await callRpc('admin_get_report_detail', { p_report_id: reportId });
      showModal('جزئیات گزارش', row.subject || 'گزارش کاربر', `<div class="detail-grid"><div class="detail-cell"><span>گزارش‌دهنده</span><strong>${esc(row.reporter_name || '—')}</strong></div><div class="detail-cell"><span>ایمیل</span><strong>${esc(row.reporter_email || '—')}</strong></div><div class="detail-cell"><span>وضعیت</span><strong>${esc(statusLabel(row.status))}</strong></div><div class="detail-cell"><span>زمان ثبت</span><strong>${esc(dateFa(row.created_at, true))}</strong></div><div class="detail-cell"><span>شناسه گزارش</span><strong dir="ltr">${esc(row.report_id)}</strong></div><div class="detail-cell"><span>مورد مرتبط</span><strong dir="ltr">${esc(row.target_id || '—')}</strong></div></div><section class="modal-section"><h3>شرح گزارش</h3><p>${esc(row.description || 'بدون شرح')}</p></section>`);
    } catch (error) { if (state.access !== 'denied') toast(safeErrorMessage(error), 'error'); }
  }
  async function confirmBlockUser(button) {
    const userId = button.dataset.userId;
    const blocked = button.dataset.blocked === 'true';
    const label = blocked ? 'رفع مسدودی این کاربر انجام شود؟' : 'این حساب مسدود و دسترسی عملیاتی آن در دیتابیس رد شود؟';
    if (!window.confirm(label)) return;
    button.disabled = true;
    try {
      await callRpc('admin_set_user_blocked', { p_user_id: userId, p_blocked: !blocked });
      toast(blocked ? 'مسدودی کاربر برداشته شد.' : 'کاربر مسدود شد.');
      await loadUsers();
    } catch (error) {
      if (state.access !== 'denied') toast(safeErrorMessage(error), 'error');
      button.disabled = false;
    }
  }
  async function confirmCancelLoad(button) {
    const loadId = button.dataset.loadId;
    const title = button.dataset.loadTitle || 'این بار';
    if (!window.confirm(`«${title}» غیرفعال شود؟ بار به‌صورت نرم لغو می‌شود؛ حذف دائمی انجام نمی‌شود و پیشنهادهای باز مختومه خواهند شد.`)) return;
    button.disabled = true;
    try {
      await callRpc('admin_cancel_load', { p_load_id: loadId });
      closeModal();
      toast('بار غیرفعال شد و رویداد در گزارش مدیریتی ثبت شد.');
      await loadLoads();
    } catch (error) {
      if (state.access !== 'denied') toast(safeErrorMessage(error), 'error');
      button.disabled = false;
    }
  }
  async function confirmResolveReport(button) {
    const reportId = button.dataset.reportId;
    const resolution = button.dataset.resolution;
    const label = resolution === 'dismissed' ? 'این گزارش بدون اقدام بیشتر مختومه شود؟' : 'رسیدگی به این گزارش ثبت شود؟';
    if (!window.confirm(label)) return;
    button.disabled = true;
    try {
      await callRpc('admin_resolve_report', { p_report_id: reportId, p_resolution: resolution });
      closeModal();
      toast(resolution === 'dismissed' ? 'گزارش مختومه شد.' : 'رسیدگی به گزارش ثبت شد.');
      await loadReports();
    } catch (error) {
      if (state.access !== 'denied') toast(safeErrorMessage(error), 'error');
      button.disabled = false;
    }
  }
  function readLoginError(error) {
    if (/email not confirmed/i.test(String(error?.message || ''))) return 'ابتدا ایمیل خود را از طریق پیام Supabase تأیید کنید.';
    if (/invalid login credentials/i.test(String(error?.message || ''))) return 'اطلاعات ورود درست نیست یا حساب در Supabase Auth فعال نیست.';
    if (!state.online || /network|fetch/i.test(String(error?.message || ''))) return 'ارتباط با سرویس احراز هویت برقرار نشد. اتصال اینترنت را بررسی کنید.';
    return 'ورود انجام نشد. وضعیت حساب و تنظیمات Supabase را بررسی کنید.';
  }
  async function handleLogin(form) {
    const email = String(new FormData(form).get('email') || '').trim().toLowerCase();
    const password = String(new FormData(form).get('password') || '');
    const button = $('#login-submit', form);
    const errorBox = $('#login-error', form);
    if (!email || !password) {
      errorBox.textContent = 'ایمیل و رمز عبور را وارد کنید.';
      errorBox.classList.add('visible');
      return;
    }
    button.disabled = true;
    button.textContent = 'در حال بررسی…';
    errorBox.classList.remove('visible');
    try {
      const { data, error } = await state.client.auth.signInWithPassword({ email, password });
      if (error) throw error;
      state.user = data.user;
      state.session = data.session;
      await verifyAdmin();
    } catch (error) {
      if (state.access !== 'denied') {
        const currentBox = $('#login-error');
        if (currentBox) {
          currentBox.textContent = readLoginError(error);
          currentBox.classList.add('visible');
          const currentButton = $('#login-submit');
          if (currentButton) { currentButton.disabled = false; currentButton.innerHTML = `ورود امن ${icon('arrow')}`; }
        }
      }
    }
  }
  function setFilterFromForm(form) {
    const type = form.dataset.filterForm;
    if (!state.filters[type]) return;
    const values = new FormData(form);
    state.filters[type] = { ...state.filters[type], search: String(values.get('search') || '').trim() };
    if (type === 'users') state.filters[type].role = String(values.get('role') || 'all');
    state.filters[type].status = String(values.get('status') || 'all');
    state.pages[type] = 0;
    loadTab(type);
  }
  function clearFilter(type) {
    if (!state.filters[type]) return;
    state.filters[type] = type === 'users' ? { search: '', role: 'all', status: 'all' } : { search: '', status: 'all' };
    state.pages[type] = 0;
    loadTab(type);
  }
  function changePage(type, direction) {
    if (!state.pages.hasOwnProperty(type)) return;
    if (direction === 'prev') state.pages[type] = Math.max(0, state.pages[type] - 1);
    else state.pages[type] += 1;
    loadTab(type);
  }

  document.addEventListener('submit', event => {
    const form = event.target;
    if (!(form instanceof HTMLFormElement)) return;
    if (form.id === 'admin-login-form') {
      event.preventDefault();
      handleLogin(form);
      return;
    }
    if (form.dataset.filterForm) {
      event.preventDefault();
      setFilterFromForm(form);
    }
  });

  document.addEventListener('click', async event => {
    const button = event.target.closest('button,a');
    if (!button) {
      if (event.target.classList?.contains('modal-root')) closeModal();
      return;
    }
    if (button.dataset.tab) { await loadTab(button.dataset.tab); return; }
    const action = button.dataset.action;
    if (!action) return;
    if (action === 'toggle-sidebar') {
      state.collapsed = !state.collapsed;
      $('#admin-shell')?.classList.toggle('sidebar-collapsed', state.collapsed);
      return;
    }
    if (action === 'toggle-mobile-nav') {
      state.mobileNavOpen = !state.mobileNavOpen;
      $('#admin-shell')?.classList.toggle('mobile-nav-open', state.mobileNavOpen);
      return;
    }
    if (action === 'close-sidebar') {
      state.mobileNavOpen = false;
      $('#admin-shell')?.classList.remove('mobile-nav-open');
      return;
    }
    if (action === 'toggle-password') {
      const input = $('#admin-password');
      if (!input) return;
      const reveal = input.type === 'password';
      input.type = reveal ? 'text' : 'password';
      button.setAttribute('aria-pressed', String(reveal));
      button.setAttribute('aria-label', reveal ? 'پنهان‌کردن رمز عبور' : 'نمایش رمز عبور');
      button.innerHTML = icon(reveal ? 'eyeOff' : 'eye');
      return;
    }
    if (action === 'logout') { await signOut(); return; }
    if (action === 'modal-close') { closeModal(); return; }
    if (action === 'refresh-tab' || action === 'retry-tab') { await loadTab(state.tab); return; }
    if (action === 'retry-access') { await verifyAdmin(); return; }
    if (action === 'clear-filter') { clearFilter(button.dataset.list); return; }
    if (action === 'page') { changePage(button.dataset.list, button.dataset.direction); return; }
    if (action === 'user-detail') { await showUserDetail(button.dataset.userId); return; }
    if (action === 'toggle-user') { await confirmBlockUser(button); return; }
    if (action === 'load-detail') { await showLoadDetail(button.dataset.loadId); return; }
    if (action === 'cancel-load') { await confirmCancelLoad(button); return; }
    if (action === 'report-detail') { await showReportDetail(button.dataset.reportId); return; }
    if (action === 'resolve-report') { await confirmResolveReport(button); return; }
  });

  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      closeModal();
      state.mobileNavOpen = false;
      $('#admin-shell')?.classList.remove('mobile-nav-open');
    }
  });

  async function init() {
    const config = window.BARINO_SUPABASE_CONFIG;
    if (!config?.url || !config?.anonKey || String(config.url).includes('YOUR_') || String(config.anonKey).includes('YOUR_')) {
      renderConfigurationError('فایل supabase-config.js باید نشانی پروژه و کلید عمومی مرورگر را داشته باشد. کلید service_role را وارد نکنید.');
      return;
    }
    if (!window.supabase?.createClient) {
      renderConfigurationError('کتابخانه Supabase بارگذاری نشد. اتصال شبکه یا CSP صفحه را بررسی کنید.');
      return;
    }
    try {
      state.client = window.supabase.createClient(config.url, config.anonKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false, flowType: 'pkce' }
      });
      const { data: { subscription } } = state.client.auth.onAuthStateChange((event, session) => {
        window.setTimeout(() => {
          state.session = session || null;
          state.user = session?.user || null;
          if (event === 'SIGNED_OUT' || !session) {
            state.adminInfo = null;
            state.access = 'login';
            state.dbConnected = false;
            closeModal();
            renderLogin();
            return;
          }
          if (['SIGNED_IN', 'TOKEN_REFRESHED', 'USER_UPDATED', 'INITIAL_SESSION'].includes(event)) verifyAdmin();
        }, 0);
      });
      state.subscription = subscription;
      const { data, error } = await state.client.auth.getSession();
      if (error) throw error;
      state.session = data.session || null;
      state.user = data.session?.user || null;
      if (state.session) await verifyAdmin();
      else renderLogin();
      window.setInterval(() => {
        if (state.access === 'admin' && state.online) verifyAdmin();
      }, 15000);
    } catch (error) {
      renderConnectionFailure(error);
    }
  }

  window.addEventListener('online', () => {
    state.online = true;
    updateConnectionPill();
    if (state.access === 'admin') verifyAdmin();
  });
  window.addEventListener('offline', () => {
    state.online = false;
    updateConnectionPill();
  });
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && state.access === 'admin') verifyAdmin();
  });

  init();
})();
