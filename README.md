# 👟 ShoeStock ERP & POS — Full-Scale Retail Ecosystem
### An Engineering Approach to Footwear Industrial Management
### Ein Ingenieursansatz für das Management von Schuheinzelhandel und -fertigung

***

## 🌐 Executive Project Summary / Projektzusammenfassung

**🇬🇧 English:**
ShoeStock ERP is not merely a software application; it is a meticulously engineered business solution developed to digitize and optimize the operational lifecycle of professional footwear retail and manufacturing units. This project is the result of intensive Field Engineering. The developer conducted multiple on-site visits to a real-world shoe manufacturing workshop, performing deep-dive interviews with floor workers, cashiers, and managers to translate manual, complex workflows into a high-performance digital architecture. The system is designed for a formal handover process, including a dedicated training day for the workforce to ensure seamless adoption.

**🇩🇪 Deutsch:**
ShoeStock ERP ist nicht nur eine Softwareanwendung; es ist eine sorgfältig konzipierte Geschäftslösung, die entwickelt wurde, um den operativen Lebenszyklus professioneller Schuheinzelhandels- und Fertigungseinheiten zu digitalisieren und zu optimieren. Dieses Projekt ist das Ergebnis intensiven Field Engineerings. Der Entwickler führte mehrere Vor-Ort-Besuche in einer realen Schuhherstellungswerkstatt durch und führte tiefgehende Interviews mit Mitarbeitern, Kassierern und Managern durch. Das System ist für einen formalen Übergabeprozess konzipiert, einschließlich eines speziellen Schulungstages für die Belegschaft.

***

## 🏗️ Hybrid Architecture & Logic / Hybride Architektur und Logik

**🇬🇧 English:**
The system operates on a dual-platform logic, ensuring that the right tools are available for the right tasks:

- **The Desktop Command Center (Windows POS):** Built for high-volume retail environments. Features a unique Global Hardware Hook allowing USB Laser Scanners to input data via HardwareKeyboard events — products added to cart instantly from any screen state.
- **The Mobile Audit Tool (Android/iOS):** Uses the `mobile_scanner` API to turn the device camera into a professional inventory tool for warehouse audits, variant verification, and margin checks on the move.
- **Synchronous Cloud Core:** Powered by Supabase with PL/pgSQL RPCs handling all complex financial transactions natively on the server to prevent data drift.
- **Hybrid Offline/Online Layer (v3 ✅):** Isar local database with queue-based synchronization allowing continuous operation during internet outages. Auto-detects connectivity loss, persists all sales locally, and replays to Supabase on reconnect.

> **Core Architecture Rule:** ALL financial calculations and business logic live exclusively in Supabase RPCs. Flutter is UI/display only. This ensures data integrity regardless of client-side state.

**🇩🇪 Deutsch:**
Das System arbeitet auf einer Dual-Plattform-Logik:

- **Desktop-Kommandozentrum (Windows POS):** Global Hardware Hook für USB-Laserscanner via HardwareKeyboard-Events.
- **Mobiles Audit-Tool (Android/iOS):** `mobile_scanner`-API für Lagerprüfungen.
- **Synchroner Cloud-Kern:** Supabase PL/pgSQL RPCs für alle Finanztransaktionen.
- **Hybrid Offline/Online-Schicht (v3 ✅):** Isar lokale Datenbank mit warteschlangenbasierter Synchronisation — Verkäufe werden lokal gespeichert und bei Wiederverbindung automatisch mit Supabase synchronisiert.

***

## 🔐 Privilege Matrix & Security / Berechtigungsmatrix und Sicherheit

**🇬🇧 English:**

| Role | Access Level | Capabilities |
|---|---|---|
| **Owner / Administrator** | Full vertical | Global reports, all stores, employee management, critical mutations |
| **Employee / Cashier** | Horizontal restricted | Data filtered by `store_id`, admin menus hidden |

- **RLS:** Supabase Row-Level Security denies unauthorized transactions at packet level
- **Exception Handling:** `42501` caught elegantly — bilingual "Access Denied" instead of crash

**🇩🇪 Deutsch:**
- **Eigentümerrolle:** Voller vertikaler Zugriff
- **Mitarbeiterrolle:** Horizontal eingeschränkt, gefiltert nach `store_id`
- **RLS:** Verweigert unbefugte Transaktionen, `42501` elegant abgefangen

***

## 🗄️ Database Schema / Datenbankschema

