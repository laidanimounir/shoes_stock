// ══════════════════════════════════════════════════════════════
// ShoeStock ERP — Local DB Enums (mirrors Supabase enums/checks)
// ══════════════════════════════════════════════════════════════

// ── transaction_type enum (Postgres enum) ──────────────────
enum TransactionType { in_, out, return_ }

extension TransactionTypeExt on TransactionType {
  String toSupabaseString() {
    switch (this) {
      case TransactionType.in_:
        return 'in';
      case TransactionType.out:
        return 'out';
      case TransactionType.return_:
        return 'return';
    }
  }

  static TransactionType fromString(String value) {
    switch (value) {
      case 'in':
        return TransactionType.in_;
      case 'out':
        return TransactionType.out;
      case 'return':
        return TransactionType.return_;
      default:
        throw ArgumentError('Unknown TransactionType: $value');
    }
  }
}

// ── user_role enum (Postgres enum) ─────────────────────────
enum UserRole { owner, employee }

extension UserRoleExt on UserRole {
  String toSupabaseString() {
    switch (this) {
      case UserRole.owner:
        return 'owner';
      case UserRole.employee:
        return 'employee';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'owner':
        return UserRole.owner;
      case 'employee':
        return UserRole.employee;
      default:
        throw ArgumentError('Unknown UserRole: $value');
    }
  }
}

// ── invoice_status (text + CHECK constraint) ───────────────
enum InvoiceStatus { paid, partial, unpaid, refunded, returned, cancelled }

extension InvoiceStatusExt on InvoiceStatus {
  String toSupabaseString() {
    switch (this) {
      case InvoiceStatus.paid:
        return 'paid';
      case InvoiceStatus.partial:
        return 'partial';
      case InvoiceStatus.unpaid:
        return 'unpaid';
      case InvoiceStatus.refunded:
        return 'refunded';
      case InvoiceStatus.returned:
        return 'returned';
      case InvoiceStatus.cancelled:
        return 'cancelled';
    }
  }

  static InvoiceStatus fromString(String value) {
    switch (value) {
      case 'paid':
        return InvoiceStatus.paid;
      case 'partial':
        return InvoiceStatus.partial;
      case 'unpaid':
        return InvoiceStatus.unpaid;
      case 'refunded':
        return InvoiceStatus.refunded;
      case 'returned':
        return InvoiceStatus.returned;
      case 'cancelled':
        return InvoiceStatus.cancelled;
      default:
        throw ArgumentError('Unknown InvoiceStatus: $value');
    }
  }
}

// ── invoice_type (text + CHECK constraint) ─────────────────
enum InvoiceType { in_, out, return_ }

extension InvoiceTypeExt on InvoiceType {
  String toSupabaseString() {
    switch (this) {
      case InvoiceType.in_:
        return 'in';
      case InvoiceType.out:
        return 'out';
      case InvoiceType.return_:
        return 'return';
    }
  }

  static InvoiceType fromString(String value) {
    switch (value) {
      case 'in':
        return InvoiceType.in_;
      case 'out':
        return InvoiceType.out;
      case 'return':
        return InvoiceType.return_;
      default:
        throw ArgumentError('Unknown InvoiceType: $value');
    }
  }
}

// ── sync_status (local only — offline queue) ───────────────
enum SyncStatus { pending, synced, failed }

extension SyncStatusExt on SyncStatus {
  String toSupabaseString() {
    switch (this) {
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.failed:
        return 'failed';
    }
  }

  static SyncStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return SyncStatus.pending;
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      default:
        throw ArgumentError('Unknown SyncStatus: $value');
    }
  }
}

// ── sync_operation_type (local only — maps to RPCs) ────────
enum SyncOperationType {
  createInvoice,
  createPayment,
  createTransaction,
  processRefund,
  createExpense,
  createDebtRecoveryPayment,
  createLogDiscount,
}

extension SyncOperationTypeExt on SyncOperationType {
  String toSupabaseString() {
    switch (this) {
      case SyncOperationType.createInvoice:
        return 'create_invoice';
      case SyncOperationType.createPayment:
        return 'create_payment';
      case SyncOperationType.createTransaction:
        return 'create_transaction';
      case SyncOperationType.processRefund:
        return 'process_refund';
      case SyncOperationType.createExpense:
        return 'create_expense';
      case SyncOperationType.createDebtRecoveryPayment:
        return 'create_debt_recovery_payment';
      case SyncOperationType.createLogDiscount:
        return 'create_log_discount';
    }
  }

  static SyncOperationType fromString(String value) {
    switch (value) {
      case 'create_invoice':
        return SyncOperationType.createInvoice;
      case 'create_payment':
        return SyncOperationType.createPayment;
      case 'create_transaction':
        return SyncOperationType.createTransaction;
      case 'process_refund':
        return SyncOperationType.processRefund;
      case 'create_expense':
        return SyncOperationType.createExpense;
      case 'create_debt_recovery_payment':
        return SyncOperationType.createDebtRecoveryPayment;
      case 'create_log_discount':
        return SyncOperationType.createLogDiscount;
      default:
        throw ArgumentError('Unknown SyncOperationType: $value');
    }
  }
}

// ── payment_method (text + CHECK constraint) ───────────────
enum PaymentMethod { cash, bank, mobile }

extension PaymentMethodExt on PaymentMethod {
  String toSupabaseString() {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.bank:
        return 'bank';
      case PaymentMethod.mobile:
        return 'mobile';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'bank':
        return PaymentMethod.bank;
      case 'mobile':
        return PaymentMethod.mobile;
      default:
        throw ArgumentError('Unknown PaymentMethod: $value');
    }
  }
}

// ── payment_type (text + CHECK constraint) ─────────────────
enum PaymentType { invoice, debtRecovery }

extension PaymentTypeExt on PaymentType {
  String toSupabaseString() {
    switch (this) {
      case PaymentType.invoice:
        return 'invoice';
      case PaymentType.debtRecovery:
        return 'debt_recovery';
    }
  }

  static PaymentType fromString(String value) {
    switch (value) {
      case 'invoice':
        return PaymentType.invoice;
      case 'debt_recovery':
        return PaymentType.debtRecovery;
      default:
        throw ArgumentError('Unknown PaymentType: $value');
    }
  }
}
