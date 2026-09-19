import '../domain/finance_store_models.dart';

const financeStoreOrders = <FinanceStoreOrder>[
  FinanceStoreOrder(
    id: 'ORD-2026-00481',
    student: 'Maryam Abdullahi',
    className: 'JSS 2A',
    guardian: 'Alhaji Abdullahi Yusuf',
    items: '2 Shirts · 1 Skirt · Book Pack',
    amount: 34500,
    account: '2038457291',
    expires: '18 Sep 2026',
    status: FinanceStoreOrderStatus.partiallyIssued,
    issued: 'Uniform issued · Book Pack pending',
  ),
  FinanceStoreOrder(
    id: 'ORD-2026-00482',
    student: 'Hafsa Abdullahi',
    className: 'Primary 3',
    guardian: 'Alhaji Abdullahi Yusuf',
    items: 'Primary Book Pack · Cardigan',
    amount: 28500,
    account: '2038457307',
    expires: '19 Sep 2026',
    status: FinanceStoreOrderStatus.paidReady,
    issued: 'Awaiting collection',
  ),
  FinanceStoreOrder(
    id: 'ORD-2026-00483',
    student: 'Muhammad Kabir',
    className: 'Primary 5',
    guardian: 'Hajiya Amina Kabir',
    items: 'Sportswear Set',
    amount: 12500,
    account: '2038457315',
    expires: '18 Sep 2026',
    status: FinanceStoreOrderStatus.awaitingPayment,
    issued: 'Not issued',
  ),
  FinanceStoreOrder(
    id: 'ORD-2026-00479',
    student: 'Zainab Aliyu',
    className: 'Nursery 2',
    guardian: 'Alhaji Aliyu Sani',
    items: '2 Nursery Uniform Sets',
    amount: 22000,
    account: '2038457264',
    expires: '15 Sep 2026',
    status: FinanceStoreOrderStatus.completed,
    issued: 'Fully issued',
  ),
];

const financeStoreStock = <FinanceStoreStockItem>[
  FinanceStoreStockItem(item: 'School Shirt', opening: 160, issued: 86, available: 124, price: 7000),
  FinanceStoreStockItem(item: 'Skirt', opening: 92, issued: 41, available: 51, price: 8500),
  FinanceStoreStockItem(item: 'Primary Book Pack', opening: 110, issued: 68, available: 42, price: 18000),
  FinanceStoreStockItem(item: 'JSS Book Pack', opening: 95, issued: 54, available: 41, price: 12000),
  FinanceStoreStockItem(item: 'Sportswear Set', opening: 78, issued: 39, available: 39, price: 12500),
  FinanceStoreStockItem(item: 'Cardigan', opening: 64, issued: 28, available: 36, price: 10500),
];

FinanceStoreTotals financeStoreTotals(List<FinanceStoreOrder> orders) =>
    FinanceStoreTotals(
      sales: orders.where((order) => order.isPaid).fold(0, (sum, order) => sum + order.amount),
      openOrders: orders.where((order) => order.isOpen).length,
      paidNotFullyIssued: orders.where((order) => order.isPaidNotFullyIssued).length,
      awaitingPayment: orders.where((order) => order.status == FinanceStoreOrderStatus.awaitingPayment).length,
      lowStockItems: 2,
    );

const financeStoreFeeRailTitle = 'School Fees';
const financeStoreFeeRailRule =
    'Static student term account · tuition and approved compulsory term charges only.';
const financeStoreSundryRailTitle = 'Store / Sundry';
const financeStoreSundryRailRule =
    'Dynamic account created for one order · exact expected amount · linked directly to goods/services.';

const financeStoreControlExceptions = <(String, String, String)>[
  (
    '2 paid orders not fully issued',
    'Finance has confirmed payment, but store fulfillment is incomplete.',
    'Priority control exception',
  ),
  (
    '1 order awaiting payment',
    'Dynamic account remains active until expiry.',
    'No tuition balance affected',
  ),
  (
    'Books revenue · ₦58,500',
    'Tracked separately from tuition collections.',
    'Store revenue ledger',
  ),
  (
    'Uniform revenue · ₦39,000',
    'Linked to item issue records and stock movement.',
    'Inventory-linked',
  ),
];

const financeStorePaymentBoundary =
    'A local device must never convert an order to Paid · ready without authoritative bank/provider confirmation. A queued or offline action is not settlement.';
const financeStoreRailBoundary =
    'Store and sundry collections remain separate from tuition. Store orders must not alter the student term-fee balance.';
const financeStorePrototypeBoundary =
    'New order, payment-account assignment and receipt printing remain prototype actions until their production workflows are connected.';