### Tables / Tabellen

| Table | Description | Version |
|---|---|---|
| `stores` | Multi-branch store records | v1 |
| `user_profiles` | Owner + employee profiles with roles (`user_role` enum) | v1 |
| `customers` | Customer registry + balance tracking | v1 |
| `suppliers` | Supplier registry + balance tracking | v1 |
| `products` | Product catalog | v1 |
| `product_variants` | Size/color/barcode variants | v1 |
| `inventory` | Stock levels per variant per store | v1 |
| `invoices` | Sales invoices (paid/partial/unpaid/refunded/returned/cancelled) | v1 |
| `payments` | Payment records + `payment_type` enum (invoice / debt_recovery) | v1 → **v4** ✅ |
| `transactions` | Financial ledger (`transaction_type` enum: in/out/return) | v1 |
| `activity_logs` | Full audit trail | v1 |
| `shifts` | Cash register shift tracking per cashier | **v2** ✅ |
| `expense_categories` | Operational expense categories per store | **v4** ✅ |
| `expenses` | Operational expenses (rent, utilities, salaries…) with RLS | **v4** ✅ |
| `settings` | User preferences — locale persistence (AR/FR) | **v4** ✅ |

### Active RPC Functions / Aktive RPC-Funktionen

| Function | Description | Version |
|---|---|---|
| `process_sale` | Atomic: invoice + stock deduction + shift linking | v1 → v2 → **v3 fixed** ✅ |
| `process_purchase` | Purchase order + inventory update | v1 |
| `get_current_user_profile` | Auth user profile fetch | v1 |
| `update_balance_from_invoice` | Customer balance reconciliation (trigger) | v1 |
| `update_balance_from_payment` | Payment balance reconciliation (trigger) | v1 |
| `handle_inventory_transaction` | Trigger-based inventory movement | v1 |
| `handle_new_user` | Auth trigger — new user setup | v1 |
| `open_shift` | Open cash register shift | **v2** ✅ |
| `close_shift` | Close shift + discrepancy calculation | **v2** ✅ |
| `get_active_shift` | Fetch current open shift (today only) | **v2** ✅ |
| `process_refund` | Atomic: reversal + restock + ledger + explicit user_id | **v2 → v3 fixed** ✅ |
| `add_expense` | Atomic: insert operational expense record | **v4** ✅ |
| `add_debt_recovery_payment` | Payment without invoice — reduces customer balance | **v4** ✅ |

### ⚠️ Critical Notes / Kritische Hinweise

**🇬🇧 English:**
- `handle_inventory_transaction` fires on every INSERT/UPDATE/DELETE on `transactions` — **never manually UPDATE inventory in any RPC**
- `process_sale` exists as a single overload only (v1 without `p_shift_id` was dropped in v3)
- `process_refund` explicitly sets `user_id = auth.uid()` with authentication guard
- `expenses` table is intentionally separate from `transactions` — mixing operational costs into the inventory ledger would corrupt stock audit trails
- `payment_type` on `payments` distinguishes invoice settlements from open-account debt recovery

**🇩🇪 Deutsch:**
- `handle_inventory_transaction` wird bei jedem INSERT/UPDATE/DELETE in `transactions` ausgelöst — **niemals manuell inventory in einem RPC aktualisieren**
- `process_sale` existiert nur als einzelne Überladung (v1 ohne `p_shift_id` wurde in v3 gelöscht)
- `expenses` ist bewusst von `transactions` getrennt — Betriebskosten dürfen das Inventar-Ledger nicht beeinflussen

***

## ✅ Implemented Modules / Implementierte Module

### v1 — Core System (Production)
- [x] Multi-role Authentication (Owner / Employee)
- [x] Multi-store branch management
- [x] Product & variant catalog with barcode support
- [x] Real-time inventory management
- [x] Supplier & customer management with balance tracking
- [x] Purchase order processing
- [x] **POS Windows** — USB Laser Scanner via Global Hardware Hook
- [x] Invoice generation + payment processing
- [x] Full activity audit logs
- [x] Admin dashboard

***

### v2 — Shift, Cash & Refund Systems *(Completed April 2026)*

#### 💰 Shift & Cash Management / Schicht- und Kassenmanagement

