# 👟 ShoeStock ERP & POS — نظام إدارة متكامل للأحذية

**الإصدار الحالي:** v5.2 | **تاريخ آخر تحديث:** 29 مايو 2026  
> **حالة Supabase:** ✅ `ACTIVE_HEALTHY` | **المنطقة:** `eu-west-3` (باريس)  
> **Flutter SDK:** `3.41.7` (FVM) | **Dart SDK:** `^3.11.0`  
> **Project ID:** `jluuobtzylejiahbelgp`

---

## 📋 فهرس المحتويات

1. [نظرة عامة](#نظرة-عامة)
2. [البنية المعمارية](#البنية-المعمارية)
3. [قاعدة البيانات](#قاعدة-البيانات)
4. [جميع الميزات المكتملة (65)](#جميع-الميزات-المكتملة-65)
5. [الحزم المضافة حديثاً](#الحزم-المضافة-حديثاً)
6. [حالة التعريب i18n](#حالة-التعريب)
7. [إنجازات الجلسة الحالية (مايو 2026)](#إنجازات-الجلسة-الحالية-مايو-2026)
8. [خريطة الطريق](#خريطة-الطريق)
9. [الأمان والديون التقنية](#الأمان-والديون-التقنية)
10. [قواعد حرجة يجب حفظها](#قواعد-حرجة-يجب-حفظها)
11. [متطلبات التشغيل](#متطلبات-التشغيل)
12. [إحصائيات المشروع](#إحصائيات-المشروع)
13. [سجل الإصدارات](#سجل-الإصدارات)

---

## 🌐 نظرة عامة

ShoeStock ERP ليس مجرد تطبيق برمجي — بل هو حل تجاري هندسي متكامل لرقمنة دورة الحياة التشغيلية لمحلات الأحذية. المشروع ثمرة هندسة ميدانية (Field Engineering) حقيقية: زيارات متعددة لورشة تصنيع أحذية، مقابلات معمّقة مع الموظفين والمحاسبين والمديرين، وترجمة إجراءات يدوية معقدة إلى هيكل رقمي عالي الأداء.

| البند | القيمة |
|---|---|
| **النوع** | ERP + POS متكامل |
| **المنصات** | Windows (أساسي) + Android/iOS/Web (ثانوي) |
| **Backend** | Supabase / PostgreSQL 17.6 |
| **قاعدة البيانات المحلية** | Isar v3.1.0+1 (Offline-First) |
| **العمارة** | Hybrid Online/Offline + RPC-Based + Service Layer |
| **اللغات** | عربي (افتراضي) + فرنسي |
| **الخطوط AR** | `GoogleFonts.cairo()` (body) + `GoogleFonts.amiri()` (headings) |
| **الخطوط FR** | `GoogleFonts.raleway()` + `GoogleFonts.playfairDisplay()` |
| **PKI** | Sentry Performance Monitoring |
| **Barcode** | USB scanner (Windows) + `mobile_scanner` (Mobile) |

---

## 🏗️ البنية المعمارية — Architecture Decisions

```text
┌────────────────────────────────────────────────────────────┐
│                    Flutter (UI فقط)                        │
│  Windows POS  ←→  Android/iOS/Web  ←→  Desktop Admin      │
├────────────────────────────────────────────────────────────┤
│             Isar Local DB (Offline Layer)                  │
│  15 Collections  │  SyncQueue  │  ConnectivityService      │
├────────────────────────────────────────────────────────────┤
│              SyncEngine (Queue Replay)                     │
│  Mutex lock  │  Max 5 retries  │  Conflict detection       │
│  Exponential backoff  │  Priority ordering                 │
├────────────────────────────────────────────────────────────┤
│           Supabase Cloud (Source of Truth)                 │
│  21 Tables  │  33+ RPCs  │  6 Edge Functions  │  RLS       │
└────────────────────────────────────────────────────────────┘
```

### المبادئ المعمارية الأساسية

1. **Flutter = UI only.** جميع الحسابات المالية داخل Supabase RPCs حصراً. لا يجوز أبداً إجراء حسابات مالية في كود Flutter.
2. **Service Layer للكتابة.** كل عملية كتابة (إنشاء فاتورة، إضافة مصروف، تسديد دين) تمر عبر Service class مخصص يدير التفرع Online/Offline.
3. **Isar writeTxn = entity + SyncQueueItem ذري.** عند العمل Offline، تكتب البيانات المحلية وإدخال SyncQueue في نفس المعاملة لضمان التكامل.
4. **SyncEngine.** يعيد تشغيل `SyncQueueItem` المعلقة مع `Mutex` لمنع race conditions، و `exponential backoff` بحد أقصى 5 محاولات، وتصنيف `conflict` للعناصر المتضاربة للفحص اليدوي.
5. **التحقق في RPC.** يتم التحقق من `credit_limit` و `max_discount_percent` على مستوى RPC قبل تنفيذ أي عملية.
6. **لا تُعدّل `inventory` يدوياً.** Trigger `handle_inventory_transaction` هو المسؤول الوحيد عن تحديث المخزون.

### طبقات الخدمة (Service Layer)

| الخدمة | الملف | الوصف |
|---|---|---|
| `InvoiceService` | `services/invoice_service.dart` | Online→RPC / Offline→Isar+Queue |
| `RefundService` | `services/refund_service.dart` | Online→RPC / Offline→Isar+Queue |
| `ExpenseService` | `services/expense_service.dart` | Online→RPC / Offline→Isar+Queue |
| `DebtRecoveryService` | `services/debt_recovery_service.dart` | Online→RPC / Offline→Isar+Queue |
| `PurchaseService` | `services/purchase_service.dart` | Online→RPC batch / Offline→Isar+Queue |
| `BackupService` | `services/backup_service.dart` | Inactivity auto-backup + manual |
| `ReportService` | `services/report_service.dart` | PDF generation + export |
| `ReceiptService` | `services/receipt_service.dart` | Thermal receipt PDF + share/print |
| `PreferencesService` | `core/preferences_service.dart` | Web localStorage wrapper |
| `ApiVersionService` | `core/api_version_service.dart` | Version check via Edge Function |
| `InactivityTimer` | `services/inactivity_timer.dart` | Auto sign-out after timeout |

### المزامنة (SyncEngine)

- **Mutex**: قفل على مستوى المزامنة — `_syncMutex.lock()` قبل البدء.
- **Exponential Backoff**: `min(2^retry * 1000, 30000)` مللي ثانية بين المحاولات.
- **Conflict Detection**: إذا فشلت العملية بسبب تعارض بيانات، يُوسم العنصر بـ `conflict` ويُترك للفحص اليدوي.
- **IdempotencyKey**: لكل عنصر في SyncQueue مفتاح idempotency لضمان عدم تكرار العمليات عند إعادة المحاولة.
- **ConnectivityService**: يُشغّل SyncEngine تلقائياً عند استعادة الاتصال.

---

## 🗄️ قاعدة البيانات

### الجداول الأساسية (13)

| الجدول | الحالة | ملاحظات |
|---|---|---|
| `stores` | ✅ | مع `max_discount_percent` |
| `user_profiles` | ✅ | مع `commission_rate` و `language` و `last_login_at` |
| `customers` | ✅ | مع `credit_limit` و `loyalty_points` و `customer_type` |
| `suppliers` | ✅ | |
| `products` | ✅ | مع `is_archived` |
| `product_variants` | ✅ | مع `barcode`، `unit_type`، `units_per_carton`، `wholesale_price` |
| `inventory` | ✅ | |
| `invoices` | ✅ | بدون shift_id |
| `payments` | ✅ | مع `payment_type` (invoice/debt_recovery) |
| `transactions` | ✅ | مع `profit_margin` |
| `activity_logs` | ✅ | |
| `expense_categories` | ✅ | |
| `expenses` | ✅ | |

### الجداول الجديدة المضافة خلال الجلسة (8)

| الجدول | الغرض |
|---|---|
| `stock_counts` | جرد المخزون |
| `stock_count_items` | عناصر الجرد |
| `product_bundles` | الحزم التسويقية (Bundle Deals) |
| `bundle_items` | عناصر الحزمة |
| `promotions` | العروض والخصومات الزمنية |
| `purchase_orders` | أوامر الشراء |
| `purchase_order_items` | عناصر أمر الشراء |
| `stock_transfers` | تحويل المخزون بين الفروع |

### دوال RPC النشطة (33+)

| الدالة | الوصف |
|---|---|
| `process_sale` (v3) | معالجة البيع — النسخة الوحيدة بدون shift_id، مع discount + commission + profit_margin |
| `process_purchase` | معالجة الشراء |
| `process_refund` | المرتجع الذري |
| `add_expense` | إضافة مصروف |
| `add_debt_recovery_payment` | دفعة تحصيل ديون |
| `get_customer_balance` | حساب رصيد العميل (RPC بدلاً من client-side) |
| `get_supplier_balance` | حساب رصيد المورد (RPC بدلاً من client-side) |
| `get_analytics_summary` | ملخص التحليلات مع نسب محسوبة مسبقاً |
| `adjust_inventory` | تعديل المخزون مع سبب (كسر/سرقة/جرد/أخرى) |
| `close_stock_count` | إغلاق جرد المخزون وتحديث الكميات |
| `get_store_bundles` | جلب الحزم المتاحة لمتجر معين |
| `get_size_analytics` | تحليل المبيعات حسب المقاسات |
| `get_inventory_turnover` | معدل دوران المخزون |
| `get_sales_forecast` | توقعات المبيعات (linear regression) |
| `execute_stock_transfer` | تنفيذ تحويل مخزون بين الفروع |
| `get_employee_commission_summary` | ملخص عمولات الموظفين |
| `get_overdue_customers` | العملاء المتأخرين في السداد |
| `get_low_stock_items` | عناصر المخزون المنخفض |
| `get_store_comparison` | مقارنة أداء الفروع |
| `get_slow_moving_products` | المنتجات بطيئة الحركة |
| `get_employee_performance` | أداء الموظفين (مبيعات/مرتجعات) |
| `approve_purchase_order` | الموافقة على أمر شراء (ينشئ فاتورة) |
| `insert_variants_batch` | إدراج متغيرات منتج بالجملة |
| `redeem_loyalty_points` | استبدال نقاط الولاء |
| `get_active_promotions` | العروض النشطة حالياً |
| `get_admin_dashboard_stats` | إحصائيات لوحة تحكم المدير |
| `get_employee_dashboard_stats` | إحصائيات لوحة تحكم الموظف |
| `get_owner_financial_summary` | ملخص مالي للمالك |
| `get_revenue_chart_data` | بيانات الرسم البياني للإيرادات |
| `get_store_performance` | أداء المتاجر |
| `get_top_products` | أفضل المنتجات |
| `create_purchase_order` | إنشاء أمر شراء |
| `award_loyalty_points` | منح نقاط ولاء (trigger) |

### Edge Functions

| الاسم | JWT | الوصف |
|---|---|---|
| `create_employee` | ✅ مفعّل | إنشاء موظف جديد |
| `update_employee` | ✅ مفعّل | تحديث بيانات الموظف (مع commission_rate) |
| `delete_employee` | ✅ مفعّل | حذف موظف |
| `toggle_employee_status` | ✅ مفعّل | تفعيل/تعطيل موظف |
| `get_minimum_version` | ❌ معطّل | التحقق من الحد الأدنى للإصدار (read-only) |
| `api_version` | ❌ معطّل | إصدار API (read-only) |

### Triggers

- `update_balance_from_invoice` — تحديث رصيد العميل/المورد تلقائياً
- `update_balance_from_payment` — تحديث الرصيد عند الدفع
- `handle_inventory_transaction` — تحديث المخزون تلقائياً (لا يُعدّل يدوياً)
- `handle_new_user` — إنشاء سجل user_profile عند التسجيل
- `generate_barcode` — توليد باركود عشوائي عند إنشاء متغير
- `log_transaction_activity` — تسجيل النشاطات

---

## ✅ جميع الميزات المكتملة (65)

### 🔄 المزامنة والـ Offline-First (7)
- [x] 15 Isar Collection تعكس البيانات المحلية
- [x] `SeedService` — تحميل الجداول الأساسية بترتيب FK-safe
- [x] `SyncEngine` — إعادة تشغيل SyncQueueItem مع retry logic
- [x] `ConnectivityService` — يُشغّل SyncEngine عند العودة للاتصال
- [x] Mutex guard يمنع race conditions قبل أول await
- [x] Isar write + SyncQueue enqueue في معاملة ذرية واحدة
- [x] Exponential backoff (max 5 retries) + تصنيف failed/conflict
- [x] Incremental pull في SeedService عبر `updated_at` filter
- [x] Conflict detection في SyncEngine مع حالة `conflict`

### ❌ إزالة نظام الوردية (7)
- [x] حذف `shifts` من Supabase
- [x] حذف `shift_id` من `invoices` و `payments`
- [x] تحديث `process_sale` بدون `p_shift_id`
- [x] حذف ملفات Flutter الخاصة بالوردية (shift_dialog, close_shift_screen, end_of_day_report, shift_service)
- [x] حذف `ShiftLocal` من Isar
- [x] حذف `currentShiftId` من `AppSession`
- [x] حذف مراجع الوردية من `pos_screen`, `employee_main_layout`, `sales_history_screen`

### 🔐 الأمان (5)
- [x] تفعيل `verify_jwt = true` على Edge Functions (create_employee, update_employee, delete_employee, toggle_employee_status)
- [x] قفل PIN/Biometric مع `local_auth`
- [x] Inactivity timer يوقع المستخدم تلقائياً بعد انتهاء المهلة
- [x] `credit_limit` على العملاء — التحقق في POS + process_sale RPC
- [x] `max_discount_percent` على المتاجر — التحقق في POS

### 📦 المخزون (8)
- [x] إدارة المخزون الفوري
- [x] التحقق من `InventoryLocal.quantity` قبل الإضافة إلى السلة
- [x] `adjust_inventory` RPC — تعديل المخزون مع سبب (كسر/سرقة/جرد/أخرى)
- [x] `stock_counts` / `stock_count_items` — نظام جرد المخزون
- [x] `close_stock_count` RPC — إغلاق الجرد وتحديث الكميات
- [x] `stock_transfers` — تحويل المخزون بين الفروع
- [x] `execute_stock_transfer` RPC — تنفيذ التحويل
- [x] Barcode scanner (USB Windows + mobile_scanner للجوال)

### 💰 المبيعات ونقاط البيع (10)
- [x] POS متكامل (Windows + Mobile)
- [x] الفواتير مع معالجة المدفوعات
- [x] `process_sale` v3 — خصم، عمولة، هامش ربح
- [x] `process_refund` — مرتجع ذري بمستوى العنصر
- [x] `refund_modal.dart` — حقل سبب + اختيار الكمية
- [x] `get_customer_balance` RPC — رصيد العميل (بدلاً من client-side)
- [x] `get_supplier_balance` RPC — رصيد المورد (بدلاً من client-side)
- [x] خصم تلقائي داخل RPC (بدلاً من client-side)
- [x] `ReceiptService` — إيصال PDF + طباعة/مشاركة
- [x] `CartItem` مستخرج إلى shared model

### 📥 المشتريات (4)
- [x] `purchase_orders` / `purchase_order_items` — أوامر الشراء
- [x] `create_purchase_order` RPC + `approve_purchase_order` RPC
- [x] شاشة أوامر الشراء
- [x] `PurchaseService` مع تفرع online/offline و batch RPC

### 💳 المالية (8)
- [x] `get_analytics_summary` RPC — كل حسابات التحليلات في RPC
- [x] `profit_margin` في كل transaction
- [x] `add_expense` RPC + `add_debt_recovery_payment` RPC
- [x] `ExpenseService` + `DebtRecoveryService` — مع تفرع online/offline
- [x] `RefundService` — استبدال استدعاءات RPC المباشرة
- [x] `get_overdue_customers` RPC + debt_overdue_days setting
- [x] `redeem_loyalty_points` RPC — استبدال نقاط الولاء
- [x] `award_loyalty_points` trigger — منح نقاط تلقائياً

### 📊 التحليلات والتقارير (12)
- [x] `get_size_analytics` RPC — تحليل المبيعات حسب المقاس
- [x] `get_inventory_turnover` RPC — معدل دوران المخزون
- [x] `get_sales_forecast` RPC — توقعات المبيعات (linear regression)
- [x] `get_store_comparison` RPC — مقارنة الفروع
- [x] `get_slow_moving_products` RPC — المنتجات بطيئة الحركة
- [x] `get_employee_performance` RPC — أداء الموظفين
- [x] `get_employee_commission_summary` RPC — ملخص العمولات
- [x] `get_low_stock_items` RPC — عناصر المخزون المنخفض
- [x] `ReportService` — توليد PDF وتصدير
- [x] Owner dashboard مقسم إلى section widgets
- [x] Bar chart للمبيعات (fl_chart)
- [x] Admin dashboard + Employee dashboard

### 🎨 واجهة المستخدم وتجربة المستخدم (13)
- [x] Product bundles — `product_bundles`/`bundle_items` + `get_store_bundles` RPC + UI في POS
- [x] Promotions — `promotions` جدول + شاشة CRUD + `get_active_promotions` RPC
- [x] Wholesale pricing — `customer_type` + `wholesale_price` fields
- [x] Loyalty points — `loyalty_points` في customers + `redeem_loyalty_points` RPC
- [x] `extractCartItemToSharedModel` — CartItem مستخرج
- [x] Shoe constants — `kShoeColors` و `kSizesByCategory` مستخرجة
- [x] Contact utils — `cleanPhone`, `sendWhatsApp`, `sendSMS` مستخرجة
- [x] RefreshIndicator على جميع شاشات القوائم
- [x] AppStrings bilingual — استخراج كل النصوص إلى ملف ترجمة واحد
- [x] FilterBottomSheet — فلتر متقدم
- [x] ConfirmDialog — تأكيد موحد
- [x] تحرير/حذف في شاشة المتاجر
- [x] تحرير/أرشفة في شاشة المنتجات

### 📱 دعم المنصات (3)
- [x] Web platform — `shared_preferences` بدلاً من localStorage
- [x] Barcode PDF generation مع `share_plus`
- [x] دعم Windows (أساسي) + Android/iOS/Web (ثانوي)

### 🛠️ الخدمات المساعدة (6)
- [x] `HealthScreen` — حالة المزامنة، إحصائيات Isar، trigger يدوي
- [x] `BackupService` — نسخ احتياطي تلقائي ويدوي
- [x] `PreferencesService` — غلاف لـ shared_preferences
- [x] `ApiVersionService` — التحقق من الإصدار عبر Edge Function
- [x] `Multi-language per user` — تخزين تفضيل اللغة في `user_profiles.language`
- [x] `Last login tracking` — تسجيل `last_login_at`
- [x] Sentry integration — error handler مع user context و performance monitoring
- [x] Version check — `get_minimum_version` Edge Function

---

## 📦 الحزم المضافة حديثاً (خلال الجلسة)

| الحزمة | الإصدار | الغرض |
|---|---|---|
| `sentry_flutter` | ^8.12.0 | مراقبة الأخطاء والأداء |
| `mobile_scanner` | ^7.2.0 | مسح الباركود عبر كاميرا الجوال |
| `share_plus` | ^10.1.4 | مشاركة ملفات PDF |
| `local_auth` | ^2.3.0 | قفل بصمة/PIN |
| `package_info_plus` | ^8.3.0 | معلومات إصدار التطبيق |
| `shared_preferences` | ^2.3.4 | تخزين التفضيلات (خاص بـ Web) |
| `fl_chart` | ^0.69.0 | الرسوم البيانية |
| `pdf` | ^3.11.1 | توليد PDF |
| `printing` | ^5.13.1 | طباعة الإيصالات |
| `barcode` | ^2.2.8 | توليد باركود |
| `intl` | ^0.20.2 | التواريخ متعددة اللغات |
| `timeago` | ^3.7.1 | أزمنة نسبية |
| `connectivity_plus` | ^6.0.5 | مراقبة الاتصال |
| `isar` / `isar_flutter_libs` | ^3.1.0+1 | قاعدة بيانات محلية |
| `supabase_flutter` | ^2.12.0 | اتصال Supabase |

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
| 🔴 عالية | **Receipt Printing** | طابعة حرارية 80mm + توليد PDF للفواتير | ✅ مكتمل |
| 🔴 عالية | **Low Stock Alerts** | حد أدنى للمخزون لكل متغير + لوحة إعادة الطلب | ✅ مكتمل |
| 🟡 متوسطة | **Analytics Dashboard** | اتجاهات المبيعات، أفضل المنتجات، تحليل الهامش | ✅ مكتمل |
| 🟡 متوسطة | **Mobile Audit Tool** | استكمال شاشات تدقيق المستودع Android/iOS | ✅ مكتمل |
| 🟢 مستقبل | **Multi-branch Reporting** | تقارير مالية موحدة عبر الفروع | 🔲 مخطط |
| 🟢 مستقبل | **Employee Performance** | مبيعات لكل كاشير، إنتاجية | ✅ مكتمل |
| 🟢 مستقبل | **RLS Policies** | تفعيل RLS كامل على كل الجداول | 🔲 معلّق |
| 🟢 مستقبل | **CI/CD Pipeline** | GitHub Actions لاختبار وبناء التطبيق | 🔲 معلّق |
| 🟢 مستقبل | **PWA Manifest** | تحسين Web PWA | 🔲 معلّق |
| 🟢 مستقبل | **Unit Tests** | كتابة اختبارات للخدمات والـ RPCs | 🔲 معلّق |

---

## 🔐 الأمان والديون التقنية

### 🔴 مشاكل حرجة
| # | المشكلة | الخطورة | الحل |
|---|---|---|---|
| 1 | بعض Edge Functions بدون JWT (get_minimum_version, api_version) | read-only but open | يمكن تفعيل verify_jwt |
| 2 | 28 FK بدون فهارس | بطء شديد عند نمو البيانات | Migration واحد يضيف 28 فهرساً |
| 3 | 5 جداول RLS مفتوحة | تشديد السياسات | إضافة سياسات RLS |

### 🟡 مشاكل مهمة
| # | المشكلة | الحل |
|---|---|---|
| 4 | بعض RPC بدون `search_path` | إضافة `SET search_path = ''` |
| 5 | سياسات RLS بطيئة | استبدال `auth.uid()` المباشر بـ `(select auth.uid())` |
| 6 | Isar بدون تشفير | `encryptionKey` مرتبط بـ device ID |
| 7 | Supabase Keys في الكود | `--dart-define` |
| 8 | Leaked Password Protection معطّل | تفعيله من Supabase Dashboard |
| 9 | Storage Buckets بحاجة تقييد | سياسات قراءة صارمة |

### 🟢 تحسينات للاحترافية
| # | المشكلة |
|---|---|
| 10 | لا توجد Unit Tests كافية |
| 11 | لا يوجد Error Handler موحد |
| 12 | مجلدا `controllers/` و `features/` فارغان |
| 13 | بعض الحزم تحتاج تحديثاً تدريجياً |

---

## ⚠️ قواعد حرجة يجب حفظها

1. **لا تُعدّل `inventory` يدوياً أبداً داخل أي RPC**.
2. **`process_sale` نسخة واحدة فقط** (v3) بدون `p_shift_id`.
3. **`expenses` منفصل عن `transactions` عمداً**.
4. **`payment_type` في `payments`** يميز بين `invoice` و `debt_recovery`.
5. **Flutter = UI فقط، لا حسابات مالية**.
6. **SyncOperationType** يجب تحديثه مع أي عملية offline جديدة.
7. **Isar writeTxn = entity + SyncQueueItem معاً في معاملة ذرية**.
8. **لا تمرر `shift_id` لأي RPC** — نظام الوردية مُزال بالكامل.
9. **جميع العمليات المالية في Supabase RPCs حصراً**.

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
| **إجمالي ملفات Dart** | ~75 ملف (بدون `.g.dart`) |
| **ملفات مولّدة `.g.dart`** | 15 ملف |
| **أكبر ملف** | `owner_dashboard.dart` |
| **ملف الترجمة** | `app_strings.dart` (~280+ مفتاح) |
| **Isar Collections** | 15 |
| **Supabase Tables** | 21 |
| **Supabase RPCs** | 33+ |
| **Edge Functions** | 6 |
| **Migrations** | 9+ |
| **Commit Count (هذه الجلسة)** | 61 |

---

## 🔖 سجل الإصدارات

| الإصدار | الوصف | التاريخ | الحالة |
|---|---|---|---|
| **v1** | النظام الأساسي | مارس 2026 | ✅ إنتاج |
| **v2** | المرتجعات | أبريل 2026 | ✅ مكتمل |
| **v3** | Hybrid Offline/Online | 18 أبريل 2026 | ✅ مكتمل |
| **v4** | المصاريف + تحصيل الديون + التعريب | 26 أبريل 2026 | ✅ مكتمل |
| **v5** | إزالة نظام الوردية + 50+ ميزة جديدة | 10-29 مايو 2026 | ✅ مكتمل |

---

## هيكل الملفات الكامل

```text
Shoes_Stock/
├── lib/
│   ├── main.dart                          — نقطة الدخول
│   ├── check_schema.dart                  — فحص schema
│   ├── core/
│   │   ├── app_session.dart               — الجلسة + locale ValueNotifier
│   │   ├── app_strings.dart               — ~280+ مفتاح AR/FR
│   │   ├── app_colors.dart                — ألوان التطبيق
│   │   ├── api_version_service.dart       — التحقق من إصدار API
│   │   ├── connectivity_service.dart      — مراقبة الاتصال
│   │   ├── preferences_service.dart       — غلاف shared_preferences
│   │   └── sync_engine.dart               — محرك المزامنة
│   ├── local_db/
│   │   ├── enums/local_enums.dart         — PaymentMethod, PaymentType, SyncOperationType
│   │   ├── isar_service.dart              — خدمة Isar
│   │   ├── seed_service.dart              — تحميل الجداول الأساسية
│   │   └── collections/
│   │       ├── store_local.dart
│   │       ├── user_profile_local.dart
│   │       ├── customer_local.dart
│   │       ├── supplier_local.dart
│   │       ├── product_local.dart
│   │       ├── product_variant_local.dart
│   │       ├── inventory_local.dart
│   │       ├── invoice_local.dart
│   │       ├── payment_local.dart
│   │       ├── transaction_local.dart
│   │       ├── expense_category_local.dart
│   │       ├── expense_local.dart
│   │       ├── settings_local.dart
│   │       ├── sync_queue_item.dart
│   │       └── sync_metadata.dart
│   ├── services/
│   │   ├── invoice_service.dart           — Offline-aware
│   │   ├── refund_service.dart            — Offline-aware
│   │   ├── expense_service.dart           — Offline-aware
│   │   ├── debt_recovery_service.dart     — Offline-aware
│   │   ├── purchase_service.dart          — Offline-aware
│   │   ├── backup_service.dart            — نسخ احتياطي
│   │   ├── report_service.dart            — توليد PDF
│   │   ├── receipt_service.dart           — إيصال طباعة
│   │   └── inactivity_timer.dart          — مؤقت انتهاء الجلسة
│   ├── shared/
│   │   ├── constants/shoe_constants.dart  — ألوان ومقاسات
│   │   ├── models/cart_item.dart          — صنف السلة
│   │   ├── utils/contact_utils.dart       — أدوات الاتصال
│   │   └── widgets/
│   │       ├── confirm_dialog.dart        — تأكيد موحد
│   │       └── filter_bottom_sheet.dart   — فلتر متقدم
│   ├── widgets/
│   │   └── offline_banner.dart            — شريط عدم الاتصال
│   └── views/
│       ├── auth/
│       │   ├── login_screen.dart
│       │   └── pin_lock_screen.dart
│       ├── desktop/
│       │   ├── admin_main_layout.dart
│       │   ├── employee_main_layout.dart
│       │   ├── pos_screen.dart
│       │   └── refund_modal.dart
│       ├── admin/
│       │   ├── dashboard_screen.dart
│       │   ├── ajouter_produit.dart
│       │   ├── expenses_screen.dart
│       │   ├── debt_recovery_screen.dart
│       │   ├── gestion_employes.dart
│       │   ├── gestion_clients.dart
│       │   ├── gestion_fournisseurs.dart
│       │   ├── gestion_stores.dart
│       │   ├── liste_produits.dart
│       │   ├── inventory_screen.dart
│       │   ├── achat_fournisseur.dart
│       │   ├── sales_history_screen.dart
│       │   ├── activity_logs_screen.dart
│       │   ├── health_screen.dart
│       │   ├── stock_count_screen.dart
│       │   ├── stock_transfer_screen.dart
│       │   ├── purchase_orders_screen.dart
│       │   ├── promotions_screen.dart
│       │   └── employee_dashboard_screen.dart
│       └── mobile/
│           ├── owner_dashboard.dart
│           ├── employee_dashboard.dart
│           ├── pos_screen.dart
│           ├── products_screen.dart
│           ├── add_product_screen.dart
│           ├── customers_screen.dart
│           ├── suppliers_screen.dart
│           ├── stores_screen.dart
│           ├── employees_screen.dart
│           ├── sales_screen.dart
│           ├── purchases_screen.dart
│           ├── expenses_screen.dart
│           ├── debt_recovery_screen.dart
│           ├── purchase_orders_screen.dart
│           ├── activity_logs_screen.dart
│           └── owner/
│               ├── analytics_sheet.dart
│               ├── debtors_section.dart
│               ├── inventory_section.dart
│               ├── kpi_cards_section.dart
│               ├── slow_moving_section.dart
│               └── store_comparison_section.dart
├── supabase/migrations/
├── assets/images/
├── test/
├── .fvmrc
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## الملاحظة الختامية

- هذا README يعكس **ما تم تنفيذه فعلياً** — 65 مهمة مكتملة، 61 commit.
- تم حذف كل الإشارات لنظام الوردية من الخلاصة والهيكل والـ RPCs.
- جميع الحسابات المالية في Supabase RPCs حصراً — Flutter للعرض فقط.
- تم تفعيل JWT على Edge Functions والمتبقي read-only functions.
- النظام جاهز للتسليم مع توثيق كامل.
