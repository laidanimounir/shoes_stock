"""# 👟 ShoeStock ERP & POS — Full-Scale Retail Ecosystem
### An Engineering Approach to Footwear Industrial Management
### Ein Ingenieursansatz für das Management von Schuheinzelhandel und -fertigung

---

## 🌐 Executive Project Summary / Projektzusammenfassung

**🇬🇧 English:**
ShoeStock ERP is not merely a software application; it is a meticulously engineered business solution developed to digitize and optimize the operational lifecycle of professional footwear retail and manufacturing units. This project is the result of intensive Field Engineering. The developer conducted multiple on-site visits to a real-world shoe manufacturing workshop, performing deep-dive interviews with floor workers, cashiers, and managers to translate manual, complex workflows into a high-performance digital architecture. The system is designed for a formal handover process, including a dedicated training day for the workforce to ensure seamless adoption.

**🇩🇪 Deutsch:**
ShoeStock ERP ist nicht nur eine Softwareanwendung; es ist eine sorgfältig konzipierte Geschäftslösung, die entwickelt wurde, um den operativen Lebenszyklus professioneller Schuheinzelhandels- und Fertigungseinheiten zu digitalisieren und zu optimieren. Dieses Projekt ist das Ergebnis intensiven Field Engineerings. Der Entwickler führte mehrere Vor-Ort-Besuche in einer realen Schuhherstellungswerkstatt durch und führte tiefgehende Interviews mit Mitarbeitern, Kassierern und Managern, um manuelle, komplexe Arbeitsabläufe in eine leistungsstarke digitale Architektur zu übersetzen. Das System ist für einen formalen Übergabeprozess konzipiert, einschließlich eines speziellen Schulungstages für die Belegschaft, um eine reibungslose Einführung zu gewährleisten.

---

## 🏗️ Hybrid Architecture & Logic / Hybride Architektur und Logik

**🇬🇧 English:**
The system operates on a dual-platform logic, ensuring that the right tools are available for the right tasks:

- **The Desktop Command Center (Windows POS):** Built for high-volume retail environments. It features a unique Global Hardware Hook, allowing USB Laser Scanners to input data via HardwareKeyboard events. This logic ensures that products are added to the cart instantly from any screen state, eliminating the need for manual mouse focus on input fields.

- **The Mobile Audit Tool (Android/iOS):** Designed for mobility within the warehouse. It utilizes the `mobile_scanner` API to turn the device camera into a professional inventory tool, allowing the owner to perform stock audits, verify variants, and check margins while on the move.

- **Synchronous Cloud Core:** Powered by Supabase, utilizing PL/pgSQL Remote Procedure Calls (RPCs) to handle complex financial transactions (invoicing and stock deduction) natively on the server to prevent data drift.

> **Core Architecture Rule:** All financial calculations and business logic live exclusively in Supabase RPCs. Flutter is UI/display only. This ensures data integrity regardless of client-side state.

**🇩🇪 Deutsch:**
Das System arbeitet auf einer Dual-Plattform-Logik, die sicherstellt, dass die richtigen Werkzeuge für die richtigen Aufgaben verfügbar sind:

- **Das Desktop-Kommandozentrum (Windows POS):** Entwickelt für Einzelhandelsumgebungen mit hohem Volumen. Es verfügt über einen einzigartigen Global Hardware Hook, der es USB-Laserscannern ermöglicht, Daten über HardwareKeyboard-Events einzugeben. Diese Logik stellt sicher, dass Produkte aus jedem Bildschirmzustand sofort in den Warenkorb gelegt werden.

- **Das mobile Audit-Tool (Android/iOS):** Konzipiert für die Mobilität innerhalb des Lagers. Es nutzt die `mobile_scanner`-API, um die Gerätekamera in ein professionelles Inventarwerkzeug zu verwandeln.

- **Synchroner Cloud-Kern:** Basierend auf Supabase, nutzt PL/pgSQL Remote Procedure Calls (RPCs), um komplexe Finanztransaktionen nativ auf dem Server zu verarbeiten, um Datenabweichungen zu vermeiden.

---

## 🔐 Privilege Matrix & Security / Berechtigungsmatrix und Sicherheit

**🇬🇧 English:**
Security is enforced through a strict **Zero-Trust model** between the UI and the Backend:

| Role | Access Level | Capabilities |
|---|---|---|
| **Owner / Administrator** | Full vertical access | Global financial reporting, employee performance tracking, multi-store branch management, critical mutations (delete records, modify historical pricing) |
| **Employee / Cashier** | Horizontal restricted | Data filtered by assigned `store_id`, administrative menus proactively hidden |

**Database-Level Enforcement (RLS):** Beyond UI hiding, Supabase Row-Level Security denies any unauthorized transaction at the packet level. If a restricted user attempts an unauthorized call, the frontend elegantly catches the `42501` exception, displaying a context-aware bilingual "Access Denied" notification instead of a system crash.

**🇩🇪 Deutsch:**
Die Sicherheit wird durch ein strenges Zero-Trust-Modell zwischen der Benutzeroberfläche und dem Backend erzwungen:

- **Eigentümer-/Administratorrolle:** Voller vertikaler Zugriff — globales Finanzreporting, Leistungsverfolgung der Mitarbeiter, Verwaltung von Filialen, exklusives Recht auf kritische Mutationen.
- **Mitarbeiter-/Kassiererrolle:** Horizontal eingeschränkte Benutzeroberfläche — alle Daten gefiltert nach `store_id`, administrative Menüs proaktiv ausgeblendet.
- **RLS-Erzwingung auf Datenbankebene:** Verweigert jede unbefugte Transaktion auf Paketebene. `42501`-Exception wird elegant abgefangen.

---

## 🗄️ Database Schema / Datenbankschema

### Tables / Tabellen

| Table | Description | Version |
|---|---|---|
| `stores` | Multi-branch store records | v1 |
| `user_profiles` | Owner and employee profiles with roles | v1 |
| `customers` | Customer registry with balance tracking | v1 |
| `suppliers` | Supplier registry with balance tracking | v1 |
| `products` | Product catalog | v1 |
| `product_variants` | Size/color variants with barcodes | v1 |
| `inventory` | Stock levels per variant per store | v1 |
| `invoices` | Sales invoices with status tracking | v1 |
| `payments` | Payment records linked to invoices | v1 |
| `transactions` | Financial transaction ledger (sale/purchase/return) | v1 |
| `activity_logs` | Full audit trail of all system events | v1 |
| `shifts` | Cash register shift tracking per cashier | **v2** ✅ |

### Active RPC Functions / Aktive RPC-Funktionen

| Function | Description | Version |
|---|---|---|
| `process_sale` | Atomic: invoice creation + stock deduction + shift linking | v1 → updated v2 |
| `process_purchase` | Purchase order processing + inventory update | v1 |
| `get_current_user_profile` | Authenticated user profile fetch | v1 |
| `update_balance_from_invoice` | Customer balance reconciliation | v1 |
| `update_balance_from_payment` | Payment balance reconciliation | v1 |
| `handle_inventory_transaction` | Inventory movement handler | v1 |
| `handle_new_user` | Auth trigger — new user profile setup | v1 |
| `open_shift` | Open a cash register shift with initial amount | **v2** ✅ |
| `close_shift` | Close shift + calculate cash discrepancy | **v2** ✅ |
| `get_active_shift` | Fetch currently open shift for a store | **v2** ✅ |
| `process_refund` | Atomic: invoice reversal + stock restock + ledger entry | **v2** ✅ |

---

## ✅ Implemented Modules / Implementierte Module

### v1 — Core System (Production)

- [x] Multi-role Authentication (Owner / Employee)
- [x] Multi-store branch management
- [x] Product & variant catalog with barcode support
- [x] Real-time inventory management
- [x] Supplier & customer management with balance tracking
- [x] Purchase order processing
- [x] **Point of Sale (Windows)** — USB Laser Scanner via Global Hardware Hook
- [x] Invoice generation & payment processing
- [x] Full activity audit logs
- [x] Admin dashboard — sales overview, employee management

---

### v2 — Sprint: Shift & Refund Systems *(Completed April 2026)*

#### 💰 Shift & Cash Management / Schicht- und Kassenmanagement

**🇬🇧 English:**
A non-blocking optional shift system that gives the cashier full control at the start and end of each working day.

- **`shift_dialog.dart`** — Bilingual (FR/AR) modal dialog appearing on POS open. Cashier chooses:
  - *"Ouvrir la caisse / فتح الوردية"* → enters initial cash amount → shift recorded in DB
  - *"Sans caisse / بدون وردية"* → enters POS immediately, shift recorded with 0 DA
  - POS is **never blocked** — dialog is informational and optional
- **`end_of_day_report.dart`** — Daily summary report accessible from AppBar/sidebar:
  - **Case A (shift exists):** Shows opening amount + total sales + expected cash + inline shift closing with live discrepancy (green = surplus / red = shortage)
  - **Case B (no shift):** Shows *"Journée sans caisse ouverte / يوم بدون وردية"* with total sales registered that day
- **`close_shift_screen.dart`** — Inline closing form with real-time discrepancy calculation
- Every invoice and payment is automatically linked to `shift_id`
- `AppSession.currentShiftId` — global session variable tracking active shift

**🇩🇪 Deutsch:**
Ein nicht-blockierendes, optionales Schichtsystem, das dem Kassierer vollständige Kontrolle zu Beginn und Ende jedes Arbeitstages gibt.

- **`shift_dialog.dart`** — Zweisprachiger (FR/AR) Modal-Dialog beim POS-Öffnen
- **`end_of_day_report.dart`** — Täglicher Zusammenfassungsbericht mit zwei Fällen: mit/ohne Schicht
- Jede Rechnung und Zahlung wird automatisch mit `shift_id` verknüpft

---

#### 🔄 Refund & Return Ecosystem / Rückerstattungs- und Rückgabe-Ökosystem

**🇬🇧 English:**
A fully atomic refund system ensuring inventory and financial ledgers are always in sync.

- **`refund_modal.dart`** — Item-level return dialog accessible from sales history:
  - Checkbox per invoice item with quantity selector (max = original quantity)
  - Auto-calculates total refund amount from selected items
  - Optional reason field
  - Calls `process_refund` RPC on confirmation
- **`process_refund` RPC** — Fully atomic Supabase function:
  1. Sets invoice status to `refunded`
  2. Inserts negative transaction entry in financial ledger
  3. Restocks inventory for each returned variant
  4. All steps within a single transaction — any failure = full rollback
- Refund button visible on every `paid` invoice in sales history screen

**🇩🇪 Deutsch:**
Ein vollständig atomares Rückerstattungssystem, das sicherstellt, dass Inventar und Finanzbücher immer synchronisiert sind.

- **`refund_modal.dart`** — Rückgabedialog auf Artikelebene mit Checkbox und Mengenwähler
- **`process_refund` RPC** — Vollständig atomare Supabase-Funktion: Rechnungsstornierung + Lagerauffüllung + Buchhaltungseintrag

---

## 🗺️ Roadmap — Pending Modules / Ausstehende Module

**🇬🇧 English:**
The system currently adheres to French-language commercial standards used in the Algerian trade sector. The following modules are identified as strategic expansions:

| Priority | Module | Description |
|---|---|---|
| 🔴 High | **Offline-First POS** | Local NoSQL caching layer (Isar/Hive) for continuous selling during ISP outages, with background sync on reconnect |
| 🔴 High | **Expense & Debt Recovery** | Independent module for tracking operational costs (utilities, logistics) + dedicated debt repayment dashboard |
| 🟡 Medium | **Multilingual UI (Arabic)** | Full RTL Arabic interface across Desktop and Mobile platforms for the local workforce |
| 🟡 Medium | **Mobile Audit Tool** | Complete Android/iOS warehouse audit screens with camera barcode scanning |
| 🟢 Future | **Multi-branch Reporting** | Cross-store financial consolidation dashboard for the owner |
| 🟢 Future | **Employee Performance Tracking** | Sales per cashier, shift productivity analytics |

**🇩🇪 Deutsch:**
Das System entspricht derzeit den französischsprachigen Handelsstandards des algerischen Handelssektors. Folgende Module sind als strategische Erweiterungen identifiziert:

| Priorität | Modul | Beschreibung |
|---|---|---|
| 🔴 Hoch | **Offline-First POS** | Lokale NoSQL-Caching-Ebene (Isar/Hive) für Verkäufe bei ISP-Ausfällen, mit Hintergrundsynchronisation |
| 🔴 Hoch | **Ausgaben- und Schuldeneintreibung** | Unabhängige Module zur Verfolgung der Betriebskosten und ein Dashboard für Schuldenrückzahlungen |
| 🟡 Mittel | **Multilinguale Integration (Arabisch)** | Vollständige RTL-Arabische Benutzeroberfläche auf beiden Plattformen |
| 🟡 Mittel | **Mobiles Audit-Tool** | Vollständige Android/iOS-Lagerprüfungsbildschirme |
| 🟢 Zukunft | **Filialübergreifendes Reporting** | Konsolidiertes Finanzdashboard für alle Filialen |
| 🟢 Zukunft | **Mitarbeiterleistungsverfolgung** | Verkäufe pro Kassierer, Schichtproduktivitätsanalysen |

---

## ⚙️ Technical Execution / Technische Ausführung

**🇬🇧 English** — To initialize the environment for production or development:

**🇩🇪 Deutsch** — So initialisieren Sie die Umgebung für Produktion oder Entwicklung:

### Prerequisites / Voraussetzungen
- Flutter SDK `3.19+`
- **Visual Studio 2022 Community** (Release — NOT Insiders) with:
  - ✅ Desktop development with C++
  - ✅ MSVC v143 build tools
  - ✅ Windows 11 SDK
- Supabase project configured with environment variables

### Commands / Befehle

```bash
# Install dependencies / Abhängigkeiten installieren
flutter pub get

# Run POS on Windows / POS auf Windows ausführen
flutter run -d windows

# Production build / Produktionskompilierung
flutter build windows
# Output / Ausgabe: build/windows/x64/runner/Release/
```

### Project Structure / Projektstruktur

```
lib/
├── core/
│   └── app_session.dart              # Global shift session state
├── models/
│   └── shift_model.dart              # ShiftModel + ShiftSummary
├── services/
│   ├── shift_service.dart            # Shift RPC calls
│   └── refund_service.dart           # Refund RPC calls
└── views/
    ├── auth/
    │   └── login_screen.dart
    ├── desktop/
    │   ├── pos_screen.dart           # Main POS (shift-aware)
    │   ├── shift_dialog.dart         # Shift opening modal ✅ v2
    │   ├── close_shift_screen.dart   # Shift closing form ✅ v2
    │   ├── end_of_day_report.dart    # Daily report Case A/B ✅ v2
    │   ├── refund_modal.dart         # Invoice return modal ✅ v2
    │   ├── admin_layout.dart
    │   └── employee_main_layout.dart
    ├── admin/
    │   ├── overview/
    │   ├── products/
    │   ├── employees/
    │   ├── stores/
    │   ├── customers/
    │   ├── suppliers/
    │   └── sales/
    │       └── sales_history_screen.dart  # + refund action ✅ v2
    └── mobile/
        └── owner_dashboard/
```

---

## 👤 Lead Developer

**Lead Systems Architect & Digital Transformation Consultant**
*Leitender Systemarchitekt und Berater für digitale Transformation*

---

*Last updated: April 2026 — v2 Sprint Complete ✅*
*Next milestone: Offline-First POS + Expense Management*