**🇬🇧 English:**
- **`shift_dialog.dart`** — Bilingual FR/AR modal on POS open (non-blocking, optional)
- **`end_of_day_report.dart`** — Case A: shift with sales summary + discrepancy / Case B: no shift
- **`close_shift_screen.dart`** — Inline closing with live discrepancy (green surplus / red shortage)
- Shift expiry — `getActiveShift()` returns null for previous day shifts
- Warning dialog for unclosed shifts from previous day
- Every invoice + payment linked to `shift_id`
- `AppSession.currentShiftId` — global session variable

**🇩🇪 Deutsch:**
- Nicht-blockierendes optionales Schichtsystem mit zweisprachigem Dialog
- Tagesendbericht mit zwei Fällen: mit/ohne Schicht
- Jede Rechnung und Zahlung automatisch mit `shift_id` verknüpft

#### 🔄 Refund & Return Ecosystem / Rückerstattungs-Ökosystem

**🇬🇧 English:**
- **`refund_modal.dart`** — Item-level return with quantity selector + reason field
- **`process_refund` RPC** — Atomic: invoice → `refunded` + stock restock via trigger + ledger entry
- Visual badges: 🟢 **"Payé ✓"** — paid / 🔴 **"Remboursé ↩"** — refunded + strike-through amount

**🇩🇪 Deutsch:**
- Vollständig atomares Rückerstattungssystem: Rechnungsstornierung + Lagerauffüllung + Buchhaltungseintrag

***

### v3 — Hybrid Offline/Online System *(Completed April 18, 2026)* ✅

#### 📦 Local Database Layer / Lokale Datenbankschicht

**🇬🇧 English:**

| Collection | Mirrors | Synced Flag |
|---|---|---|
| `StoreLocal` | `stores` | — |
| `UserProfileLocal` | `user_profiles` | — |
| `CustomerLocal` | `customers` + `address` field | — |
| `SupplierLocal` | `suppliers` | — |
| `ProductLocal` | `products` | — |
| `ProductVariantLocal` | `product_variants` + `@Index(barcode)` | — |
| `InventoryLocal` | `inventory` + composite index | — |
| `InvoiceLocal` | `invoices` | ✅ |
| `PaymentLocal` | `payments` + `paymentType` field | ✅ |
| `TransactionLocal` | `transactions` | ✅ |
| `ShiftLocal` | `shifts` | ✅ |
| `SyncQueueItem` | Queue — operationType, payloadJson, retryCount | — |
| `SyncMetadata` | Singleton — lastSyncAt, mode, pendingCount | — |

**🇩🇪 Deutsch:**
13 Isar-Collections spiegeln die Supabase-Tabellen für den Offline-Betrieb wider. Collections mit `synced`-Flag werden bei Wiederverbindung automatisch synchronisiert.

#### ⚙️ Core Services / Kerndienste

**🇬🇧 English:**
- **`ConnectivityService`** — Singleton monitoring network state. Auto-triggers `SyncEngine.syncPending()` on reconnect
- **`SeedService`** — Downloads 13 tables from Supabase into Isar on first offline login (FK-safe order, 30-day window for transactional data)
- **`SyncEngine`** — Replays `SyncQueueItem` queue against Supabase RPCs. Retry logic: max 3 attempts per item, then marks `failed`
- **`InvoiceService`** — Offline-aware service: if online → Supabase RPC directly / if offline → Isar + SyncQueue enqueue

**🇩🇪 Deutsch:**
- **`ConnectivityService`** — Netzwerküberwachung, automatische Synchronisierungsauslösung bei Wiederverbindung
- **`SeedService`** — Lädt 13 Tabellen beim ersten Offline-Login in FK-sicherer Reihenfolge
- **`SyncEngine`** — Wiederholt ausstehende Operationen mit max. 3 Versuchen
- **`InvoiceService`** — Offline-bewusster Dienst mit automatischer Weiterleitung

#### 🖥️ UI Integration / UI-Integration

**🇬🇧 English:**
- **Mode Selection Dialog** — After login: choose "Online" or "Offline"
- **OfflineBanner** — Persistent top banner showing connection status + pending sync count + manual sync button
- **POS Screen** — Refactored to use `InvoiceService` — sells offline seamlessly
- **AppSession** — Extended with `isOfflineMode`, `pendingSync`, `currentUserId`

**🇩🇪 Deutsch:**
- **Modusauswahldialog** — Nach dem Login: Online oder Offline wählen
- **OfflineBanner** — Dauerhaftes Banner mit Verbindungsstatus und ausstehenden Synchronisierungen
- **POS-Bildschirm** — Umstrukturiert für nahtlosen Offline-Verkauf

