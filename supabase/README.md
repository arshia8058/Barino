# اجرای SQL بارینو از موبایل

فایل `supabase_schema.sql` شامل شمای کامل فعلی (پایه، سخت‌سازی‌های قبلی و پنل مدیریت) است. اگر clipboard گوشی برای فایل کامل بزرگ است، ابتدا پنج فایل پایه را **دقیقاً به همین ترتیب** در Supabase SQL Editor اجرا کنید:

1. [`01-core-schema.sql`](./01-core-schema.sql) — جدول‌ها، نوع‌ها، indexها و توابع پایه
2. [`02-security-guards.sql`](./02-security-guards.sql) — Triggerهای محافظتی
3. [`03-rls-policies.sql`](./03-rls-policies.sql) — فعال‌سازی RLS و policyها
4. [`04-loads-and-offers.sql`](./04-loads-and-offers.sql) — ثبت بار، پیشنهاد و توافق امن
5. [`05-shipments-and-grants.sql`](./05-shipments-and-grants.sql) — وضعیت سفارش، اطلاعات خصوصی و مجوزها
6. [`migrations/20261102100000_admin_console.sql`](./migrations/20261102100000_admin_console.sql) — گزارش مدیریتی و RPCهای محافظت‌شدهٔ پنل

برای هر فایل: محتوا را کامل Copy کنید، در SQL Editor Paste کنید، **Run** بزنید و تنها پس از پیام موفقیت به فایل بعدی بروید. فایل ششم افزایشی است و باید پس از Schema پایه اجرا شود؛ برای دیتابیسی که قبلاً ساخته شده، فقط migration جدید را اجرا کنید.

اگر SQL Editor موبایل متن کامل migration را نمی‌پذیرد، به‌جای فایل migration اصلی، فایل‌های `manual-admin-console/part-01.sql` تا `part-08.sql` را **به همین ترتیب و یکی‌یکی** اجرا کنید؛ پس از موفقیت هر قسمت، بعدی را اجرا کنید. اگر خطایی دیدید، ادامه ندهید. از روش فایل کامل و تکه‌ها با هم استفاده نکنید.

> این فایل‌ها جایگزین مستقل نیستند؛ ترتیب شماره‌ها ضروری است. پنج فایل اول، شمای پایه را می‌سازند؛ `supabase_schema.sql` علاوه بر آن‌ها migrationهای تکمیلی فعلی، از جمله پنل مدیریت، را هم دارد. فایل‌های migration اعمال‌شده را در دیتابیس موجود بازنویسی یا از نو اجرا نکنید.

برای تعیین مدیر اولیه، از مسیر **GitHub Actions** در [`README.md`](../README.md#supabase-setup) استفاده کنید: ایمیل حساب تأییدشده و فعال را فقط در secret `SUPABASE_INITIAL_ADMIN_EMAIL` قرار دهید و workflow دستی را با گزینهٔ `provision_initial_admin` اجرا کنید. این کار در runner مورد اعتماد انجام می‌شود؛ پنل از سمت مرورگر امکان ساخت یا ارتقای مدیر ندارد.
