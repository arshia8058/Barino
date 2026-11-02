# استقرار Schema بارینو

## مسیر پشتیبانی‌شده: GitHub Actions

برای جلوگیری از خطای copy/paste در موبایل، مسیر پشتیبانی‌شده برای دیتابیس موجود و migrationهای بعدی، workflow دستی **Deploy Barino Supabase schema** است:

1. migrationهای جدید را همراه کد در `main` ادغام کنید؛ migration اعمال‌شده را بازنویسی نکنید.
2. در GitHub، از **Settings → Secrets and variables → Actions** فقط secret `SUPABASE_DB_PASSWORD` را ثبت کنید.
3. از **Actions → Deploy Barino Supabase schema → Run workflow**، branch `main` را انتخاب و اجرا کنید. گزینهٔ `provision_initial_admin` در اجرای عادی باید خاموش بماند.
4. workflow با `supabase db push` فقط فایل‌های جدید `migrations/` را بر پایهٔ تاریخ نام فایل اعمال می‌کند. اجرای آن خودکار یا بخشی از GitHub Pages نیست.

جدیدترین migration فعلی [`migrations/20261102130000_validation_and_abuse_controls.sql`](./migrations/20261102130000_validation_and_abuse_controls.sql) است. این migration افزایشی است: اعتبارسنجی شمارهٔ ایران برای نوشته‌های جدید/تغییریافته را با `NOT VALID` اضافه می‌کند و هیچ رکورد تاریخی را حذف یا بازنویسی نمی‌کند. پیش از اجرای آن روی دادهٔ واقعی، migrationهای اعمال‌شده و پشتیبان‌گیری خود را بررسی کنید.

## دیتابیس تازه

[`../supabase_schema.sql`](../supabase_schema.sql) نمای تجمعی Schema برای **دیتابیس تازه** است و migrationهای تکمیلی تا نسخهٔ فعلی را دارد. آن را روی دیتابیس موجود اجرا نکنید. برای دیتابیس تازه نیز ترجیحاً همین مخزن و workflow Actions را استفاده کنید تا تاریخچهٔ migration ثبت شود.

فایل‌های `01` تا `05` و `manual-admin-console/` در مخزن برای بازبینی/ارجاع تاریخی باقی مانده‌اند؛ آن‌ها مسیر استقرار پیشنهادی برای کاربر موبایل یا دیتابیس در حال استفاده نیستند. ترکیب اجرای دستی تکه‌ها با workflow می‌تواند وضعیت migration را نامشخص کند.

## مدیر اولیه

برای ایجاد مدیر اولیه، حساب منتخب باید از قبل در Supabase Auth وجود داشته باشد، ایمیل تأییدشده و پروفایل Barino فعال و مسدودنشده داشته باشد. سپس مطابق [راهنمای اصلی](../README.md#supabase-setup)، ایمیل دقیق آن حساب را فقط در secret `SUPABASE_INITIAL_ADMIN_EMAIL` قرار دهید و workflow را یک‌بار با گزینهٔ `provision_initial_admin` روشن اجرا کنید.

این provision در runner مورد اعتماد Actions انجام می‌شود، از مرورگر قابل فراخوانی نیست و در صورت وجود مدیر دیگر fail-closed می‌شود. رازها، URL اتصال و ایمیل مدیر را در SQL، commit، Issue یا رابط عمومی قرار ندهید.
