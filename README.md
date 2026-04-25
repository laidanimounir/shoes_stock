# 👟 ShoeStock ERP & POS — نظام إدارة متكامل للأحذية

> **الإصدار الحالي:** v4 (قيد التطوير) | **تاريخ آخر تحديث:** 25 أبريل 2026  
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
9. [الأمان والديون التقنية](#الأمان-والديون-التقنية)
10. [قواعد حرجة يجب حفظها](#قواعد-حرجة-يجب-حفظها)
11. [متطلبات التشغيل](#متطلبات-التشغيل)
12. [إحصائيات المشروع](#إحصائيات-المشروع)
13. [سجل الإصدارات](#سجل-الإصدارات)

---

## 🌐 نظرة عامة

ShoeStock ERP ليس مجرد تطبيق برمجي — بل هو حل تجاري هندسي متكامل لرقمنة دورة الحياة التشغيلية لمحلات الأحذية. المشروع ثمرة هندسة ميدانية (Field Engineering) حقيقية: زيارات متعددة لورشة تصنيع أحذية، مقابلات معمّقة مع الموظفين والمحاسبين والمديرين، وترجمة إجراءات يدوية معقدة إلى هيكل رقمي عالي الأداء. النظام مصمم لتسليم رسمي يشمل يوم تدريب للموظفين.

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

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter (UI فقط)                      │
│   Windows POS  ←→  Android/iOS Audit Tool               │
├─────────────────────────────────────────────────────────┤
│             Isar Local DB (Offline Layer)                │
│   16 Collection  |  SyncQueue  |  ConnectivityService   │
├─────────────────────────────────────────────────────────┤
│              SyncEngine (Queue Replay)                   │
│         Max 3 retries | Failed marking                  │
├─────────────────────────────────────────────────────────┤
│           Supabase Cloud (Source of Truth)               │
│     14 Tables | 12+ RPCs | RLS | Edge Functions         │
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
| `SeedService` | `local_db/seed_service.dart` | تحميل 13 جدول من Supabase إلى Isar عند أول تسجيل دخول offline |
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

- **RLS:** Supabase Row-Level Security يرفض العمليات غير المصرح بها على مستوى الحزم
- **استثناء `42501`:** يُعترض بأناقة — رسالة "Access Denied" ثنائية اللغة بدلاً من تعطل التطبيق
- **`AppSession.currentShiftId`** — متغير جلسة عالمي مرتبط بكل فاتورة ودفعة

---

## 📁 هيكل الملفات الكامل

```
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
│   │   │   ├── shift_local.dart           — synced flag ✅
│   │   │   ├── expense_category_local.dart — v4 ✅
│   │   │   ├── expense_local.dart         — synced flag ✅ v4
│   │   │   ├── settings_local.dart        — locale persistence v4
│   │   │   ├── sync_queue_item.dart       — operationType + payloadJson + retryCount
│   │   │   └── sync_metadata.dart         — Singleton: lastSyncAt + mode + pendingCount
│   │   ├── enums/
│   │   │   └── local_enums.dart           (8.3 KB) — PaymentMethod + PaymentType + SyncOperationType
│   │   ├── isar_service.dart              (1.9 KB)
│   │   └── seed_service.dart              (15.3 KB) — + expense_categories + expenses (v4)
│   ├── models/
│   │   └── shift_model.dart               (2.5 KB)
│   ├── services/
│   │   ├── invoice_service.dart           (5.0 KB)  — v3 offline-aware
│   │   ├── shift_service.dart             (5.7 KB)  — v4 fix: isar.dart import + named notes param
│   │   ├── refund_service.dart            (1.4 KB)
│   │   ├── expense_service.dart           (6.9 KB)  — v4 offline-aware
│   │   └── debt_recovery_service.dart     (5.5 KB)  — v4 offline-aware
│   └── views/
│       ├── auth/
│       │   └── login_screen.dart          (21.7 KB) — mode selection + AR/FR toggle ✅
│       ├── desktop/
│       │   ├── admin_main_layout.dart     (16.3 KB) — RTL + BorderDirectional ✅
│       │   ├── employee_main_layout.dart  (14.8 KB) — i18n B ✅
│       │   ├── pos_screen.dart            (44.0 KB) — uses InvoiceService v3 | 🔲 i18n C3
│       │   ├── shift_dialog.dart          (3.8 KB)  — i18n v4 ✅
│       │   ├── close_shift_screen.dart    (9.9 KB)  — i18n v4 ✅
│       │   ├── end_of_day_report.dart     (10.9 KB) — i18n v4 ✅
│       │   └── refund_modal.dart          (8.2 KB)  — i18n C1 ✅
│       ├── admin/
│       │   ├── dashboard_screen.dart      (29.4 KB) — dynamic Arabic dates ✅ i18n C1
│       │   ├── ajouter_produit.dart       (19.8 KB) — i18n C1 ✅
│       │   ├── expenses_screen.dart       (23.9 KB) — v4 | i18n C2 ✅
│       │   ├── debt_recovery_screen.dart  (26.5 KB) — v4 | i18n C2 ✅
│       │   ├── gestion_employes.dart      (15.0 KB) — i18n C2 ✅
│       │   ├── gestion_clients.dart       (32.9 KB) — 🔲 i18n C3
│       │   ├── gestion_fournisseurs.dart  (26.6 KB) — 🔲 i18n C3
│       │   ├── gestion_stores.dart        (16.2 KB) — 🔲 i18n C3
│       │   ├── liste_produits.dart        (29.6 KB) — 🔲 i18n C3
│       │   ├── inventory_screen.dart      (31.2 KB) — v4 fix (casting) | 🔲 i18n C3
│       │   ├── achat_fournisseur.dart     (21.0 KB) — 🔲 i18n C3
│       │   ├── sales_history_screen.dart  (8.3 KB)  — i18n B ✅
│       │   └── activity_logs_screen.dart  (6.8 KB)  — i18n B ✅
│       ├── mobile/
│       │   └── owner_dashboard.dart       (55.0 KB) — 🔲 i18n C4 (~215 سلسلة)
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

### الجداول (14 جدول)

| الجدول | RLS | السجلات | الأعمدة | الإصدار | ملاحظات |
|---|:---:|:---:|:---:|---|---|
| `stores` | ✅ | 5 | 6 | v1 | ⚠️ RLS مفتوح `USING(true)` |
| `user_profiles` | ✅ | 6 | 7 | v1 | ⚠️ RLS مفتوح `USING(true)` |
| `customers` | ✅ | 1+ | 9 | v1 | ✅ |
| `suppliers` | ✅ | 1+ | 9 | v1 | ⚠️ RLS مفتوح `USING(true)` |
| `products` | ✅ | 8 | 8 | v1 | ✅ |
| `product_variants` | ✅ | 6 | 10 | v1 | ⚠️ RLS مفتوح `USING(true)` |
| `inventory` | ✅ | 8 | 6 | v1 | ✅ |
| `invoices` | ✅ | 32 | 14 | v1 | ✅ |
| `payments` | ✅ | 37 | 14 | **v4** | `payment_type` enum: invoice/debt_recovery |
| `transactions` | ✅ | 50+ | 14 | v1 | ⚠️ سياسة RLS بطيئة |
| `activity_logs` | ✅ | 50+ | 6 | v1 | ⚠️ RLS مفتوح `USING(true)` |
| `shifts` | ✅ | 4 | 11 | **v2** | ⚠️ سياستان RLS بطيئتان |
| `expense_categories` | ✅ | 0 ⚠️ | 4 | **v4** | فارغ — لم يُضاف بيانات بعد |
| `expenses` | ✅ | 0 ⚠️ | 9 | **v4** | فارغ — لم يُضاف بيانات بعد |

> ❌ **تحذير:** جدول `settings` مذكور في الكود (`SettingsLocal`) لكنه **غير موجود في Supabase** — الإعدادات تُحفظ محلياً في Isar فقط. يجب إنشاء Migration لهذا الجدول.

### دوال RPC النشطة (12+)

| الدالة | الإصدار | الملاحظة |
|---|---|---|
| `process_sale` | v1→v3 ✅ | Atomic: فاتورة + مخزون + ربط شيفت. إصدار واحد فقط (v1 بدون p_shift_id تم حذفه في v3) |
| `process_purchase` | v1 | أوامر الشراء + تحديث المخزون |
| `process_refund` | v2→v3 ✅ | Atomic: إلغاء فاتورة + إعادة مخزون عبر trigger + سجل محاسبي. يُعيّن `user_id = auth.uid()` صراحةً |
| `open_shift` | v2 ✅ | فتح شيفت كاشير |
| `close_shift` | v2 ✅ | إغلاق + حساب الفارق |
| `get_active_shift` | v2 ✅ | يُعيد null للشيفتات من أيام سابقة |
| `add_expense` | v4 ✅ | إدراج مصروف تشغيلي ذري |
| `add_debt_recovery_payment` | v4 ✅ | دفعة بدون فاتورة — تخفض رصيد العميل |
| `update_balance_from_invoice` | v1 | Trigger — مزامنة رصيد العميل |
| `update_balance_from_payment` | v1 | Trigger — مزامنة رصيد بعد الدفع |
| `handle_inventory_transaction` | v1 | **Trigger على كل INSERT/UPDATE/DELETE في transactions** |
| `handle_new_user` | v1 | Auth Trigger — إعداد المستخدم الجديد |
| `get_current_user_profile` | v1 | جلب ملف المستخدم المصادق |
| `log_transaction_activity` | v1 | Audit trail |

### Edge Functions (2) ⚠️

| الاسم | الحالة | JWT | الإصدار | خطر |
|---|---|---|---|---|
| `create_employee` | ✅ ACTIVE | ❌ معطّل | v3 | 🔴 أي شخص يستطيع إضافة موظف |
| `delete_employee` | ✅ ACTIVE | ❌ معطّل | v2 | 🔴 أي شخص يستطيع حذف موظف |

### Migrations المسجلة (9)

| التاريخ | الاسم |
|---|---|
| 2026-03-06 | `init_schema` |
| 2026-03-06 | `create_shoes_images_bucket` |
| 2026-03-06 | `add_sell_price_to_variants` |
| 2026-03-12 | `process_sale_rpc` |
| 2026-03-12 | `process_purchase_rpc` |
| 2026-04-16 | `create_user_profile_helper` |
| 2026-04-16 | `secure_all_policies_fixed` |
| 2026-04-16 | `secure_transactions_payments_storage` |
| 2026-04-19 | `expenses_module` |

### Isar Collections (16)

| Collection | تعكس | synced |
|---|---|---|
| `StoreLocal` | `stores` | — |
| `UserProfileLocal` | `user_profiles` | — |
| `CustomerLocal` | `customers` + address | — |
| `SupplierLocal` | `suppliers` | — |
| `ProductLocal` | `products` | — |
| `ProductVariantLocal` | `product_variants` + `@Index(barcode)` | — |
| `InventoryLocal` | `inventory` + composite index | — |
| `InvoiceLocal` | `invoices` | ✅ |
| `PaymentLocal` | `payments` + paymentType | ✅ |
| `TransactionLocal` | `transactions` | ✅ |
| `ShiftLocal` | `shifts` | ✅ |
| `ExpenseCategoryLocal` | `expense_categories` | — |
| `ExpenseLocal` | `expenses` | ✅ |
| `SettingsLocal` | — (محلي فقط) | — |
| `SyncQueueItem` | Queue: operationType + payloadJson + retryCount | — |
| `SyncMetadata` | Singleton: lastSyncAt + mode + pendingCount | — |

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

### v2 — إدارة الشيفت والمرتجعات *(مكتمل أبريل 2026)*
- [x] `shift_dialog.dart` — حوار غير إلزامي ثنائي اللغة FR/AR عند فتح POS
- [x] `end_of_day_report.dart` — حالة A: مع ملخص مبيعات + فارق / حالة B: بدون شيفت
- [x] `close_shift_screen.dart` — إغلاق مدمج مع فارق فوري (أخضر فائض / أحمر عجز)
- [x] انتهاء صلاحية الشيفت — `getActiveShift()` يُعيد null للأيام السابقة
- [x] تحذير للشيفتات غير المغلقة من اليوم السابق
- [x] كل فاتورة ودفعة مرتبطة بـ `shift_id`
- [x] `AppSession.currentShiftId` — متغير جلسة عالمي
- [x] `refund_modal.dart` — مرتجع بمستوى العنصر + محدد الكمية + حقل السبب
- [x] `process_refund` RPC — ذري: فاتورة→refunded + إعادة مخزون عبر trigger + قيد محاسبي

### v3 — نظام Hybrid Offline/Online *(مكتمل 18 أبريل 2026)* ✅
- [x] 16 Isar Collection تعكس Supabase
- [x] `SeedService` — تحميل 13 جدول في ترتيب FK-safe، نافذة 30 يوم للبيانات المعاملاتية
- [x] `SyncEngine` — إعادة تشغيل SyncQueueItem ضد Supabase RPCs، 3 محاولات ثم failed
- [x] `InvoiceService` — Offline-aware: online→RPC / offline→Isar+Queue
- [x] حوار اختيار الوضع بعد تسجيل الدخول (Online / Offline)
- [x] `OfflineBanner` — شريط علوي دائم: حالة الاتصال + عداد المزامنة المعلقة + زر مزامنة يدوية
- [x] `AppSession` موسّع: `isOfflineMode`, `pendingSync`, `currentUserId`
- [x] `ConnectivityService` — Singleton يُشغّل `SyncEngine.syncPending()` تلقائياً عند الاتصال

### v4 — المصاريف + تحصيل الديون + التعريب *(قيد التطوير — أبريل 2026)*
- [x] جداول `expense_categories` و `expenses` مع RLS
- [x] RPCs ذرية: `add_expense` + `add_debt_recovery_payment`
- [x] `ExpenseService` + `DebtRecoveryService` — Offline-aware
- [x] `ExpensesScreen` — إحصائيات شهرية (إجمالي، عدد، أعلى) + فلاتر الفئة + حوارات الإضافة
- [x] `DebtRecoveryScreen` — Master-detail: قائمة عملاء مرتبة بالدين + تبويبات سجل الدفع + حوار الدفع الفوري مع معاينة الرصيد
- [x] `SyncOperationType` موسّع: `createExpense` + `createDebtRecoveryPayment`
- [x] تسجيل Admin nav: index 11 (Dépenses) + index 12 (Recouvrement)
- [x] البنية التحتية للتعريب (~280+ مفتاح AR/FR)
- [x] **Phase C2 مكتمل (25 أبريل 2026)** — إصلاح أخطاء البناء في debt_recovery, expenses, gestion_employes

---

## 🌍 حالة التعريب (i18n)

| المرحلة | الملفات | الحالة |
|---|---|---|
| **Phase A** | `app_strings.dart` (~280+ مفتاح) + `SettingsLocal` + `AppSession.locale` ValueNotifier | ✅ مكتمل |
| **Phase B** | `offline_banner`, `login_screen`, `admin_main_layout`, `employee_main_layout`, `shift_dialog`, `close_shift_screen`, `end_of_day_report`, `activity_logs_screen`, `sales_history_screen` | ✅ مكتمل |
| **Phase C1** | `refund_modal`, `dashboard_screen`, `ajouter_produit` | ✅ مكتمل |
| **Phase C2** | `debt_recovery_screen`, `expenses_screen`, `gestion_employes` | ✅ **مكتمل 25 أبريل 2026** |
| **Phase C3** | `gestion_stores`, `achat_fournisseur`, `inventory_screen`, `liste_produits`, `gestion_fournisseurs`, `gestion_clients`, `pos_screen` | ✅ **مكتمل 25 أبريل 2026** |
| **Phase C4** | `owner_dashboard` (~215 سلسلة) | 🔲 معلّق |

**تفاصيل البنية التقنية للتعريب:**
- `AppSession.locale` — `ValueNotifier<String>` يُغلّف `MaterialApp` لإعادة بناء كاملة عند تغيير اللغة
- `S.t('key')` — وصول ثابت (static) قابل للاستخدام في أي مكان بدون `BuildContext`
- `SettingsLocal` — Isar singleton (id=1) يحفظ اللغة عبر إعادات التشغيل
- اللغة الافتراضية: **عربي** — التطبيق يفتح بالعربية عند أول تشغيل
- RTL: Flutter يتعامل مع 90% تلقائياً عبر `Locale('ar')`. إصلاحات يدوية على `EdgeInsetsDirectional` + `BorderDirectional` + أيقونات الاتجاه

---

## 🗺️ خريطة الطريق

| الأولوية | الوحدة | الوصف | الحالة |
|---|---|---|---|
| 🔴 عالية | **Bilingual UI C3** | POS + Inventory + Clients + Suppliers + Stores | ✅ مكتمل |
| 🔴 عالية | **Bilingual UI C4** | Mobile owner dashboard (~215 سلسلة) | 🔲 التالي |
| 🔴 عالية | **Receipt Printing** | طابعة حرارية 80mm + توليد PDF للفواتير | 🔲 معلّق |
| 🔴 عالية | **Low Stock Alerts** | حد أدنى للمخزون لكل متغير + لوحة إعادة الطلب | 🔲 معلّق |
| 🟡 متوسطة | **Analytics Dashboard** | اتجاهات المبيعات، أفضل المنتجات، تحليل الهامش | 🔲 معلّق |
| 🟡 متوسطة | **Mobile Audit Tool** | استكمال شاشات تدقيق المستودع Android/iOS | 🔲 معلّق |
| 🟢 مستقبل | **Multi-branch Reporting** | تقارير مالية موحدة عبر الفروع | 🔲 مخطط |
| 🟢 مستقبل | **Employee Performance** | مبيعات لكل كاشير، إنتاجية الشيفت | 🔲 مخطط |

---

## 🔐 الأمان والديون التقنية

### 🔴 مشاكل حرجة (تمنع الإنتاج الكامل)

| # | المشكلة | الخطورة | الحل |
|---|---|---|---|
| 1 | **Edge Functions بدون JWT** — `create_employee` و `delete_employee` مكشوفتان | أي شخص يضيف/يحذف موظفاً | تفعيل `verify_jwt = true` في Supabase Dashboard |
| 2 | **28 FK بدون فهارس** — بطء شديد عند نمو البيانات | أداء متدهور في الإنتاج | Migration واحد يضيف 28 فهرساً |
| 3 | **جدول `settings` مفقود** من Supabase | تناقض بين الكود والـ DB | Migration لإنشاء الجدول |

### 🟡 مشاكل مهمة (تؤثر على الجودة والأمان)

| # | المشكلة | الحل |
|---|---|---|
| 4 | **5 جداول RLS مفتوحة** — `activity_logs`, `product_variants`, `stores`, `suppliers`, `user_profiles` تستخدم `USING(true)` | تشديد السياسات بربطها بـ `store_id` أو الدور |
| 5 | **12 RPC بدون `search_path`** — ثغرة Schema Poisoning محتملة | إضافة `SET search_path = ''` لكل دالة |
| 6 | **5 سياسات RLS بطيئة** — `transactions`, `shifts`, `expenses` تستدعي `auth.uid()` لكل صف | استبدال بـ `(select auth.uid())` |
| 7 | **سياستان متسامحتان على `shifts`** — تبطئ كل استعلام | دمجهما في سياسة واحدة |
| 8 | **Isar بدون تشفير** — البيانات المحلية مكشوفة على الجهاز | `encryptionKey` مرتبط بـ device ID |
| 9 | **Supabase Keys في الكود** — مفاتيح API مدمجة | `--dart-define` environment variables |
| 10 | **Leaked Password Protection معطّل** | تفعيله من Supabase Dashboard → Auth → Settings |
| 11 | **Storage Buckets مكشوفة** — `app_images` و `shoes-images` | تقييد سياسات القراءة |

> **ملاحظة:** مهمة الأمان الكاملة (Isar + SyncQueue encryption + obfuscation) مُوكلة لشخص آخر ✅

### 🟢 تحسينات للاحترافية

| # | المشكلة |
|---|---|
| 12 | لا توجد Unit Tests — مجلد `test/` يحتوي ملف واحد افتراضي فقط (`widget_test.dart`) |
| 13 | لا يوجد Error Handler موحد — `print(e)` في بعض الأماكن بدلاً من رسائل للكاشير |
| 14 | مجلدا `controllers/` و `features/` فارغان — كود ميت يُربك المطورين الجدد |
| 15 | 35 حزمة تحتاج تحديثاً تدريجياً (غير متوافقة مع القيود الحالية) |
| 16 | `PROJECT_PROGRESS.md` يعكس v1 فقط — قديم |
| 17 | لا توجد comments على الدوال الرئيسية (`SyncEngine`, `InvoiceService`, `KeyManager`) |

---

## ⚠️ قواعد حرجة يجب حفظها

> هذه القواعد مبنية على تصميم النظام — مخالفتها تُفسد البيانات أو تُعطل النظام.

1. **لا تُعدّل `inventory` يدوياً أبداً داخل أي RPC**  
   `handle_inventory_transaction` trigger يُطلق على كل INSERT/UPDATE/DELETE في `transactions` تلقائياً. أي تعديل يدوي سيُسبب تكراراً في المخزون.

2. **`process_sale` إصدار واحد فقط**  
   الإصدار القديم (v1 بدون `p_shift_id`) تم حذفه في v3. لا يوجد overload — هناك دالة واحدة فقط.

3. **`expenses` منفصل عن `transactions` عمداً**  
   خلط المصاريف التشغيلية مع ledger المخزون سيُفسد سجلات التدقيق المحاسبية.

4. **`payment_type` في `payments` يُميّز نوعين**  
   `invoice` = تسوية فاتورة عادية / `debt_recovery` = دفعة على حساب مفتوح بدون فاتورة.

5. **Flutter = UI فقط، لا حسابات مالية**  
   أي حساب مالي يجب أن يكون في Supabase RPC. Flutter يعرض النتائج فقط.

6. **SyncOperationType موسّع في v4**  
   عند إضافة عمليات offline جديدة، يجب إضافة النوع في `local_enums.dart` + معالجته في `sync_engine.dart`.

7. **`getActiveShift()` يُعيد null للأيام السابقة**  
   الشيفتات منتهية الصلاحية لا تُعتبر نشطة — يجب فتح شيفت جديد كل يوم.

---

## ⚙️ متطلبات التشغيل

### المتطلبات الأساسية
- **FVM** مُثبّت: `dart pub global activate fvm`
- Flutter SDK `3.41.7` عبر FVM (إلزامي — لا تستخدم flutter system مباشرة)
- Visual Studio 2022 Community **(Release — NOT Insiders)**:
  - ✅ Desktop development with C++
  - ✅ MSVC v143 build tools
  - ✅ Windows 11 SDK
- مشروع Supabase مُهيّأ بـ `jluuobtzylejiahbelgp`

### أوامر الإعداد الكاملة
```bash
# المرة الأولى فقط — تثبيت FVM
dart pub global activate fvm
fvm install 3.41.7
fvm use 3.41.7

# تشغيل المشروع (كل مرة بعد تعديل الكود)
fvm flutter clean
fvm flutter pub get
dart run build_runner build --delete-conflicting-outputs
fvm flutter run -d windows

# بناء النسخة النهائية للتسليم
fvm flutter build windows
# المخرج: build/windows/x64/runner/Release/
```

> ⚠️ **مهم:** دائماً أضف `fvm` قبل أي أمر flutter في هذا المشروع.  
> إذا نسيت وشغّلت `flutter run` مباشرة، ستحصل على خطأ SDK version.

### إعداد VS Code (مرة واحدة)
```json
// .vscode/settings.json
{
  "dart.flutterSdkPath": ".fvm/flutter_sdk",
  "search.exclude": { "**/.fvm": true }
}
```

### `.gitignore` — تأكد من وجود هذه الأسطر
```
.fvm/
.env
*.dart-define
build/
```

### عند تغيير CMake أو Visual Studio
إذا واجهت خطأ `generator does not match`:
```bash
fvm flutter clean   # يحذف build/ وكل CMakeCache
fvm flutter pub get
fvm flutter run -d windows
```

### التبعيات الرئيسية
```yaml
dependencies:
  supabase_flutter: ^2.12.0
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  connectivity_plus: ^6.0.5
  google_fonts: ^8.0.2
  mobile_scanner: ^7.2.0
  image_picker: ^1.2.1
  path_provider: ^2.1.2
  intl: ^0.20.2
  timeago: ^3.7.1

dev_dependencies:
  isar_generator: ^3.1.0+1
  build_runner: ^2.4.9
```

---

## 📊 إحصائيات المشروع

| المقياس | القيمة |
|---|---|
| **إجمالي ملفات Dart** | ~50 ملف (بدون `.g.dart`) |
| **ملفات مولّدة `.g.dart`** | 16 ملف |
| **أكبر ملف** | `owner_dashboard.dart` (55 KB) |
| **ثاني أكبر ملف** | `pos_screen.dart` (44 KB) |
| **ملف الترجمة** | `app_strings.dart` (43.5 KB / 934+ سطر) |
| **Isar Collections** | 16 |
| **Supabase Tables** | 14 (+ `settings` مفقود) |
| **Supabase RPCs** | 14 دالة |
| **Edge Functions** | 2 (⚠️ بدون JWT) |
| **Migrations** | 9 |
| **تنبيهات أمنية من Supabase** | 20 (12 search_path + 5 RLS مفتوح + 2 Storage + 1 auth) |
| **FK بدون فهارس** | 28 |
| **صور Assets** | 2 فقط (login) |

---

## 🔖 سجل الإصدارات

| الإصدار | الوصف | التاريخ | الحالة |
|---|---|---|---|
| **v1** | النظام الأساسي: POS + المخزون + الفواتير + المصادقة + متعدد الفروع | مارس 2026 | ✅ إنتاج |
| **v2** | الشيفت + المرتجعات + تقرير نهاية اليوم | أبريل 2026 | ✅ مكتمل |
| **v3** | Hybrid Offline/Online: Isar + SyncEngine + ConnectivityService + OfflineBanner | 18 أبريل 2026 | ✅ مكتمل |
| **v4** | المصاريف + تحصيل الديون + التعريب AR/FR (A→B→C1→C2) | 25 أبريل 2026 | 🔧 قيد التطوير |

---


Offline & Local Database Strategy
Why Isar + Supabase?
ShoeStock uses a dual-database architecture combining Supabase as the cloud backend and Isar as the local database for offline support. Supabase handles real-time data sharing across multiple stores and devices, while Isar ensures the app remains fully functional without an internet connection.
Isar was chosen over other local database solutions (such as SQLite via sqflite or drift) for three main reasons. First, performance — Isar reads and writes Dart objects natively without SQL parsing or manual mapping, making it significantly faster on low-end Android devices commonly used in retail environments. Second, reactivity — Isar's built-in watchLazy() streams allow the UI to update automatically when local data changes, without any additional state management overhead. Third, developer experience — defining data models as plain Dart classes with @collection annotations eliminates boilerplate and keeps the codebase consistent with Dart idioms.
When the device is online, all write operations are persisted to Isar first, then synced to Supabase. When offline, operations are queued locally and synced automatically upon reconnection. This approach guarantees zero data loss and a seamless experience for store employees regardless of network conditions.


ستراتيجية قاعدة البيانات المحلية والمزامنة
لماذا Isar مع Supabase؟
يعتمد تطبيق ShoeStock على معمارية ثنائية تجمع بين Supabase كقاعدة بيانات سحابية وIsar كقاعدة بيانات محلية لدعم العمل بدون إنترنت. يتولى Supabase مشاركة البيانات في الوقت الفعلي بين المتاجر والأجهزة المختلفة، بينما يضمن Isar استمرار عمل التطبيق بكامل وظائفه حتى في غياب الاتصال بالشبكة.
تم اختيار Isar على حساب بدائل أخرى كـ SQLite عبر مكتبتَي sqflite أو drift لثلاثة أسباب رئيسية. أولاً، الأداء — يخزن Isar كائنات Dart مباشرةً دون الحاجة إلى تحليل SQL أو تحويل يدوي للبيانات، مما يجعله أسرع بشكل ملحوظ على أجهزة Android المتوسطة والمنخفضة المواصفات الشائعة في بيئات نقاط البيع. ثانياً، التفاعلية — توفر Isar دعماً مدمجاً لـ watchLazy() يتيح تحديث واجهة المستخدم تلقائياً عند أي تغيير في البيانات المحلية، دون الحاجة إلى طبقات إضافية لإدارة الحالة. ثالثاً، سهولة التطوير — يُعرَّف نموذج البيانات كـ Dart class عادي باستخدام @collection، مما يقلل الكود المتكرر ويحافظ على اتساق قاعدة الكود مع أسلوب Dart.
عند اتصال الجهاز بالإنترنت، تُحفظ جميع العمليات في Isar أولاً ثم تُزامَن مع Supabase فوراً. وعند انقطاع الاتصال، تُوضع العمليات في قائمة انتظار محلية وتُرسَل تلقائياً عند عودة الشبكة. يضمن هذا النهج عدم ضياع أي بيانات ويوفر تجربة سلسة لموظفي المتاجر بصرف النظر عن حالة الاتصال.



## 👤 المطور الرئيسي

**Lead Systems Architect & Digital Transformation Consultant**  
*Leitender Systemarchitekt und Berater für digitale Transformation*

---

*آخر تحديث: 25 أبريل 2026*  
*v1: إنتاج ✅ | v2: مكتمل ✅ | v3: مكتمل ✅ | v4: قيد التطوير 🔧*  
*الجلسة الحالية: C4 → طباعة الفواتير → تنبيهات المخزون*  
*الأولوية الأمنية: JWT Edge Functions → 28 FK Indexes → RLS search_path*
