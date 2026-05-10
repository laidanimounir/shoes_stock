# 👟 ShoeStock ERP & POS — نظام إدارة متكامل للأحذية

**الإصدار الحالي:** v4.2 | **تاريخ آخر تحديث:** 10 مايو 2026  
> **حالة Supabase:** ✅ `ACTIVE_HEALTHY` | **المنطقة:** `eu-west-3` (باريس)  
> **Flutter SDK:** `3.41.7` (FVM) | **Dart SDK:** `^3.11.0`  
> **Project ID:** `jluuobtzylejiahbelgp`

---

## 📋 فهرس المحتويات

1. [نظرة عامة](#نظرة-عامة)
2. [البنية المعمارية](#البنية-المعمارية)
3. [مصفوفة الصلاحيات](#مصفوفة-الصلاحيات)
4. [هيكل الملفات الكامل](#هيكل-الملفات-الكامل)
5. [قاعدة البيانات](#قاعدة-البيانات)
6. [الوحدات المكتملة](#الوحدات-المكتملة)
7. [حالة التعريب i18n](#حالة-التعريب)
8. [خريطة الطريق](#خريطة-الطريق)
9. [الأمان والديون التقنية](#الأمان-والديون التقنية)
10. [قواعد حرجة يجب حفظها](#قواعد-حرجة-يجب-حفظها)
11. [متطلبات التشغيل](#متطلبات التشغيل)
12. [إحصائيات المشروع](#إحصائيات-المشروع)
13. [سجل الإصدارات](#سجل-الإصدارات)

---

## 🌐 نظرة عامة

ShoeStock ERP ليس مجرد تطبيق برمجي — بل هو حل تجاري هندسي متكامل لرقمنة دورة الحياة التشغيلية لمحلات الأحذية. المشروع ثمرة هندسة ميدانية (Field Engineering) حقيقية: زيارات متعددة لورشة تصنيع أحذية، مقابلات معمّقة مع الموظفين والمحاسبين والمديرين، وترجمة إجراءات يدوية معقدة إلى هيكل رقمي عالي الأداء. النظام مصمم للتسليم الرسمي ويشمل تدريباً عملياً للموظفين.

| البند | القيمة |
|---|---|
| **النوع** | ERP + POS متكامل |
| **المنصات** | Windows (أساسي) + Android/iOS (ثانوي) |
| **Backend** | Supabase / PostgreSQL 17.6 |
| **قاعدة البيانات المحلية** | Isar v3.1.0+1 (Offline-First) |
| **العمارة** | Hybrid Online/Offline + RPC-Based + RBAC |
| **اللغات** | عربي (افتراضي) + فرنسي |
| **الخطوط AR** | `GoogleFonts.cairo()` (body) + `GoogleFonts.amiri()` (headings) |
| **الخطوط FR** | `GoogleFonts.raleway()` + `GoogleFonts.playfairDisplay()` |

---

## 🏗️ البنية المعمارية

```text
┌─────────────────────────────────────────────────────────┐
│                   Flutter (UI فقط)                      │
│   Windows POS  ←→  Android/iOS Audit Tool               │
├─────────────────────────────────────────────────────────┤
│             Isar Local DB (Offline Layer)               │
│   15 Collection  |  SyncQueue  |  ConnectivityService   │
├─────────────────────────────────────────────────────────┤
│              SyncEngine (Queue Replay)                  │
│        Max 3 retries | Priority ordering                │
├─────────────────────────────────────────────────────────┤
│           Supabase Cloud (Source of Truth)              │
│     13 Tables + settings/local-only  |  RPCs  | RLS    │
└─────────────────────────────────────────────────────────┘
```

### ⚡ مبدأ المعمارية الأساسي — لا تخالفه أبداً
> **ALL financial calculations live in Supabase RPCs exclusively.**  
> Flutter = UI/Display only. Data integrity is guaranteed regardless of client state.

### المنصات

| المنصة | الوصف |
|---|---|
| **Desktop Windows POS** | Global Hardware Hook — USB Laser Scanner عبر HardwareKeyboard events من أي حالة شاشة |
| **Mobile Android/iOS** | `mobile_scanner` API — أداة تدقيق المستودع والتحقق من المتغيرات وفحص الهامش |
| **Offline Mode (v3)** | Isar + SyncQueue — البيع مستمر حتى بدون إنترنت، مزامنة تلقائية عند الاتصال |

### خدمات جوهرية (Core Services)

| الخدمة | الملف | الوصف |
|---|---|---|
| `ConnectivityService` | `core/connectivity_service.dart` | Singleton — مراقبة الشبكة + تشغيل SyncEngine عند الاتصال |
| `SeedService` | `local_db/seed_service.dart` | تحميل الجداول الأساسية من Supabase إلى Isar عند أول تسجيل دخول offline |
| `SyncEngine` | `core/sync_engine.dart` | إعادة تشغيل SyncQueueItem — 3 محاولات ثم تحديد failed |
| `InvoiceService` | `services/invoice_service.dart` | Offline-aware: online→RPC مباشرة / offline→Isar+Queue |
| `ExpenseService` | `services/expense_service.dart` | Offline-aware: online→RPC / offline→Isar+Queue |
| `DebtRecoveryService` | `services/debt_recovery_service.dart` | Offline-aware: online→RPC / offline→Isar+Queue |

---

## 🔐 مصفوفة الصلاحيات

| الدور | مستوى الوصول | القدرات |
|---|---|---|
| **Owner / Administrator** | عمودي كامل | تقارير شاملة، كل الفروع، إدارة الموظفين، العمليات الحرجة |
| **Employee / Cashier** | أفقي محدود | البيانات مفلترة بـ `store_id`، قوائم الإدارة مخفية |

- **RLS:** Supabase Row-Level Security يرفض العمليات غير المصرح بها على مستوى الحزم.
- **استثناء `42501`:** يُعترض بأناقة — رسالة "Access Denied" ثنائية اللغة بدلاً من تعطل التطبيق.
- **`AppSession.currentShiftId`**: تمت إزالته بالكامل بعد حذف نظام الوردية.

---

## 📁 هيكل الملفات الكامل

```text
Shoes_Stock/
├── lib/
│   ├── main.dart                          (11.8 KB) — نقطة الدخول
│   ├── core/
│   │   ├── app_session.dart               (2.2 KB)  — الجلسة + locale ValueNotifier
│   │   ├── app_strings.dart               (43.5 KB) — ~280+ مفتاح AR/FR
│   │   ├── connectivity_service.dart      (1.6 KB)  — مراقبة الاتصال
│   │   └── sync_engine.dart               (11.9 KB) — محرك المزامنة
│   ├── controllers/                       ⚠️ فارغ — كود ميت
│   ├── features/                          ⚠️ فارغ — كود ميت
│   ├── local_db/
│   │   ├── collections/
│   │   │   ├── store_local.dart
│   │   │   ├── user_profile_local.dart
│   │   │   ├── customer_local.dart        — + address field (v4)
│   │   │   ├── supplier_local.dart
│   │   │   ├── product_local.dart
│   │   │   ├── product_variant_local.dart — + @Index(barcode)
│   │   │   ├── inventory_local.dart       — + composite index
│   │   │   ├── invoice_local.dart         — synced flag ✅
│   │   │   ├── payment_local.dart         — + paymentType (v4) synced ✅
│   │   │   ├── transaction_local.dart     — synced flag ✅
│   │   │   ├── expense_category_local.dart — v4 ✅
│   │   │   ├── expense_local.dart         — synced flag ✅ v4
│   │   │   ├── settings_local.dart        — locale persistence v4
│   │   │   ├── sync_queue_item.dart       — idempotencyKey + priority + retryCount
│   │   │   └── sync_metadata.dart         — Singleton: lastSyncAt + mode + pendingCount
│   │   ├── enums/
│   │   │   └── local_enums.dart           (8.3 KB) — PaymentMethod + PaymentType + SyncOperationType
│   │   ├── isar_service.dart              (1.9 KB)
│   │   └── seed_service.dart              (15.3 KB) — expense_categories + expenses
│   ├── models/
│   └── services/
│       ├── invoice_service.dart           (5.0 KB)  — offline-aware
│       ├── refund_service.dart            (1.4 KB)
│       ├── expense_service.dart           (6.9 KB)  — offline-aware
│       └── debt_recovery_service.dart     (5.5 KB)  — offline-aware
│   └── views/
│       ├── auth/
│       │   └── login_screen.dart          (21.7 KB) — mode selection + AR/FR toggle ✅
│       ├── desktop/
│       │   ├── admin_main_layout.dart     (16.3 KB) — RTL + BorderDirectional ✅
│       │   ├── employee_main_layout.dart  (14.8 KB) — i18n B ✅
│       │   ├── pos_screen.dart            (44.0 KB) — uses InvoiceService v4 | i18n C3 ✅
│       │   └── refund_modal.dart          (8.2 KB)  — i18n C1 ✅
│       ├── admin/
│       │   ├── dashboard_screen.dart      (29.4 KB) — dynamic Arabic dates ✅ i18n C1
│       │   ├── ajouter_produit.dart       (19.8 KB) — i18n C1 ✅
│       │   ├── expenses_screen.dart       (23.9 KB) — v4 | i18n C2 ✅
│       │   ├── debt_recovery_screen.dart  (26.5 KB) — v4 | i18n C2 ✅
│       │   ├── gestion_employes.dart      (15.0 KB) — i18n C2 ✅
│       │   ├── gestion_clients.dart       (32.9 KB) — i18n C3 ✅
│       │   ├── gestion_fournisseurs.dart  (26.6 KB) — i18n C3 ✅
│       │   ├── gestion_stores.dart        (16.2 KB) — i18n C3 ✅
│       │   ├── liste_produits.dart        (29.6 KB) — i18n C3 ✅
│       │   ├── inventory_screen.dart      (31.2 KB) — v4 fix (casting) | i18n C3 ✅
│       │   ├── achat_fournisseur.dart     (21.0 KB) — i18n C3 ✅
│       │   ├── sales_history_screen.dart  (8.3 KB)  — i18n B ✅
│       │   └── activity_logs_screen.dart  (6.8 KB)  — i18n B ✅
│       ├── mobile/
│       │   └── owner_dashboard.dart       (58.2 KB) — i18n C4 ✅ v4.1 (RPCs + WhatsApp/SMS)
│       └── widgets/
│           └── offline_banner.dart        (6.2 KB)  — i18n B ✅
├── supabase/migrations/                   — 9 migration files
├── datatalk-ai/                           — مشروع Python فرعي لتحليل البيانات
├── assets/images/                         — صورتان فقط (login)
├── test/                                  — ملف واحد افتراضي فقط ⚠️
├── .fvmrc                                 — Flutter 3.41.7
├── pubspec.yaml                           (751B)
├── analysis_options.yaml
└── README.md
```

---

## 🗄️ قاعدة البيانات

### الجداول

| الجدول | الحالة | ملاحظات |
|---|---|---|
| `stores` | ✅ | RLS يحتاج تشديداً |
| `user_profiles` | ✅ | RLS يحتاج تشديداً |
| `customers` | ✅ | جيد |
| `suppliers` | ✅ | RLS يحتاج تشديداً |
| `products` | ✅ | جيد |
| `product_variants` | ✅ | RLS يحتاج تشديداً |
| `inventory` | ✅ | جيد |
| `invoices` | ✅ | جيد |
| `payments` | ✅ | `payment_type` invoice/debt_recovery |
| `transactions` | ✅ | يحتاج تحسين RLS |
| `activity_logs` | ✅ | RLS مفتوح |
| `expense_categories` | ✅ | فارغ حتى الآن |
| `expenses` | ✅ | فارغ حتى الآن |
| `settings` | ❌ | محلي فقط داخل Isar |

### دوال RPC النشطة

| الدالة | الحالة | الملاحظة |
|---|---|---|
| `process_sale` | ✅ | نسخة واحدة فقط بدون `p_shift_id` |
| `process_purchase` | ✅ | أوامر الشراء + تحديث المخزون |
| `process_refund` | ✅ | ذري: إلغاء فاتورة + إعادة مخزون + قيد محاسبي |
| `add_expense` | ✅ | إدراج مصروف تشغيلي ذري |
| `add_debt_recovery_payment` | ✅ | دفعة بدون فاتورة — تخفض رصيد العميل |
| `update_balance_from_invoice` | ✅ | Trigger |
| `update_balance_from_payment` | ✅ | Trigger |
| `handle_inventory_transaction` | ✅ | Trigger على transactions |
| `handle_new_user` | ✅ | Auth Trigger |
| `get_current_user_profile` | ✅ | جلب ملف المستخدم |
| `log_transaction_activity` | ✅ | Audit trail |

### Edge Functions

| الاسم | الحالة | JWT | الخطر |
|---|---|---|---|
| `create_employee` | ✅ ACTIVE | ❌ معطّل | 🔴 أي شخص يستطيع إضافة موظف |
| `delete_employee` | ✅ ACTIVE | ❌ معطّل | 🔴 أي شخص يستطيع حذف موظف |

### الملاحظات المهمة
- جدول `shifts` تم حذفه بالكامل.
- العمود `shift_id` تم حذفه من `invoices` و`payments`.
- دوال `open_shift` و`close_shift` و`get_active_shift` تم حذفها.
- `process_sale` لم يعد يستقبل `p_shift_id`.

---

## ✅ الوحدات المكتملة

### v1 — النظام الأساسي *(إنتاج — مارس 2026)*
- [x] مصادقة متعددة الأدوار (Owner / Employee)
- [x] إدارة متعددة الفروع
- [x] كتالوج المنتجات والمتغيرات مع الباركود
- [x] إدارة المخزون الفوري
- [x] إدارة الموردين والعملاء مع تتبع الأرصدة
- [x] معالجة أوامر الشراء
- [x] POS Windows — USB Scanner عبر Global Hardware Hook
- [x] إنشاء الفواتير + معالجة المدفوعات
- [x] سجلات تدقيق كاملة (activity_logs)
- [x] لوحة تحكم المدير

### v2 — إدارة المرتجعات
- [x] `refund_modal.dart` — مرتجع بمستوى العنصر + محدد الكمية + حقل السبب
- [x] `process_refund` RPC — ذري: فاتورة→refunded + إعادة مخزون + قيد محاسبي

### v3 — نظام Hybrid Offline/Online *(مكتمل)*
- [x] 15 Isar Collection تعكس البيانات المحلية المطلوبة
- [x] `SeedService` — تحميل الجداول الأساسية في ترتيب FK-safe
- [x] `SyncEngine` — إعادة تشغيل SyncQueueItem مع retry logic
- [x] `InvoiceService` — Offline-aware
- [x] `ConnectivityService` — يُشغّل sync عند العودة للاتصال
- [x] `SyncQueueItem` — idempotencyKey + priority
- [x] معالجة race conditions في sync loop

### v4 — المصاريف + تحصيل الديون + التعريب *(مكتمل)*
- [x] جداول `expense_categories` و `expenses`
- [x] RPCs ذرية: `add_expense` + `add_debt_recovery_payment`
- [x] `ExpenseService` + `DebtRecoveryService`
- [x] شاشات المصاريف وتحصيل الديون
- [x] توسعة `SyncOperationType` للعمليات الجديدة
- [x] Phase C2 / C3 / C4 مكتملة
- [x] `owner_dashboard` v4.1

### v5 — إزالة نظام الوردية *(مايو 2026)*
- [x] حذف `shifts` من Supabase
- [x] حذف `shift_id` من `invoices` و`payments`
- [x] تحديث `process_sale` بدون `p_shift_id`
- [x] حذف ملفات Flutter الخاصة بالوردية
- [x] حذف `ShiftLocal` من Isar
- [x] حذف `currentShiftId` من `AppSession`
- [x] حذف مراجع الوردية من `pos_screen` و`employee_main_layout` و`sales_history_screen`
- [x] تنظيف `seed_service.dart` و`isar_service.dart`

---

## 🌍 حالة التعريب (i18n)

| المرحلة | الملفات | الحالة |
|---|---|---|
| **Phase A** | `app_strings.dart` + `SettingsLocal` + `AppSession.locale` | ✅ مكتمل |
| **Phase B** | `offline_banner`, `login_screen`, `admin_main_layout`, `employee_main_layout`, `sales_history_screen`, `activity_logs_screen` | ✅ مكتمل |
| **Phase C1** | `refund_modal`, `dashboard_screen`, `ajouter_produit` | ✅ مكتمل |
| **Phase C2** | `debt_recovery_screen`, `expenses_screen`, `gestion_employes` | ✅ مكتمل |
| **Phase C3** | `gestion_stores`, `achat_fournisseur`, `inventory_screen`, `liste_produits`, `gestion_fournisseurs`, `gestion_clients`, `pos_screen` | ✅ مكتمل |
| **Phase C4** | `owner_dashboard` | ✅ مكتمل |

---

## 🗺️ خريطة الطريق

| الأولوية | الوحدة | الوصف | الحالة |
|---|---|---|---|
| 🔴 عالية | **Receipt Printing** | طابعة حرارية 80mm + توليد PDF للفواتير | 🔲 معلّق |
| 🔴 عالية | **Low Stock Alerts** | حد أدنى للمخزون لكل متغير + لوحة إعادة الطلب | 🔲 معلّق |
| 🟡 متوسطة | **Analytics Dashboard** | اتجاهات المبيعات، أفضل المنتجات، تحليل الهامش | 🔲 معلّق |
| 🟡 متوسطة | **Mobile Audit Tool** | استكمال شاشات تدقيق المستودع Android/iOS | 🔲 معلّق |
| 🟢 مستقبل | **Multi-branch Reporting** | تقارير مالية موحدة عبر الفروع | 🔲 مخطط |
| 🟢 مستقبل | **Employee Performance** | مبيعات لكل كاشير، إنتاجية الشيفت | 🔲 مخطط |

---

## 🔐 الأمان والديون التقنية

### 🔴 مشاكل حرجة
| # | المشكلة | الخطورة | الحل |
|---|---|---|---|
| 1 | Edge Functions بدون JWT | أي شخص يضيف/يحذف موظفاً | تفعيل `verify_jwt = true` |
| 2 | 28 FK بدون فهارس | بطء شديد عند نمو البيانات | Migration واحد يضيف 28 فهرساً |
| 3 | جدول `settings` مفقود من Supabase | تناقض بين الكود والـ DB | Migration لإنشاء الجدول |

### 🟡 مشاكل مهمة
| # | المشكلة | الحل |
|---|---|---|
| 4 | 5 جداول RLS مفتوحة | تشديد السياسات |
| 5 | بعض RPC بدون `search_path` | إضافة `SET search_path = ''` |
| 6 | سياسات RLS بطيئة | استبدال `auth.uid()` المباشر بـ `(select auth.uid())` |
| 7 | Isar بدون تشفير | `encryptionKey` مرتبط بـ device ID |
| 8 | Supabase Keys في الكود | `--dart-define` |
| 9 | Leaked Password Protection معطّل | تفعيله من Supabase Dashboard |
| 10 | Storage Buckets بحاجة تقييد | سياسات قراءة صارمة |

### 🟢 تحسينات للاحترافية
| # | المشكلة |
|---|---|
| 11 | لا توجد Unit Tests كافية |
| 12 | لا يوجد Error Handler موحد |
| 13 | مجلدا `controllers/` و `features/` فارغان |
| 14 | بعض الحزم تحتاج تحديثاً تدريجياً |
| 15 | `PROJECT_PROGRESS.md` قديم |
| 16 | لا توجد comments على الدوال الرئيسية |

---

## ⚠️ قواعد حرجة يجب حفظها

1. **لا تُعدّل `inventory` يدوياً أبداً داخل أي RPC**.
2. **`process_sale` نسخة واحدة فقط** بدون `p_shift_id`.
3. **`expenses` منفصل عن `transactions` عمداً**.
4. **`payment_type` في `payments`** يميز بين `invoice` و `debt_recovery`.
5. **Flutter = UI فقط، لا حسابات مالية**.
6. **SyncOperationType** يجب تحديثه مع أي عملية offline جديدة.
7. **`getActiveShift()`** لم يعد موجوداً بعد حذف نظام الوردية.

---

## ⚙️ متطلبات التشغيل

### المتطلبات الأساسية
- **FVM** مثبت.
- Flutter SDK `3.41.7` عبر FVM فقط.
- Visual Studio 2022 Community Release مع C++ workload.
- مشروع Supabase مهيأ بـ `jluuobtzylejiahbelgp`.

### أوامر الإعداد الكاملة
```bash
dart pub global activate fvm
fvm install 3.41.7
fvm use 3.41.7

fvm flutter clean
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter run -d windows

fvm flutter build windows
```

---

## 📊 إحصائيات المشروع

| المقياس | القيمة |
|---|---|
| **إجمالي ملفات Dart** | ~45 ملف (بدون `.g.dart`) |
| **ملفات مولّدة `.g.dart`** | 15 ملف |
| **أكبر ملف** | `owner_dashboard.dart` |
| **ثاني أكبر ملف** | `pos_screen.dart` |
| **ملف الترجمة** | `app_strings.dart` |
| **Isar Collections** | 15 |
| **Supabase Tables** | 13 + `settings` محلي فقط |
| **Supabase RPCs** | 11+ |
| **Edge Functions** | 2 (⚠️ بدون JWT) |
| **Migrations** | 9 |
| **تنبيهات أمنية من Supabase** | متعددة |
| **FK بدون فهارس** | 28 |
| **صور Assets** | 2 فقط |

---

## 🔖 سجل الإصدارات

| الإصدار | الوصف | التاريخ | الحالة |
|---|---|---|---|
| **v1** | النظام الأساسي | مارس 2026 | ✅ إنتاج |
| **v2** | المرتجعات | أبريل 2026 | ✅ مكتمل |
| **v3** | Hybrid Offline/Online | 18 أبريل 2026 | ✅ مكتمل |
| **v4** | المصاريف + تحصيل الديون + التعريب | 26 أبريل 2026 | ✅ مكتمل |
| **v5** | إزالة نظام الوردية | 10 مايو 2026 | ✅ مكتمل |

---

## الملاحظة الختامية

- هذا README يعكس **ما تم تنفيذه فعلياً**.
- تم حذف كل الإشارات لنظام الوردية من الخلاصة والهيكل والـ RPCs.
- تم تحديث المزامنة لتشمل `idempotencyKey` و `priority`.
- بقيت العناصر الأخرى كما هي دون اختراع أو توسيع غير موجود.
