import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../domain/finance_store_models.dart';
import 'finance_authority.dart';
import 'finance_billing.dart' show paymentMethods;

class StoreActionResult {
  const StoreActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

/// The School Store: what it sells and what it has sold. The owner and the Finance Office manage it;
/// a sale always pays at the point of sale, never "on account".
class FinanceStoreRepository {
  FinanceStoreRepository({required this.database, required this.session, required this.students});

  final LocalDatabase database;
  final SchoolSessionController session;
  final AdministratorStudentsRepository students;

  /// Students a sale can be recorded against - the real school register, same as the fee ledger's own.
  Future<List<AdministratorStudentRecord>> studentRegister() async => [
        for (final s in (await students.load()).students)
          if (s.status != AdministratorStudentStatus.transferredOut) s,
      ];

  static const itemType = 'finance_store_item';
  static const saleType = 'finance_store_sale';

  Future<SchoolMembership> _operator() async {
    final m = session.requireActiveMembership();
    if (!await canOperateReceivables(database, m)) {
      throw StateError('Only the owner or the Finance Office can do this.');
    }
    return m;
  }

  Future<List<StoreItem>> items() async {
    final m = session.requireActiveMembership();
    final records = await database.getLocalRecords(tenantId: m.schoolId, entityType: itemType);
    final list = [for (final r in records) StoreItem.fromJson(r.payload)];
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<StoreSale>> sales() async {
    final m = session.requireActiveMembership();
    final records = await database.getLocalRecords(tenantId: m.schoolId, entityType: saleType);
    final list = [for (final r in records) StoreSale.fromJson(r.payload)];
    list.sort((a, b) => b.receiptNumber.compareTo(a.receiptNumber));
    return list;
  }

  /// Adds a new item, or restocks/re-prices an existing one.
  Future<StoreActionResult> saveItem({String? id, required String name, required int price, required int stock}) async {
    final SchoolMembership m;
    try {
      m = await _operator();
    } on StateError catch (e) {
      return StoreActionResult(success: false, message: e.message);
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const StoreActionResult(success: false, message: 'Enter the item name.');
    if (price <= 0) return const StoreActionResult(success: false, message: 'Enter a price above zero.');
    if (stock < 0) return const StoreActionResult(success: false, message: 'Stock cannot be negative.');
    final itemId = id ?? 'ITEM-${DateTime.now().microsecondsSinceEpoch}';
    final item = StoreItem(id: itemId, name: trimmed, price: price, stock: stock);
    await _put(m, itemType, item.id, item.toJson());
    return StoreActionResult(success: true, message: '$trimmed saved.');
  }

  /// Records a sale of one or more items to a student, paid for now.
  Future<StoreActionResult> recordSale({
    required String studentId,
    required String studentName,
    required String className,
    required List<({String itemId, int quantity})> lines,
    required String method,
    String reference = '',
    String note = '',
    DateTime? now,
  }) async {
    final SchoolMembership m;
    try {
      m = await _operator();
    } on StateError catch (e) {
      return StoreActionResult(success: false, message: e.message);
    }
    if (lines.isEmpty) return const StoreActionResult(success: false, message: 'Add at least one item.');
    if (!paymentMethods.contains(method)) return const StoreActionResult(success: false, message: 'Choose how it was paid.');
    if (method != 'Cash' && reference.trim().isEmpty) {
      return StoreActionResult(success: false, message: 'Enter the ${method == 'POS' ? 'POS' : 'bank'} reference so the sale can be reconciled.');
    }
    final catalog = await items();
    final saleLines = <StoreSaleLine>[];
    var total = 0;
    for (final line in lines) {
      final item = catalog.where((i) => i.id == line.itemId).firstOrNull;
      if (item == null) return const StoreActionResult(success: false, message: 'One of the items in this sale is no longer in the store.');
      if (line.quantity <= 0) return const StoreActionResult(success: false, message: 'Enter a quantity above zero.');
      if (line.quantity > item.stock) {
        return StoreActionResult(success: false, message: 'Only ${item.stock} of ${item.name} left in stock.');
      }
      saleLines.add(StoreSaleLine(itemId: item.id, itemName: item.name, quantity: line.quantity, unitPrice: item.price));
      total += item.price * line.quantity;
    }
    if (reference.trim().isNotEmpty) {
      final clash = (await sales()).any((s) => !s.isVoided && s.reference.trim().toLowerCase() == reference.trim().toLowerCase());
      if (clash) return const StoreActionResult(success: false, message: 'That reference has already been recorded on another sale.');
    }

    final all = await sales();
    final at = now ?? DateTime.now();
    final sale = StoreSale(
      id: 'SALE-${at.microsecondsSinceEpoch}',
      receiptNumber: 'STR-${(all.length + 1).toString().padLeft(6, '0')}',
      studentId: studentId, studentName: studentName, className: className,
      items: saleLines, amount: total, method: method, soldAt: at.toUtc().toIso8601String(),
      reference: reference.trim(), recordedBy: m.id, note: note.trim(),
    );
    await _put(m, saleType, sale.id, sale.toJson());
    await _adjustStock(m, catalog, saleLines, sign: -1);
    return StoreActionResult(success: true, message: 'Receipt ${sale.receiptNumber}: ${_naira(total)} received for $studentName.');
  }

  /// Cancels a sale recorded by mistake. It is kept, with the reason, and the items go back into stock.
  Future<StoreActionResult> voidSale(StoreSale sale, String reason) async {
    final SchoolMembership m;
    try {
      m = await _operator();
    } on StateError catch (e) {
      return StoreActionResult(success: false, message: e.message);
    }
    if (sale.isVoided) return const StoreActionResult(success: false, message: 'This sale is already voided.');
    if (reason.trim().isEmpty) return const StoreActionResult(success: false, message: 'Say why the sale is voided.');
    final updated = sale.voided(reason.trim());
    await _put(m, saleType, updated.id, updated.toJson());
    await _adjustStock(m, await items(), sale.items, sign: 1);
    return StoreActionResult(success: true, message: 'Receipt ${sale.receiptNumber} voided.');
  }

  /// Keeps this device's own copy of stock in step with a sale/void it just recorded, the same way
  /// the server's own StoreSaleHandler.after_write does - otherwise this screen would show stale
  /// numbers until the next sync pull overwrites them.
  Future<void> _adjustStock(SchoolMembership m, List<StoreItem> catalog, List<StoreSaleLine> lines, {required int sign}) async {
    for (final line in lines) {
      final item = catalog.where((i) => i.id == line.itemId).firstOrNull;
      if (item == null) continue;
      final updated = StoreItem(id: item.id, name: item.name, price: item.price, stock: item.stock + sign * line.quantity);
      await _put(m, itemType, updated.id, updated.toJson());
    }
  }

  Future<void> _put(SchoolMembership m, String type, String id, Map<String, Object?> payload) async {
    final existing = await database.getLocalRecord(tenantId: m.schoolId, entityType: type, entityId: id);
    await database.upsertLocalRecord(
      tenantId: m.schoolId, entityType: type, entityId: id, payload: payload,
      serverVersion: existing?.serverVersion, isDirty: true,
    );
    await database.queueMutation(
      tenantId: m.schoolId, membershipId: m.id, entityType: type, entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload, baseVersion: existing?.serverVersion,
    );
  }

  static String _naira(int amount) {
    final raw = amount.toString();
    final b = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) b.write(',');
      b.write(raw[i]);
    }
    return '₦$b';
  }
}