***

### v4 — Expense Management, Debt Recovery & Bilingual UI *(In Progress — April 19, 2026)*

#### 💸 Expense & Debt Recovery Module ✅

**🇬🇧 English:**
- **`expense_categories` table** — Store-scoped operational expense categories with RLS
- **`expenses` table** — Full expense tracking (amount, category, payment method, date) with RLS
- **`add_expense` RPC** — Atomic server-side expense insertion
- **`add_debt_recovery_payment` RPC** — Account-level payment that reduces customer balance without invoice reference
- **`ExpenseService`** — Offline-aware: online → RPC / offline → Isar + SyncQueue (`createExpense`)
- **`DebtRecoveryService`** — Offline-aware: online → RPC / offline → Isar + SyncQueue (`createDebtRecoveryPayment`)
- **`ExpensesScreen`** — Monthly stats (total, count, max) + category filter chips + add/category dialogs
- **`DebtRecoveryScreen`** — Master-detail: customer list sorted by debt + payment history tabs + inline payment dialog with balance preview
- **`SyncOperationType`** — Extended with `createExpense` + `createDebtRecoveryPayment`
- **Admin nav** — Registered at indices 11 (`Dépenses`) and 12 (`Recouvrement`)

**🇩🇪 Deutsch:**
- Vollständiges Ausgaben- und Schuldenrückzahlungsmodul mit Offline-Unterstützung
- Atomare RPCs für Serverintegrität
- Master-Detail-UI für Kundenschulden mit Echtzeit-Saldovorschau

#### 🌍 Arabic / French Bilingual UI *(In Progress)*

**🇬🇧 English:**

| Phase | Scope | Status |
|---|---|---|
| **Phase A** — Infrastructure | `app_strings.dart` (~280 keys AR/FR) + `SettingsLocal` Isar + `AppSession.locale` ValueNotifier + `main.dart` rebuild wrapper | ✅ Complete |
| **Phase B** — Core screens | `offline_banner`, `login_screen` (AR/FR toggle), `admin_main_layout` (RTL + BorderDirectional), `employee_main_layout`, `shift_dialog`, `close_shift_screen`, `end_of_day_report`, `activity_logs_screen`, `sales_history_screen` | ✅ Complete |
| **Phase C1** — Admin screens | `refund_modal`, `dashboard_screen` (dynamic Arabic dates), `ajouter_produit` | ✅ Complete |
| **Phase C2** — Admin screens | `debt_recovery_screen`, `expenses_screen`, `gestion_employes` | ⚠️ Build errors under fix |
| **Phase C3** — Admin screens | `gestion_stores`, `achat_fournisseur`, `inventory_screen`, `liste_produits`, `gestion_fournisseurs`, `gestion_clients`, `pos_screen` | 🔲 Pending |
| **Phase C4** — Mobile | `owner_dashboard` (~215 strings) | 🔲 Pending |

**Architecture:**
- `AppSession.locale` — `ValueNotifier<String>` wrapping `MaterialApp` for full widget tree rebuild on language switch
- `S.t('key')` — Static accessor usable anywhere without `BuildContext`
- `SettingsLocal` — Isar singleton (id=1) persisting locale across restarts
- Default language: **Arabic** — app launches in AR on first install
- RTL layout: Flutter handles 90% automatically via `Locale('ar')`. Manual fixes applied to `EdgeInsetsDirectional`, `BorderDirectional`, and direction-sensitive icons
- Fonts: `GoogleFonts.cairo()` (body) + `GoogleFonts.amiri()` (headings) for Arabic — `GoogleFonts.raleway()` + `GoogleFonts.playfairDisplay()` for French

**Known issue being resolved:**
- `app_strings.dart` — syntax error near line 932 (unclosed map entry)
- `login_screen.dart` — unclosed bracket in SnackBar construction
- 3 `const` conflicts in `gestion_employes`, `debt_recovery_screen`, `end_of_day_report`

***

## 🗺️ Roadmap — Pending Modules / Ausstehende Module

**🇬🇧 English:**

