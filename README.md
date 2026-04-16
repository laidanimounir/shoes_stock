👞 ShoeStock ERP & POS: Full-Scale Retail Ecosystem
An Engineering Approach to Footwear Industrial Management
🌐 Executive Project Summary / Projektzusammenfassung
English:
ShoeStock ERP is not merely a software application; it is a meticulously engineered business solution developed to digitize and optimize the operational lifecycle of professional footwear retail and manufacturing units. This project is the result of intensive Field Engineering. The developer conducted multiple on-site visits to a real-world shoe manufacturing workshop, performing deep-dive interviews with floor workers, cashiers, and managers to translate manual, complex workflows into a high-performance digital architecture. The system is designed for a formal handover process, including a dedicated training day for the workforce to ensure seamless adoption.

Deutsch:
ShoeStock ERP ist nicht nur eine Softwareanwendung; es ist eine sorgfältig konzipierte Geschäftslösung, die entwickelt wurde, um den operativen Lebenszyklus professioneller Schuheinzelhandels- und Fertigungseinheiten zu digitalisieren und zu optimieren. Dieses Projekt ist das Ergebnis intensiven Field Engineerings. Der Entwickler führte mehrere Vor-Ort-Besuche in einer realen Schuhherstellungswerkstatt durch und führte tiefgehende Interviews mit Mitarbeitern, Kassierern und Managern, um manuelle, komplexe Arbeitsabläufe in eine leistungsstarke digitale Architektur zu übersetzen. Das System ist für einen formalen Übergabeprozess konzipiert, einschließlich eines speziellen Schulungstages für die Belegschaft, um eine reibungslose Einführung zu gewährleisten.

🏗️ Hybrid Architecture & Logic / Hybride Architektur und Logik
English:
The system operates on a dual-platform logic, ensuring that the right tools are available for the right tasks:

The Desktop Command Center (Windows POS): Built for high-volume retail environments. It features a unique Global Hardware Hook, allowing USB Laser Scanners to input data via HardwareKeyboard events. This logic ensures that products are added to the cart instantly from any screen state, eliminating the need for manual mouse focus on input fields.

The Mobile Audit Tool (Android/iOS): Designed for mobility within the warehouse. It utilizes the mobile_scanner API to turn the device camera into a professional inventory tool, allowing the owner to perform stock audits, verify variants, and check margins while on the move.

Synchronous Cloud Core: Powered by Supabase, utilizing PL/pgSQL Remote Procedure Calls (RPCs) to handle complex financial transactions (invoicing and stock deduction) natively on the server to prevent data drift.

Deutsch:
Das System arbeitet auf einer Dual-Plattform-Logik, die sicherstellt, dass die richtigen Werkzeuge für die richtigen Aufgaben verfügbar sind:

Das Desktop-Kommandozentrum (Windows POS): Entwickelt für Einzelhandelsumgebungen mit hohem Volumen. Es verfügt über einen einzigartigen Global Hardware Hook, der es USB-Laserscannern ermöglicht, Daten über HardwareKeyboard-Events einzugeben. Diese Logik stellt sicher, dass Produkte aus jedem Bildschirmzustand sofort in den Warenkorb gelegt werden, ohne dass ein manueller Fokus der Maus auf Eingabefelder erforderlich ist.

Das mobile Audit-Tool (Android/iOS): Konzipiert für die Mobilität innerhalb des Lagers. Es nutzt die mobile_scanner-API, um die Gerätekamera in ein professionelles Inventarwerkzeug zu verwandeln, mit dem der Eigentümer Bestandsprüfungen durchführen, Varianten verifizieren und Margen von unterwegs überprüfen kann.

Synchroner Cloud-Kern: Basierend auf Supabase, nutzt PL/pgSQL Remote Procedure Calls (RPCs), um komplexe Finanztransaktionen (Rechnungsstellung und Bestandsabbuchung) nativ auf dem Server zu verarbeiten, um Datenabweichungen zu vermeiden.

🔐 Privilege Matrix & Security / Berechtigungsmatrix und Sicherheit
English:
Security is enforced through a strict Zero-Trust model between the UI and the Backend:

Owner/Administrator Role: Full vertical access. Logic includes global financial reporting, employee performance tracking, multi-store branch management, and the exclusive right to perform "Critical Mutations" (deleting records or modifying historical pricing).

Employee/Cashier Role: A horizontally restricted UI. Logic filters all data by the user’s assigned store_id. The UI proactively hides administrative menus.

Database-Level Enforcement (RLS): Beyond UI hiding, the Supabase Row-Level Security denies any unauthorized transaction at the packet level. If a restricted user attempts an unauthorized call, the frontend elegantly catches the 42501 exception, displaying a context-aware "Access Denied" notification instead of a system crash.

