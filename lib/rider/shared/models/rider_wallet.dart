part of '../../app.dart';

// Keep backend decimal strings intact; no client balance calculation.
class RiderWallet {
  const RiderWallet(this.availableTokens);
  final String availableTokens;
  factory RiderWallet.fromJson(Map<String, dynamic> json) =>
      RiderWallet(json['available_tokens'].toString());
}

class RiderWalletPage {
  const RiderWalletPage(this.items, this.lastPage);
  final List<RiderWalletTransaction> items;
  final int lastPage;
}

class RiderWalletTransaction {
  RiderWalletTransaction.fromJson(Map<String, dynamic> json)
    : id = _riderInt(json['id']),
      type = json['type'].toString(),
      amount = json['amount'].toString(),
      balanceAfter = json['balance_after'].toString(),
      deliveryId = json['delivery_id'] == null
          ? null
          : _riderInt(json['delivery_id']),
      note = _riderString(json['note']),
      createdAt = DateTime.tryParse(json['created_at'].toString());
  final int id;
  final String type;
  final String amount;
  final String balanceAfter;
  final int? deliveryId;
  final String? note;
  final DateTime? createdAt;
  bool get isDebit => amount.startsWith('-');
  String get title => switch (type) {
    'TOP_UP' => 'Top Up',
    'DELIVERY_DEDUCTION' => 'Delivery Deduction',
    _ => 'Wallet Adjustment',
  };
}

String riderCoins(String decimal) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(decimal);
  if (match == null) return 'Unavailable';
  final whole = match[2]!.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '${match[1]}$whole.${(match[3] ?? '').padRight(2, '0')}';
}