| Priority | Module | Description | Status |
|---|---|---|---|
| 🔴 High | **Bilingual UI C2 fix** | Fix 5 build errors blocking Phase C2 | 🔧 In fix |
| 🔴 High | **Bilingual UI C3** | POS + Inventory + Clients + Suppliers + Stores | 🔲 Next |
| 🔴 High | **Bilingual UI C4** | Mobile owner dashboard | 🔲 Next |
| 🔴 High | **Receipt Printing** | Thermal printer (80mm) + PDF invoice generation | 🔲 Pending |
| 🔴 High | **Low Stock Alerts** | Minimum threshold per variant + reorder dashboard | 🔲 Pending |
| 🟡 Medium | **Analytics Dashboard** | Sales trends, top products, margin analysis charts | 🔲 Pending |
| 🟡 Medium | **Mobile Audit Tool** | Complete Android/iOS warehouse audit screens | 🔲 Pending |
| 🟢 Future | **Multi-branch Reporting** | Cross-store financial consolidation | 🔲 Pending |
| 🟢 Future | **Employee Performance** | Sales per cashier, shift productivity | 🔲 Pending |

**🇩🇪 Deutsch:**

| Priorität | Modul | Beschreibung | Status |
|---|---|---|---|
| 🔴 Hoch | **Zweisprachige UI C2-Fix** | 5 Build-Fehler beheben | 🔧 In Bearbeitung |
| 🔴 Hoch | **Zweisprachige UI C3** | POS + Inventar + Kunden + Lieferanten | 🔲 Ausstehend |
| 🔴 Hoch | **Zweisprachige UI C4** | Mobiles Eigentümer-Dashboard | 🔲 Ausstehend |
| 🔴 Hoch | **Belegdruck** | Thermodrucker (80mm) + PDF-Rechnungsgenerierung | 🔲 Ausstehend |
| 🔴 Hoch | **Mindestbestandsalarm** | Schwellenwert pro Variante + Nachbestellübersicht | 🔲 Ausstehend |
| 🟡 Mittel | **Analyse-Dashboard** | Verkaufstrends, Topprodukte, Margenanalyse | 🔲 Ausstehend |
| 🟡 Mittel | **Mobiles Audit-Tool** | Vollständige Android/iOS-Lagerprüfungsbildschirme | 🔲 Ausstehend |
| 🟢 Zukunft | **Filialübergreifendes Reporting** | Konsolidiertes Finanzdashboard | 🔲 Ausstehend |
| 🟢 Zukunft | **Mitarbeiterleistungsverfolgung** | Verkäufe pro Kassierer, Schichtproduktivität | 🔲 Ausstehend |

***

## ⚙️ Technical Execution / Technische Ausführung

### Prerequisites / Voraussetzungen
- Flutter SDK `3.19+`
- **Visual Studio 2022 Community** (Release — NOT Insiders):
  - ✅ Desktop development with C++
  - ✅ MSVC v143 build tools
  - ✅ Windows 11 SDK
- Supabase project configured

### Commands / Befehle
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
flutter build windows
# Output: build/windows/x64/runner/Release/
```

### Key Dependencies / Wichtige Abhängigkeiten

```yaml
dependencies:
  supabase_flutter: latest
  mobile_scanner: latest
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  connectivity_plus: ^6.0.5
  path_provider: ^2.1.2
  google_fonts: latest
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2

dev_dependencies:
  isar_generator: ^3.1.0+1
  build_runner: ^2.4.9
