// JSON exactly as the SkulGen server sends it for family payment accounts, so the tests break if the app and the
// server stop agreeing about a field.

Map<String, Object?> payAccountJson({
  String id = 'acc-1',
  String provider = 'gtbank',
  String bankName = 'GTBank',
  String accountName = 'BRIGHTGATE / BELLO',
  String accountNumber = '0123456789',
  String numberLabel = 'Account number',
  List<Map<String, String>> details = const [],
  String note = '',
  String status = 'active',
  bool? canPay,
  bool isTest = false,
  bool staff = false,
}) {
  final payable = canPay ?? (status == 'active' || status == 'dormant');
  return {
    'id': id,
    'provider': provider,
    'bankName': bankName,
    'accountName': accountName,
    // The server withholds the number of an account a family cannot pay into right now.
    'accountNumber': payable ? accountNumber : '',
    'numberLabel': numberLabel,
    'details': payable ? details : <Object?>[],
    'status': status,
    'isTest': isTest,
    if (!staff) ...{'note': note, 'canPay': payable},
    if (staff) ...{'familyId': 'fam-1', 'connectionId': null, 'currency': 'NGN'},
  };
}

Map<String, Object?> familyPositionJson({
  int grossMinor = 30000000,
  int adjustmentsMinor = 0,
  int netMinor = 30000000,
  int paidMinor = 2000000,
  int outstandingMinor = 28000000,
  int overdueMinor = 0,
  int arrearsMinor = 0,
  int currentMinor = 28000000,
  int creditMinor = 0,
  int collectibleMinor = 28000000,
  int charges = 3,
}) =>
    {
      'grossMinor': grossMinor,
      'adjustmentsMinor': adjustmentsMinor,
      'netMinor': netMinor,
      'paidMinor': paidMinor,
      'outstandingMinor': outstandingMinor,
      'overdueMinor': overdueMinor,
      'arrearsMinor': arrearsMinor,
      'currentMinor': currentMinor,
      'creditMinor': creditMinor,
      'collectibleMinor': collectibleMinor,
      'charges': charges,
      'currency': 'NGN',
    };

Map<String, Object?> myFamilyJson({
  String id = 'fam-1',
  String code = 'FAM-K7Q2M9XA',
  String name = 'Bello family',
  List<Map<String, Object?>> accounts = const [],
  Map<String, Object?>? position,
}) =>
    {
      'id': id,
      'code': code,
      'displayName': name,
      'status': 'active',
      'createdAt': '2026-09-01T09:00:00+01:00',
      'mergedInto': null,
      'mergedAt': null,
      'position': position ?? familyPositionJson(),
      'collectionAccounts': accounts,
    };

Map<String, Object?> myFamiliesJson(List<Map<String, Object?>> families) => {'families': families};

Map<String, Object?> verifiedAllocationJson({
  String studentId = 'stu-1',
  String studentName = 'Ahmad Bello',
  String purpose = 'tuition',
  int amountMinor = 12000000,
  String item = 'Tuition',
}) =>
    {'studentId': studentId, 'studentName': studentName, 'purpose': purpose, 'amountMinor': amountMinor, 'receivableId': 'rec-1', 'item': item};

Map<String, Object?> verifiedPaymentJson({
  String transactionId = 'tx-1',
  String date = '2026-10-12T09:30:00+01:00',
  String provider = 'paystack',
  String reference = 'PSK-4471',
  int amountMinor = 12000000,
  String status = 'matched',
  bool countsTowardBalance = true,
  List<Map<String, Object?>>? allocations,
  int allocatedMinor = 12000000,
  int creditMinor = 0,
  int unappliedMinor = 0,
}) =>
    {
      'transactionId': transactionId,
      'date': date,
      'provider': provider,
      'reference': reference,
      'amountMinor': amountMinor,
      'status': status,
      'countsTowardBalance': countsTowardBalance,
      'allocations': allocations ?? [verifiedAllocationJson()],
      'allocatedMinor': allocatedMinor,
      'creditMinor': creditMinor,
      'unappliedMinor': unappliedMinor,
    };

Map<String, Object?> verifiedPaymentsJson(List<Map<String, Object?>> payments) => {'payments': payments};

Map<String, Object?> familyRowJson({
  String id = 'fam-1',
  String code = 'FAM-K7Q2M9XA',
  String name = 'Bello family',
  String status = 'active',
  String? mergedInto,
  List<String> students = const ['Ahmad Bello', 'Aisha Bello', 'Maryam Bello'],
  List<Map<String, Object?>> accounts = const [],
}) =>
    {
      'id': id,
      'code': code,
      'displayName': name,
      'status': status,
      'createdAt': '2026-09-01T09:00:00+01:00',
      'mergedInto': mergedInto,
      'mergedAt': null,
      'students': [
        for (final (i, s) in students.indexed) {'id': '$id-s$i', 'name': s, 'studentCode': 'BG-$i', 'status': 'active'},
      ],
      'collectionAccounts': accounts,
    };

Map<String, Object?> familyPageJson(List<Map<String, Object?>> families, {bool hasMore = false, bool canDecideBilling = false}) => {
      'families': families,
      'hasMore': hasMore,
      'permissions': {'canDecideBilling': canDecideBilling},
    };

Map<String, Object?> mergePreviewJson({List<Map<String, String>> problems = const []}) => {
      'preview': {
        'problems': problems,
        'source': {
          'id': 'fam-2', 'code': 'FAM-SANI', 'name': 'Sani family', 'status': 'active',
          'students': ['Yusuf Sani'], 'outstandingMinor': 9000000, 'creditMinor': 0, 'charges': 1,
        },
        'into': {
          'id': 'fam-1', 'code': 'FAM-K7Q2M9XA', 'name': 'Bello family', 'status': 'active',
          'students': ['Ahmad Bello', 'Aisha Bello', 'Maryam Bello'], 'outstandingMinor': 30000000, 'creditMinor': 500000, 'charges': 3,
        },
        'moves': {'students': 1, 'charges': 1, 'creditEntries': 0, 'payments': 2, 'statements': 0, 'payers': 1},
        'accountsMoved': [
          {'provider': 'uba', 'bankName': 'UBA'},
        ],
        'accountsKeptAsIs': [
          {'provider': 'gtbank', 'bankName': 'GTBank'},
        ],
        'irreversible': true,
      },
    };
