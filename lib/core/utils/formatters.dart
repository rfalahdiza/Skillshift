import 'package:intl/intl.dart';

import '../config/env.dart';

final _rupiah = NumberFormat.decimalPattern('id_ID');

/// `25000` → `Rp25.000` (Indonesian grouping, no space, as in the designs).
String formatRupiah(num amount) => 'Rp${_rupiah.format(amount.round())}';

/// `2451505001110011` → `2451505••••••` (first 7 digits kept).
String maskNim(String? nim) {
  if (nim == null || nim.isEmpty) return '—';
  const keep = 7;
  if (nim.length <= keep) return nim;
  return '${nim.substring(0, keep)}${'•' * 6}';
}

/// `Raka Pratama` → `RP`.
String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

/// True for addresses on an allowed UB domain (exact domain match, so
/// `x@evil-ub.ac.id` and `x@ub.ac.id.evil.com` are rejected).
bool isUbEmail(
  String email, {
  List<String> domains = AppDefaults.allowedEmailDomains,
}) {
  final value = email.trim().toLowerCase();
  final at = value.lastIndexOf('@');
  if (at <= 0 || at == value.length - 1) return false;
  final local = value.substring(0, at);
  if (!RegExp(r'^[a-z0-9._%+\-]+$').hasMatch(local)) return false;
  return domains.contains(value.substring(at + 1));
}

/// Platform fee split, rounded to whole rupiah (fee rounds half up).
({int gross, int fee, int net}) splitPayment(
  int gross, {
  int feePercent = AppDefaults.platformFeePercent,
}) {
  final fee = (gross * feePercent / 100).round();
  return (gross: gross, fee: fee, net: gross - fee);
}