```

### Project Structure / Projektstruktur

├── core/
│ ├── app_session.dart # Global session + locale ValueNotifier (v4)
│ ├── app_strings.dart # ✅ v4 — ~280 AR/FR translation keys
│ ├── connectivity_service.dart # ✅ v3 — internet monitoring + auto-sync trigger
│ └── sync_engine.dart # ✅ v3+v4 — queue sync + expense/debt operations
├── local_db/ # ✅ v3+v4
│ ├── collections/
│ │ ├── store_local.dart
│ │ ├── user_profile_local.dart
│ │ ├── customer_local.dart # + address field (v4 fix)
│ │ ├── supplier_local.dart
│ │ ├── product_local.dart
│ │ ├── product_variant_local.dart
│ │ ├── inventory_local.dart
│ │ ├── invoice_local.dart
│ │ ├── payment_local.dart # + paymentType field (v4)
│ │ ├── transaction_local.dart
│ │ ├── shift_local.dart
│ │ ├── expense_category_local.dart # ✅ v4
│ │ ├── expense_local.dart # ✅ v4 — synced flag
│ │ ├── settings_local.dart # ✅ v4 — locale persistence
│ │ ├── sync_queue_item.dart
│ │ └── sync_metadata.dart
│ ├── enums/
│ │ └── local_enums.dart # + PaymentMethod + PaymentType + createExpense + createDebtRecoveryPayment (v4)
│ ├── isar_service.dart
│ └── seed_service.dart # + expense_categories + expenses seeding (v4)
├── models/
│ └── shift_model.dart
├── services/
│ ├── invoice_service.dart # ✅ v3 — offline-aware sale processing
│ ├── shift_service.dart # ✅ v4 fix — isar.dart import + named notes param
│ ├── refund_service.dart
│ ├── expense_service.dart # ✅ v4 — offline-aware expense management
│ └── debt_recovery_service.dart # ✅ v4 — offline-aware debt recovery
└── views/
├── auth/
│ └── login_screen.dart # ✅ v3+v4 — mode selection + AR/FR toggle
├── desktop/
│ ├── pos_screen.dart # ✅ v3 — uses InvoiceService | 🔲 i18n C3
│ ├── shift_dialog.dart # ✅ v2+v4i18n
│ ├── close_shift_screen.dart # ✅ v2+v4i18n
│ ├── end_of_day_report.dart # ✅ v2+v4i18n
│ └── refund_modal.dart # ✅ v2+v4i18n C1
├── admin/
│ ├── dashboard_screen.dart # ✅ v4i18n C1 — dynamic Arabic dates
│ ├── ajouter_produit.dart # ✅ v4i18n C1
│ ├── expenses_screen.dart # ✅ v4 — ⚠️ i18n C2 build fix pending
│ ├── debt_recovery_screen.dart # ✅ v4 — ⚠️ i18n C2 build fix pending
│ ├── gestion_employes.dart # ⚠️ i18n C2 build fix pending
│ ├── gestion_clients.dart # 🔲 i18n C3
│ ├── gestion_fournisseurs.dart # 🔲 i18n C3
│ ├── gestion_stores.dart # 🔲 i18n C3
│ ├── liste_produits.dart # 🔲 i18n C3
│ ├── inventory_screen.dart # ✅ v4 fix (casting) | 🔲 i18n C3
│ ├── achat_fournisseur.dart # 🔲 i18n C3
│ ├── sales_history_screen.dart # ✅ v4i18n B
│ └── activity_logs_screen.dart # ✅ v4i18n B
├── mobile/
│ └── owner_dashboard/ # 🔲 i18n C4
└── widgets/
└── offline_banner.dart # ✅ v3+v4i18n B


***

## 👤 Lead Developer

**Lead Systems Architect & Digital Transformation Consultant**
*Leitender Systemarchitekt und Berater für digitale Transformation*

***

*Last updated: April 19, 2026*
*v1: Production ✅ | v2: Complete ✅ | v3: Complete ✅ | v4: In Progress 🔧*
*Current session: Fixing i18n Phase C2 build errors → then C3 → C4 → Receipt Printing → Low Stock Alerts*








## 🧪 Technical Debt & Improvement Areas
### المناطق التي تحتاج تحسين

---

### 1️⃣ Testing — الاختبارات التلقائية

**الوضع الحالي:** لا يوجد مجلد `test/` في المشروع

**ما هو Testing؟**
ملفات كود خفية تعمل في الخلفية فقط — ليست واجهة يراها المستخدم.
المطور يكتب `flutter test` في terminal ويرى النتائج تلقائياً:
- ✅ process_sale تنقص المخزون صح
- ✅ refund يرجع المخزون صح
- ❌ process_sale بمخزون صفر — CRASH! ← يعرف المشكلة فوراً

**الحالات التي يجب اختبارها:**

| الحالة | النتيجة المتوقعة |
|---|---|
| بيع طبيعي: 10 أحذية، بعت 3 | يبقى 7 ✅ |
| المخزون ناقص: عندي 2، طلب 5 | رسالة خطأ ✅ |
| بيع بدون إنترنت | يحفظ في Isar + Queue ✅ |
| مرتجع: بعت 3، رجع 1 | المخزون يرجع 8 ✅ |
| كاشير بدون شيفت مفتوح | يمنعه من البيع ✅ |

**الملفات المطلوب إنشاؤها:**
test/
├── invoice_test.dart
├── refund_test.dart
└── sync_test.dart

**الوقت المطلوب:** 3-4 أيام

**أهميته للـ Ausbildung:**
> سيسألونك: *"Wie testest du deinen Code?"*
> - ❌ ضعيف: "Ich starte die App und schaue"
> - ✅ قوي: "Ich schreibe Unit Tests mit flutter_test für jede kritische Funktion"

---

### 2️⃣ Error Handling — معالجة الأخطاء

**الوضع الحالي:** بعض الأخطاء تُطبع في console فقط بـ `print(e)` — الكاشير لا يرى شيئاً

**ما هو Error Handling؟**
بدل ما يتجمد التطبيق أو يغلق فجأة عند حدوث خطأ — تظهر رسالة واضحة للكاشير.

**الأخطاء الممكنة في هذا المشروع:**

| الخطأ | السبب | الرسالة المطلوبة |
|---|---|---|
| `SocketException` | انقطع النت | "تم الحفظ محلياً ✅" |
| `PostgrestException 42501` | ليس لديه صلاحية | "ليس لديك صلاحية لهذه العملية" |
| `insufficient_stock` | مخزون ناقص | "المخزون غير كافٍ لإتمام البيع" |
| `no_active_shift` | ما في شيفت | "يجب فتح شيفت أولاً قبل البيع" |
| `AuthException` | انتهت الجلسة | "انتهت جلستك — يرجى تسجيل الدخول مجدداً" |

**ما ينقص:**
- تعريف `enum SaleError` يجمع كل أنواع الأخطاء
- رسائل واضحة للكاشير بدل تجمد التطبيق
- معالجة خاصة لكل نوع من الأخطاء

**الملف المقترح:** `lib/core/error_handler.dart`
**الوقت المطلوب:** 1-2 يوم

---

### 3️⃣ Code Comments — توثيق الكود

**الوضع الحالي:** الكود يعمل لكن بدون شرح داخلي

**ما هو Code Comments؟**
شرح الكود من الداخل حتى أي مطور آخر يفهمه بسرعة بدون ما يضيع ساعات.

**أنواع Comments في Flutter:**

| النوع | الاستخدام |
|---|---|
| `// تعليق سطر` | شرح سطر معين |
| `/* تعليق متعدد */` | شرح منطق معقد |
| `/// Documentation` | للدوال المهمة — يظهر في IDE تلقائياً |

