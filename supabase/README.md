# اجرای SQL بارینو با موبایل

اگر فایل `supabase_schema.sql` برای clipboard گوشی بزرگ است، شش فایل زیر را **دقیقاً به همین ترتیب** در Supabase SQL Editor اجرا کنید:

1. [`01-core-schema.sql`](./01-core-schema.sql) — جدول‌ها، نوع‌ها، indexها و توابع پایه
2. [`02-security-guards.sql`](./02-security-guards.sql) — Triggerهای محافظتی
3. [`03-rls-policies.sql`](./03-rls-policies.sql) — فعال‌سازی RLS و policyها
4. [`04-loads-and-offers.sql`](./04-loads-and-offers.sql) — ثبت بار، پیشنهاد و توافق امن
5. [`05-shipments-and-grants.sql`](./05-shipments-and-grants.sql) — وضعیت سفارش، اطلاعات خصوصی و مجوزهای پایه
6. [`06-admin-console.sql`](./06-admin-console.sql) — پنل مدیریت امن، audit log و RPCهای مدیر

برای هر فایل: محتوا را کامل Copy کنید، در SQL Editor Paste کنید، **Run** بزنید و تنها پس از پیام موفقیت به فایل بعدی بروید.

> این فایل‌ها جایگزین مستقل نیستند؛ ترتیب شماره‌ها ضروری است. اجرای هر شش فایل برابر با اجرای `supabase_schema.sql` است.
