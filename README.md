<a id="Barino"></a>
<h1 align="center">Barino</h1>

<p align="center" dir="rtl"><strong>بارینو — تجربه‌ای امن و موبایل‌محور برای اتصال صاحبان بار و رانندگان کامیون در ایران</strong></p>

<p align="center">
  <a href="https://github.com/arshia8058/Barino"><img alt="Repository" src="https://img.shields.io/badge/repository-arshia8058%2FBarino-181717?style=flat-square&logo=github&logoColor=white" /></a>
  <a href="https://github.com/arshia8058/Barino/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/arshia8058/Barino/main?style=flat-square&label=last%20commit&logo=github" /></a>
  <a href="https://arshia8058.github.io/Barino/"><img alt="GitHub Pages live" src="https://img.shields.io/badge/GitHub%20Pages-live-222222?style=flat-square&logo=githubpages&logoColor=white" /></a>
  <a href="https://developer.mozilla.org/docs/Web/HTML"><img alt="HTML5" src="https://img.shields.io/badge/HTML5-E34F26?style=flat-square&logo=html5&logoColor=white" /></a>
  <a href="https://developer.mozilla.org/docs/Web/CSS"><img alt="CSS3" src="https://img.shields.io/badge/CSS3-1572B6?style=flat-square&logo=css3&logoColor=white" /></a>
  <a href="https://developer.mozilla.org/docs/Web/JavaScript"><img alt="JavaScript" src="https://img.shields.io/badge/JavaScript-323330?style=flat-square&logo=javascript&logoColor=F7DF1E" /></a>
  <a href="https://supabase.com/"><img alt="Supabase" src="https://img.shields.io/badge/Supabase-3ECF8E?style=flat-square&logo=supabase&logoColor=white" /></a>
</p>

<p align="center" dir="rtl">
  <a href="https://arshia8058.github.io/Barino/">مشاهده نسخه زنده</a> ·
  <a href="https://github.com/arshia8058/Barino">کد منبع</a> ·
  <a href="#quick-start">راه‌اندازی</a> ·
  <a href="#supabase-setup">تنظیمات Supabase</a>
</p>

> **یادداشت نام‌گذاری:** نام مخزن **Barino** است و محصولی که کاربر در رابط می‌بیند با برند فارسی **«بارینو»** نمایش داده می‌شود.

<a id="overview"></a>
## ✨ Barino چیست؟

Barino یک وب‌اپلیکیشن فارسی، راست‌به‌چپ و **Mobile-First** است که فرایند یافتن بار، ثبت پیشنهاد کرایه و پیگیری حمل را میان صاحبان بار و رانندگان کامیون ساده‌تر می‌کند. رابط کاربری به‌صورت یک SPA استاتیک با HTML، CSS و JavaScript اجرا می‌شود؛ احراز هویت، داده‌های پایدار، قوانین دسترسی و عملیات حساس در **Supabase** قرار دارند.

هدف پروژه فقط نمایش یک رابط زیبا نیست: اطلاعات خصوصی مسیر و تماس از داده‌های عمومی جدا می‌شوند، پذیرش پیشنهاد در تراکنش دیتابیس انجام می‌شود و تصمیم‌های دسترسی به سیاست‌های RLS و RPCهای محافظت‌شده سپرده شده‌اند.

### وضعیت قابل‌تأیید مخزن