Deutsch:
Die Sicherheit wird durch ein strenges Zero-Trust-Modell zwischen der Benutzeroberfläche und dem Backend erzwungen:

Eigentümer-/Administratorrolle: Voller vertikaler Zugriff. Die Logik umfasst globales Finanzreporting, Leistungsverfolgung der Mitarbeiter, Verwaltung von Filialen mit mehreren Standorten und das exklusive Recht, "kritische Mutationen" (Löschen von Datensätzen oder Ändern historischer Preise) durchzuführen.

Mitarbeiter-/Kassiererrolle: Eine horizontal eingeschränkte Benutzeroberfläche. Die Logik filtert alle Daten nach der dem Benutzer zugewiesenen store_id. Die Benutzeroberfläche blendet administrative Menüs proaktiv aus.

Erzwingung auf Datenbankebene (RLS): Über das Ausblenden der Benutzeroberfläche hinaus verweigert die Supabase Row-Level Security jede unbefugte Transaktion auf Paketebene. Wenn ein eingeschränkter Benutzer einen unbefugten Aufruf versucht, fängt das Frontend die 42501-Exception elegant ab und zeigt eine kontextbezogene Benachrichtigung "Zugriff verweigert" anstelle eines Systemabsturzes an.

🗺️ Roadmap & Development Strategy / Roadmap und Entwicklungsstrategie
English:
The system currently adheres to the French-language commercial standards utilized in the Algerian trade sector. The following modules are identified as high-priority strategic expansions:

Multilingual Integration (Arabic): Extending the UI/UX logic to support a full Arabic interface across both Mobile and Desktop platforms to cater to a broader local workforce.

Refund & Return Ecosystem: Developing a robust "Transaction Reversal" logic to handle customer returns, ensuring inventory is restocked and financial ledgers are balanced without manual intervention.

Shift & Cash Management: Implementing "Register Opening/Closing" protocols to track cash flow per shift and identify financial discrepancies.

Offline-First POS: Developing a local NoSQL caching layer (Isar/Hive) to allow continuous selling during ISP outages, with background synchronization once connectivity is restored.

Expense & Debt Recovery: Independent modules for tracking operational costs (utilities, logistics) and a dedicated dashboard for independent debt repayments.

Deutsch:
Das System entspricht derzeit den im algerischen Handelssektor verwendeten französischsprachigen Handelsstandards. Die folgenden Module sind als hochprioritäre strategische Erweiterungen identifiziert:

Multilinguale Integration (Arabisch): Erweiterung der UI/UX-Logik zur Unterstützung einer vollständigen arabischen Schnittstelle sowohl auf mobilen als auch auf Desktop-Plattformen, um einer breiteren lokalen Belegschaft gerecht zu werden.

Rückerstattungs- und Rückgabe-Ökosystem: Entwicklung einer robusten "Transaktionsumkehr"-Logik für Kundenrückgaben, um sicherzustellen, dass der Bestand wieder aufgefüllt und die Finanzbücher ohne manuelles Eingreifen ausgeglichen werden.

Schicht- und Kassenmanagement: Implementierung von Protokollen zum "Öffnen/Schließen der Kasse", um den Cashflow pro Schicht zu verfolgen und finanzielle Diskrepanzen zu identifizieren.

Offline-First POS: Entwicklung einer lokalen NoSQL-Caching-Ebene (Isar/Hive), um kontinuierliche Verkäufe bei ISP-Ausfällen zu ermöglichen, mit Hintergrundsynchronisation, sobald die Verbindung wiederhergestellt ist.

Ausgaben- und Schuldeneintreibung: Unabhängige Module zur Verfolgung der Betriebskosten (Nebenkosten, Logistik) und ein spezielles Dashboard für unabhängige Schuldenrückzahlungen.

⚙️ Technical Execution / Technische Ausführung
English:
To initialize the environment for production or development:

Environment Setup: Ensure Flutter SDK (3.19+) and Windows C++ build tools are configured.

Dependency Synchronization: flutter pub get

Execution (POS): flutter run -d windows

Production Compilation: flutter build windows (Executable found in build/windows/x64/runner/Release/)

Deutsch:
So initialisieren Sie die Umgebung für Produktion oder Entwicklung:

Einrichtung der Umgebung: Stellen Sie sicher, dass das Flutter SDK (3.19+) und die Windows C++-Build-Tools konfiguriert sind.

Synchronisierung der Abhängigkeiten: flutter pub get

Ausführung (POS): flutter run -d windows

Produktionskompilierung: flutter build windows (Ausführbare Datei unter build/windows/x64/runner/Release/ zu finden)

Lead Systems Architect & Digital Transformation Consultant
Leitender Systemarchitekt und Berater für digitale Transformation