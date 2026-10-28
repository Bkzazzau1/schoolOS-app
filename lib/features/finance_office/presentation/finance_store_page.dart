import 'package:flutter/material.dart';

import '../../administrator/domain/administrator_students_models.dart';
import '../data/finance_billing.dart' show paymentMethods;
import '../data/finance_store_repository.dart';
import '../domain/finance_concessions_models.dart' show financeMoney;
import '../domain/finance_store_models.dart';

class FinanceStorePage extends StatefulWidget {
  const FinanceStorePage({super.key, required this.repository, this.onChanged});

  final FinanceStoreRepository repository;
  final VoidCallback? onChanged;

  @override
  State<FinanceStorePage> createState() => _FinanceStorePageState();
}

class _FinanceStorePageState extends State<FinanceStorePage> {
  List<StoreItem> _items = const [];
  List<StoreSale> _sales = const [];
  List<AdministratorStudentRecord> _students = const [];
  bool _loading = true;
  String? _error;
  String? _notice;
  bool _showItemForm = false;
  bool _showSaleForm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.items();
      final sales = await widget.repository.sales();
      final students = await widget.repository.studentRegister();
      if (!mounted) return;
      setState(() {
        _items = items;
        _sales = sales;
        _students = students;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text('Could not load the store. $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final theme = Theme.of(context);
    final lowStock = _items.where((i) => i.stock < 5).length;
    final activeSales = _sales.where((s) => !s.isVoided);
    final revenue = activeSales.fold<int>(0, (sum, s) => sum + s.amount);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('FINANCE OFFICE · SCHOOL STORE', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('School Store', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Uniforms, books and stationery, sold at the point of sale. A sale is always paid for now - never on account.'),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            key: const ValueKey('store-add-item'),
            onPressed: () => setState(() { _showItemForm = !_showItemForm; _showSaleForm = false; _notice = null; _editing = null; }),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add item'),
          ),
          FilledButton.icon(
            key: const ValueKey('store-record-sale'),
            onPressed: _items.isEmpty
                ? null
                : () => setState(() { _showSaleForm = !_showSaleForm; _showItemForm = false; _notice = null; }),
            icon: const Icon(Icons.point_of_sale_outlined),
            label: const Text('Record sale'),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Kpi('Items in catalog', '${_items.length}'),
          _Kpi('Low stock (<5)', '$lowStock'),
          _Kpi('Sales revenue', financeMoney(revenue)),
          _Kpi('Sales recorded', '${activeSales.length}'),
        ]),
        if (_notice != null) ...[const SizedBox(height: 14), _Notice(text: _notice!)],
        if (_showItemForm) ...[const SizedBox(height: 14), _ItemForm(key: ValueKey('store-item-form-${_editing?.id}'), initial: _editing, onSubmit: _addItem)],
        if (_showSaleForm) ...[
          const SizedBox(height: 14),
          _SaleForm(items: _items, students: _students, onSubmit: _recordSale),
        ],
        const SizedBox(height: 18),
        Text('Catalog', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (_items.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No items in the store yet.')),
        for (final item in _items)
          Card(
            key: ValueKey('store-item-${item.id}'),
            elevation: 0,
            child: ListTile(
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${financeMoney(item.price)} each'),
              trailing: Text(
                '${item.stock} in stock',
                style: TextStyle(fontWeight: FontWeight.w900, color: item.stock < 5 ? theme.colorScheme.error : null),
              ),
              onTap: () => setState(() { _showItemForm = true; _showSaleForm = false; _editing = item; }),
            ),
          ),
        const SizedBox(height: 18),
        Text('Sales', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (_sales.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No sales recorded yet.')),
        for (final sale in _sales)
          Card(
            key: ValueKey('store-sale-${sale.id}'),
            elevation: 0,
            child: ListTile(
              title: Text('${sale.receiptNumber} · ${sale.studentName}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${sale.className} · ${[for (final l in sale.items) '${l.quantity}× ${l.itemName}'].join(', ')}'
                '${sale.isVoided ? '\nVOIDED (${sale.voidedReason})' : ''}',
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(financeMoney(sale.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (!sale.isVoided)
                    TextButton(onPressed: () => _void(sale), child: const Text('Void')),
                ],
              ),
            ),
          ),
      ],
    );
  }

  StoreItem? _editing;

  Future<void> _addItem(String name, int price, int stock) async {
    final result = await widget.repository.saveItem(id: _editing?.id, name: name, price: price, stock: stock);
    if (!mounted) return;
    setState(() { _notice = result.message; if (result.success) { _showItemForm = false; _editing = null; } });
    if (result.success) { widget.onChanged?.call(); await _load(); }
  }

  Future<void> _recordSale(
    AdministratorStudentRecord student,
    List<({String itemId, int quantity})> lines,
    String method,
    String reference,
  ) async {
    final result = await widget.repository.recordSale(
      studentId: student.id, studentName: student.name, className: student.className,
      lines: lines, method: method, reference: reference,
    );
    if (!mounted) return;
    setState(() { _notice = result.message; if (result.success) _showSaleForm = false; });
    if (result.success) { widget.onChanged?.call(); await _load(); }
  }

  Future<void> _void(StoreSale sale) async {
    final reason = await _askReason(context);
    if (reason == null) return;
    final result = await widget.repository.voidSale(sale, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) { widget.onChanged?.call(); await _load(); }
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void this sale'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? null : controller.text.trim()),
            child: const Text('Void'),
          ),
        ],
      ),
    );
  }
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({super.key, this.initial, required this.onSubmit});

  final StoreItem? initial;
  final Future<void> Function(String name, int price, int stock) onSubmit;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _price = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.price}');
  late final _stock = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.stock}');

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
              SizedBox(width: 260, child: TextFormField(key: const ValueKey('store-item-name'), controller: _name, decoration: const InputDecoration(labelText: 'Item name'), validator: _required)),
              SizedBox(width: 160, child: TextFormField(key: const ValueKey('store-item-price'), controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₦)'), validator: _positive)),
              SizedBox(width: 160, child: TextFormField(key: const ValueKey('store-item-stock'), controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock'), validator: _nonNegative)),
              FilledButton(
                key: const ValueKey('store-item-save'),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.onSubmit(_name.text, int.parse(_price.text), int.parse(_stock.text));
                },
                child: const Text('Save'),
              ),
            ]),
          ),
        ),
      );

  static String? _required(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;
  static String? _positive(String? v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter a price above zero' : null;
  static String? _nonNegative(String? v) => (int.tryParse(v ?? '') ?? -1) < 0 ? 'Enter a valid stock' : null;
}

class _SaleForm extends StatefulWidget {
  const _SaleForm({required this.items, required this.students, required this.onSubmit});

  final List<StoreItem> items;
  final List<AdministratorStudentRecord> students;
  final Future<void> Function(
    AdministratorStudentRecord student,
    List<({String itemId, int quantity})> lines,
    String method,
    String reference,
  ) onSubmit;

  @override
  State<_SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends State<_SaleForm> {
  AdministratorStudentRecord? _student;
  StoreItem? _pickedItem;
  final _quantity = TextEditingController(text: '1');
  final List<({String itemId, int quantity})> _lines = [];
  String _method = 'Cash';
  final _reference = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _addLine() {
    final item = _pickedItem;
    final qty = int.tryParse(_quantity.text) ?? 0;
    if (item == null || qty <= 0) return;
    setState(() {
      _lines.add((itemId: item.id, quantity: qty));
      _pickedItem = null;
      _quantity.text = '1';
    });
  }

  String _lineLabel(({String itemId, int quantity}) line) {
    final item = widget.items.where((i) => i.id == line.itemId).firstOrNull;
    return '${line.quantity}× ${item?.name ?? line.itemId}';
  }

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Record a sale', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Paid for now, at the point of sale.'),
            const SizedBox(height: 14),
            DropdownButtonFormField<AdministratorStudentRecord>(
              key: const ValueKey('store-sale-student'),
              isExpanded: true,
              initialValue: _student,
              decoration: const InputDecoration(labelText: 'Student'),
              items: [for (final s in widget.students) DropdownMenuItem(value: s, child: Text('${s.name} · ${s.className}'))],
              onChanged: (v) => setState(() => _student = v),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<StoreItem>(
                  key: const ValueKey('store-sale-item'),
                  isExpanded: true,
                  initialValue: _pickedItem,
                  decoration: const InputDecoration(labelText: 'Item'),
                  items: [for (final i in widget.items) DropdownMenuItem(value: i, child: Text('${i.name} (${i.stock} left)'))],
                  onChanged: (v) => setState(() => _pickedItem = v),
                ),
              ),
              SizedBox(width: 100, child: TextField(key: const ValueKey('store-sale-quantity'), controller: _quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty'))),
              OutlinedButton(key: const ValueKey('store-sale-add-line'), onPressed: _addLine, child: const Text('Add')),
            ]),
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < _lines.length; i++)
                  Chip(label: Text(_lineLabel(_lines[i])), onDeleted: () => setState(() => _lines.removeAt(i))),
              ]),
            ],
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('store-sale-method'),
                  isExpanded: true,
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: [for (final m in paymentMethods) DropdownMenuItem(value: m, child: Text(m))],
                  onChanged: (v) => setState(() => _method = v ?? _method),
                ),
              ),
              if (_method != 'Cash')
                SizedBox(width: 220, child: TextField(key: const ValueKey('store-sale-reference'), controller: _reference, decoration: const InputDecoration(labelText: 'Reference'))),
              FilledButton(
                key: const ValueKey('store-sale-submit'),
                onPressed: (_student == null || _lines.isEmpty)
                    ? null
                    : () => widget.onSubmit(_student!, _lines, _method, _reference.text),
                child: const Text('Record sale'),
              ),
            ]),
          ]),
        ),
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 5),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Text(text),
      );
}
