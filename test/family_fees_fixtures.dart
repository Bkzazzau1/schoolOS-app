// JSON exactly as the SchoolOS server sends it for family payment accounts, so the tests break if the app and the
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

Map<String, Object?> myFamilyJson({
  String id = 'fam-1',
  String code = 'FAM-K7Q2M9XA',
  String name = 'Bello family',
  List<Map<String, Object?>> accounts = const [],
}) =>
    {
      'id': id,
      'code': code,
      'displayName': name,
      'status': 'active',
      'createdAt': '2026-09-01T09:00:00+01:00',
      'mergedInto': null,
      'mergedAt': null,
      'position': {'outstandingMinor': 28000000, 'currency': 'NGN'},
      'collectionAccounts': accounts,
    };

Map<String, Object?> myFamiliesJson(List<Map<String, Object?>> families) => {'families': families};

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
