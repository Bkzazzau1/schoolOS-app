import '../../proprietor/domain/concession_request.dart' show formatNaira;

/// outstandingAmountMinor and friends are in kobo (minor units), matching
/// apps.billing's *_minor convention - convert to whole naira for display.
String badDebtMoney(int minor) => formatNaira(minor ~/ 100);