| مورد | وضعیت فعلی |
|---|---|
| نسخه عمومی | [GitHub Pages](https://arshia8058.github.io/Barino/) از `main` و مسیر `/(root)` منتشر شده است. |
| معماری اجرا | فرانت‌اند استاتیک؛ هیچ سرور Node.js یا بک‌اند دائمی سفارشی ندارد. |
| اتصال داده | فایل `supabase-config.js` شامل پیکربندی **عمومی مرورگر** برای Supabase است. |
| طرح دیتابیس | Schema، migrationها، RLS، triggerها و RPCها در مخزن وجود دارند. |
| استقرار Schema | workflow دستی GitHub Actions برای اجرای migrationها وجود دارد. |
| تست خودکار سرتاسری | در این مخزن suite مستقل E2E وجود ندارد؛ رفتار نهایی Auth و RLS باید با حساب‌های آزمایشی در پروژه Supabase بررسی شود. |

> پیش‌نمایش تصویری یا GIF واقعی در مخزن نگهداری نشده است؛ برای جلوگیری از تصویر ساختگی، تنها [نسخه زنده](https://arshia8058.github.io/Barino/) معرفی می‌شود.

<a id="contents"></a>
## 🧭 فهرست مطالب

| بخش | آنچه می‌خوانید |
|---|---|
| [امکانات](#features) | قابلیت‌های واقعی راننده، صاحب بار، مدیر و رابط کاربری |
| [فناوری‌ها](#stack) | اجزای فرانت‌اند، Supabase و انتشار |
| [اجرای سریع](#quick-start) | مشاهده محلی بدون ابزار اضافی |
| [تنظیمات Supabase](#supabase-setup) | پیکربندی عمومی مرورگر، Auth، Schema و مدیر اول |
| [انتشار GitHub Pages](#github-pages) | روش انتشار و نکات موبایل |
| [ساختار پروژه](#structure) | نقش فایل‌ها و پوشه‌های اصلی |
| [امنیت](#security) | مرزهای دسترسی و مواردی که نباید افشا شوند |
| [عیب‌یابی](#troubleshooting) | خطاهای متداول و راه‌حل‌های دقیق |
| [مشارکت](#contributing) | پیشنهاد تغییرات و Pull Request |
| [مجوز](#license) | وضعیت فعلی مجوز پروژه |

<a id="features"></a>
## 🚚 امکانات پیاده‌سازی‌شده

<table dir="rtl">
  <thead>
    <tr><th align="right">حوزه</th><th align="right">قابلیت‌های موجود در کد</th></tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>🔐 حساب کاربری</strong></td>
      <td>ثبت‌نام و ورود ایمیلی، تأیید ایمیل، ارسال دوباره لینک با شمارش معکوس، بازیابی و تغییر رمز عبور، خروج و نگه‌داری نشست.</td>
    </tr>
    <tr>
      <td><strong>🪪 نقش‌ها و پروفایل</strong></td>
      <td>انتخاب نقش راننده یا صاحب بار هنگام ثبت‌نام، تکمیل نام، موبایل ایران، شهر و مشخصات کامیون برای راننده.</td>
    </tr>
    <tr>
      <td><strong>🔎 راننده</strong></td>
      <td>مشاهده و فیلتر بارهای فعال بر پایه مبدأ، مقصد، نوع بار، نوع کامیون و بازه کرایه؛ ثبت یک پیشنهاد برای هر بار؛ مشاهده پیشنهادها و سفارش‌ها.</td>
    </tr>
    <tr>
      <td><strong>📦 صاحب بار</strong></td>
      <td>ثبت بار همراه با نشانی خصوصی، ویرایش یا لغو پیش از توافق، مشاهده پیشنهادها و پذیرش اتمیک یک پیشنهاد.</td>
    </tr>
    <tr>
      <td><strong>🧭 حمل و پیگیری</strong></td>
      <td>ساخت shipment، تاریخچه وضعیت و انتقال مرحله‌ای «توافق‌شده → در انتظار بارگیری → در حال حمل → تحویل‌شده» مطابق نقش مجاز.</td>
    </tr>
    <tr>
      <td><strong>🛡️ مدیریت</strong></td>
      <td>نمایش آمار، کاربران، بارها، سفارش‌ها و گزارش‌ها؛ مسدود/رفع‌مسدودی کاربر و مختومه‌کردن گزارش برای مدیرِ مورد اعتماد دیتابیس.</td>
    </tr>
    <tr>
      <td><strong>✨ تجربه کاربری</strong></td>
      <td>رابط فارسی RTL، طراحی واکنش‌گرا، نوار ناوبری پایین در موبایل، اعتبارسنجی فرم، loading، empty state، offline state، toast و پشتیبانی از کاهش حرکت.</td>
    </tr>
  </tbody>
</table>

### آنچه عمداً در پروژه وجود ندارد

- ورود پیامکی نمایشی یا SMS ساختگی
- OAuth نمایشی یا اتصال پرداخت واقعی
- کلید `service_role`، رمز دیتابیس یا backend دائمی سفارشی در مرورگر
- ادعای تست‌شدن همه سناریوهای واقعی روی هر حساب Supabase

<a id="stack"></a>
## 🧩 فناوری‌ها و معماری

| لایه | فناوری | نقش |
|---|---|---|
| رابط کاربری | HTML5، CSS3، JavaScript بدون فریم‌ورک | SPA سبک، RTL و Mobile-First |
| کلاینت Auth/Data | `@supabase/supabase-js@2.118.0` از CDN | Auth، REST، RPC و نشست کاربر |
| احراز هویت | Supabase Auth | ایمیل/رمز، تأیید ایمیل، بازیابی رمز و PKCE |
| داده | Supabase PostgreSQL | profiles، loads، offers، shipments و reports |
| مجوزدهی | PostgreSQL RLS، trigger و `SECURITY DEFINER` RPC | اعمال مجوز در دیتابیس، نه فقط در UI |
| انتشار سایت | GitHub Pages | میزبانی فایل‌های استاتیک از `main` |
| استقرار Schema | GitHub Actions + Supabase CLI | اجرای دستی migrationها با secret مخزن |

<a id="quick-start"></a>
## ⚡ اجرای سریع

### پیش‌نیاز حداقلی

- یک مرورگر مدرن
- Python 3 **یا** هر static file server ساده، فقط برای مشاهده محلی
- Node.js، npm، build step و سرور دائمی برای اجرای رابط لازم نیستند.

```bash
# 1) دریافت پروژه
git clone https://github.com/arshia8058/Barino.git
cd Barino

# 2) اجرای یک سرور محلی استاتیک
python3 -m http.server 8080 --bind 0.0.0.0
```

سپس `http://localhost:8080/` را باز کنید.

> این دستور فقط فایل‌ها را نمایش می‌دهد. برای ثبت‌نام، دریافت داده و عملیات واقعی باید Supabase مطابق بخش بعدی پیکربندی شود. اگر روی localhost جریان ایمیل را می‌آزمایید، URLهای redirect محلی را نیز در تنظیمات Supabase اضافه کنید.

### اجرای مستقیم نسخه منتشرشده

برای مشاهده بدون نصب چیزی، [نسخه GitHub Pages](https://arshia8058.github.io/Barino/) را باز کنید.

<a id="supabase-setup"></a>
## 🟩 تنظیمات Supabase

### ۱) پیکربندی عمومی مرورگر

این پروژه از متغیر محیطی runtime یا فایل `.env` در GitHub Pages استفاده نمی‌کند. پیکربندی کلاینت از شیء زیر خوانده می‌شود:

```js
window.BARINO_SUPABASE_CONFIG = {
  url: 'https://YOUR_PROJECT_REF.supabase.co',
  anonKey: 'YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY'
};
```

| کلید | کاربرد | محل صحیح |
|---|---|---|
| `url` | Project URL پروژه Supabase | `supabase-config.js` |
| `anonKey` | Publishable key یا anon key قابل استفاده در مرورگر | `supabase-config.js` |
| `SUPABASE_DB_PASSWORD` | رمز اتصال workflow برای اجرای migration | فقط GitHub Actions Secret؛ هرگز در مرورگر یا README نیست |

- قالب امن پیکربندی در [`supabase-config.example.js`](./supabase-config.example.js) قرار دارد.
- فایل `supabase-config.js` نسخه حاضر پیکربندی عمومیِ موردنیاز نسخه Pages را دارد. برای fork یا پروژه مستقل، مقادیر خودتان را جایگزین کنید.
- Publishable/anon key برای مرورگر **راز مدیریتی نیست**؛ امنیت داده باید با RLS برقرار شود.
- هرگز `service_role`، JWT secret، رمز دیتابیس یا کلید سرویس خارجی را در این فایل، Issue، commit یا مرورگر قرار ندهید.

### ۲) Auth و URLهای بازگشت

در پروژه Supabase، Email provider و تأیید ایمیل را فعال کنید. برای نسخه منتشرشده، این URLها را در **Authentication → URL Configuration** قرار دهید:

```text
Site URL
https://arshia8058.github.io/Barino/

Redirect URLs
https://arshia8058.github.io/Barino/
https://arshia8058.github.io/Barino/#auth
https://arshia8058.github.io/Barino/#reset-password
```

برای توسعه محلی، آدرس‌های متناظر مانند موارد زیر را نیز اضافه کنید:

```text
http://localhost:8080/
http://localhost:8080/#auth
http://localhost:8080/#reset-password
```

کد JavaScript مقصد redirect را از URL فعلی مرورگر می‌سازد تا زیرمسیر `/Barino/` در GitHub Pages حفظ شود.

### ۳) ایجاد Schema و migrationها

دو مسیر وجود دارد. برای پروژه جدید، یک مسیر را از ابتدا انتخاب کنید و برای migrationهای بعدی همان مسیر را ادامه دهید.

<details>
<summary><strong>مسیر A — SQL Editor (مناسب اجرای دستی)</strong></summary>

1. در Supabase به **SQL Editor** بروید.
2. محتوای [`supabase_schema.sql`](./supabase_schema.sql) را کامل اجرا کنید.
3. اگر clipboard موبایل برای فایل کامل مناسب نیست، پنج فایل پوشه [`supabase/`](./supabase/) را به ترتیب `01` تا `05` اجرا کنید. راهنمای کوتاه‌تر در [`supabase/README.md`](./supabase/README.md) است.

</details>

<details>
<summary><strong>مسیر B — GitHub Actions (مناسب موبایل و migrationهای بعدی)</strong></summary>

1. در مخزن GitHub به **Settings → Secrets and variables → Actions** بروید.
2. فقط یک secret با نام `SUPABASE_DB_PASSWORD` بسازید و رمز دیتابیس Supabase را وارد کنید.
3. پس از قرارگرفتن migrationها در `main`، workflow [Deploy Barino Supabase schema](./.github/workflows/deploy-supabase-schema.yml) را از تب **Actions** به‌صورت دستی و روی branch `main` اجرا کنید.
4. workflow با Supabase CLI، فایل‌های [`supabase/migrations/`](./supabase/migrations/) را اعمال می‌کند.

workflow آدرس اتصال را داخل runner می‌سازد و رمز را URL-encode می‌کند؛ URL اتصال یا رمز در مخزن نگهداری نمی‌شود.

</details>

### ۴) ساخت اولین مدیر

مدیر از فیلد قابل‌ویرایش پروفایل یا JavaScript ساخته نمی‌شود. ابتدا کاربر با Auth ثبت‌نام کند، سپس مالک پروژه در SQL Editor UUID همان کاربر را وارد کند:

```sql
insert into public.app_admins (user_id)
values ('UUID-کاربر-مدیر');
```

پس از ورود مجدد، آن کاربر بخش مدیریت را خواهد دید. این دستور یک عملیات مورد اعتمادِ مالک دیتابیس است، نه یک قابلیت سمت کاربر.

<a id="github-pages"></a>
## 🌐 انتشار روی GitHub Pages

وضعیت فعلی مخزن: GitHub Pages از branch `main` و پوشه `/(root)` منتشر می‌شود و URL آن [arshia8058.github.io/Barino](https://arshia8058.github.io/Barino/) است.

برای fork یا مخزن جدید:

1. در GitHub مسیر **Settings → Pages** را باز کنید.
2. **Deploy from a branch** را انتخاب کنید.
3. branch موردنظر (معمولاً `main`) و پوشه `/(root)` را انتخاب و ذخیره کنید.
4. URL تولیدشده را به Site URL و Redirect URLs پروژه Supabase اضافه کنید.
5. پس از انتشار، ثبت‌نام، بازنشانی رمز و redirect ایمیل را از همان URL نهایی تست کنید.

> GitHub Pages فقط فایل‌های استاتیک را میزبانی می‌کند؛ جایگزین PostgreSQL، Auth، RLS یا نگه‌داری رازها نیست. این بخش‌ها در Supabase اجرا می‌شوند.

<a id="structure"></a>
## 🗂️ ساختار پروژه

```text
Barino/
├── index.html                              # نقطه ورود صفحه و وابستگی‌های CDN
├── styles.css                              # طراحی فارسی، RTL، responsive و Mobile-First
├── app.js                                  # منطق SPA، Auth، فرم‌ها، داده و تعامل‌ها
├── supabase-config.js                      # پیکربندی عمومی مرورگر برای Pages
├── supabase-config.example.js              # قالب بدون مقدار واقعی برای پروژه‌های دیگر
├── supabase_schema.sql                     # Schema کامل، RLS، triggerها و RPCها
├── supabase/
│   ├── 01-core-schema.sql                  # جدول‌ها، نوع‌ها و توابع پایه
│   ├── 02-security-guards.sql              # triggerهای محافظتی
│   ├── 03-rls-policies.sql                 # RLS policyها
│   ├── 04-loads-and-offers.sql             # ثبت بار، پیشنهاد و توافق
│   ├── 05-shipments-and-grants.sql         # سفارش، اطلاعات خصوصی و grantها
│   ├── migrations/                         # migrationهای قابل اعمال با Supabase CLI
│   └── README.md                           # راهنمای اجرای تکه‌های SQL از موبایل
├── .github/workflows/
│   └── deploy-supabase-schema.yml          # workflow دستی استقرار Schema
├── .gitignore
└── README.md
```

<a id="security"></a>
## 🔒 امنیت و حریم خصوصی

امنیت Barino فقط به پنهان‌کردن دکمه‌ها در رابط وابسته نیست. کنترل‌های زیر در کد و Schema وجود دارند:

- **RLS برای جدول‌های حساس:** `profiles`، `loads`، `load_private_details`، `freight_offers`، `shipments`، `shipment_status_history` و `reports`.
- **حساب فعال در دیتابیس:** policyها و RPCهای حساس، تأییدشدن ایمیل و مسدودنبودن حساب را با `is_active_user()` کنترل می‌کنند.
- **اطلاعات خصوصی مسیر:** نشانی بارگیری/تخلیه در `load_private_details` جدا از بار عمومی نگهداری می‌شود.
- **شماره تماس و نشانی:** فقط برای طرف‌های مجاز یک shipment یا مدیر از RPC کنترل‌شده بازگردانده می‌شود.
- **عملیات اتمیک:** ثبت بار، پیشنهاد، پذیرش پیشنهاد، ویرایش بار و تغییر وضعیت با RPCهای PostgreSQL و کنترل `auth.uid()` انجام می‌شوند.
- **نقش مدیر:** فقط جدول خصوصی `app_admins` مرجع مدیر است؛ نقش مدیر از metadata ثبت‌نام، فیلد پروفایل یا دست‌کاری JavaScript به دست نمی‌آید.
- **کمینه‌سازی مجوز:** مجوز پیش‌فرض `PUBLIC`/`anon` برای توابع حساس صریحاً لغو و فقط دسترسی لازم به `authenticated` اعطا شده است.
- **مرورگر:** CSP محدودکننده، Referrer Policy و نسخه pin‌شده کتابخانه Supabase در `index.html` تعریف شده‌اند.

### مرز مهم امنیت

RLS از درخواست‌های مرورگر با کلید عمومی محافظت می‌کند؛ اما مالک Supabase، `service_role` و هر شخصی که رمز دیتابیس یا رازهای سروری دارد می‌تواند RLS را دور بزند. این موارد را فقط در محیط سروری/Secrets نگه دارید و هرگز در frontend یا GitHub commit نکنید.

<a id="data-model"></a>
<details>
<summary><strong>مدل داده و دسترسی‌ها</strong></summary>

| منبع | کارکرد | خواندن مجاز |
|---|---|---|
| `profiles` | پروفایل و مشخصات کامیون | خود کاربر، مدیر یا طرف سفارش توافق‌شده |
| `driver_public_profiles` | نمای عمومی راننده | حساب فعال؛ بدون تلفن، پلاک و نشانی |
| `loads` | اطلاعات عمومی بار | حساب فعال برای بار باز؛ مالک، طرف سفارش یا مدیر برای سایر وضعیت‌ها |
| `load_private_details` | نشانی دقیق مبدأ و مقصد | مالک، طرف‌های shipment یا مدیر |
| `freight_offers` | پیشنهاد کرایه | راننده پیشنهاددهنده، مالک بار یا مدیر |
| `shipments` و `shipment_status_history` | سفارش و تاریخچه | طرف‌های همان سفارش یا مدیر |
| `reports` | گزارش تخلف/مشکل | ثبت‌کننده یا مدیر |
| `app_admins` | مرجع مدیران | در دسترس کلاینت نیست |

</details>

<a id="troubleshooting"></a>
## 🧰 عیب‌یابی سریع

| نشانه | علت محتمل | راه‌حل |
|---|---|---|
| پیام «تنظیمات Supabase وارد نشده است» | `url` یا `anonKey` placeholder است یا فایل پیکربندی لود نشده | `supabase-config.js` را با قالب example بررسی کنید؛ فقط URL و publishable/anon key عمومی را وارد کنید. |
| لینک تأیید یا بازیابی به صفحه نامعتبر می‌رود | URL بازگشت در Supabase ثبت نشده | Site URL و هر سه Redirect URL بخش تنظیمات را دقیق و با زیرمسیر `/Barino/` وارد کنید. |
| دکمه ارسال دوباره ایمیل غیرفعال است | شمارش معکوس ۶۰ ثانیه‌ای فعال است | صبر کنید؛ شمارش با زمان واقعی به‌روزرسانی می‌شود. اگر برنامه در پس‌زمینه بود، با بازگشت به صفحه دوباره محاسبه می‌شود. محدودیت Supabase ممکن است طولانی‌تر باشد. |
| پیام rate limit ایمیل | محدودیت سمت Supabase/Auth provider | پشت سر هم درخواست نفرستید و تا پایان محدودیت provider صبر کنید؛ cooldown رابط جایگزین محدودیت سرور نیست. |
| ثبت/خواندن داده با خطای permission یا RLS رد می‌شود | ایمیل تأیید نشده، حساب مسدود است یا سیاست دسترسی اجازه نمی‌دهد | تأیید ایمیل، نقش حساب و RLS/schema اعمال‌شده را بررسی کنید؛ برای رفع مشکل RLS را خاموش نکنید. |
| migration اجرا نمی‌شود | secret workflow تعریف نشده یا روی branch نادرست اجرا شده | `SUPABASE_DB_PASSWORD` را فقط در Actions Secrets قرار دهید و workflow را روی `main` اجرا کنید. |
| تغییرات Pages دیده نمی‌شود | cache مرورگر یا build هنوز کامل نشده | صفحه را refresh سخت کنید و وضعیت workflow Pages را در تب Actions بررسی کنید. |

<a id="contributing"></a>
## 🤝 مشارکت در توسعه

راهنمای مستقل `CONTRIBUTING.md` در مخزن وجود ندارد؛ با این حال برای تغییرات پیشنهادی می‌توانید روند معمول GitHub را دنبال کنید:

1. مخزن را fork کنید یا branch جدا بسازید.
2. تغییر را کوچک، قابل توضیح و هم‌راستا با معماری static + Supabase نگه دارید.
3. برای تغییرات JavaScript، حداقل `node --check app.js` و `git diff --check` را اجرا کنید.
4. برای تغییرات Schema، migration جدید اضافه کنید؛ migration قبلیِ اعمال‌شده را بازنویسی نکنید.
5. Pull Request را با شرح مسئله، راه آزمون و اثر امنیتی احتمالی ارسال کنید.

> هر تغییر در Auth، RLS، grantها، RPCهای `SECURITY DEFINER` یا workflow باید به‌عنوان تغییر حساس امنیتی بازبینی شود.

<a id="license"></a>
## 📄 مجوز استفاده

در حال حاضر فایل `LICENSE` یا `LICENCE` در این مخزن وجود ندارد؛ بنابراین هیچ مجوز استفادهٔ مستقلی از روی مخزن اعلام نشده است. پیش از استفاده، بازنشر یا استفاده تجاری، با مالک مخزن هماهنگ کنید.

---

<p align="center" dir="rtl">
  <strong>Barino / بارینو</strong> · حمل‌ونقل شفاف‌تر با داده‌های محافظت‌شده<br />
  <a href="#Barino">بازگشت به بالا</a>
</p>