**الملفات ذات الأولوية:**
- 🔴 `SyncEngine.syncPending()`
- 🔴 `InvoiceService.processSale()`
- 🔴 `KeyManager.getIsarKey()`
- 🟡 باقي الـ services

**الوقت المطلوب:** 1 يوم

> في ألمانيا هذا يسمى **"Clean Code"** — معيار أساسي في كل شركة IT

---

### 4️⃣ Security — الحماية 🔐

**الوضع الحالي:** قاعدة البيانات المحلية Isar مكشوفة بدون تشفير

| الثغرة | الخطورة | الحل |
|---|---|---|
| Isar بدون تشفير | 🔴 عالي | `encryptionKey` مرتبط بـ device ID |
| `payloadJson` واضح في SyncQueue | 🔴 عالي | تشفير AES |
| Supabase keys في الكود | 🔴 عالي | `--dart-define` environment variables |
| APK/EXE قابل للعكس | 🟡 متوسط | `--obfuscate` عند البناء |
| Supabase RLS موجود | 🟢 محمي | ✅ جيد |

> **هذه المهمة أُوكلت لشخص آخر ✅ — قيد التنفيذ**

---

### ⏱️ الوقت التقديري الكامل

| المهمة | الوقت |
|---|---|
| Security كاملة | 8-10 أيام |
| Tests أساسية | 3-4 أيام |
| Error Handling | 1-2 يوم |
| Code Comments | 1 يوم |
| **المجموع** | **~3 أسابيع** |

---

### ✅ Checklist قبل التسليم الرسمي
الأمان:
□ Isar encryptionKey مفعّل ومرتبط بالجهاز
□ SyncQueue payloads مشفّرة AES
□ Supabase keys في --dart-define فقط
□ APK/EXE مبني بـ --obfuscate
□ لا يوجد أي string حساس في الكود
الجودة:
□ Tests أساسية مكتوبة (7-10 tests)
□ Error Handler موحّد في lib/core/
□ Comments على الدوال الرئيسية
□ لا يوجد print(e) في الكود النهائي

---

*هذه النقائص لا تؤثر على عمل النظام الحالي*
*لكنها ضرورية للاحترافية وبيئة العمل الرسمية 🇩🇪*