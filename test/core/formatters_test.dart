import 'package:flutter_test/flutter_test.dart';
import 'package:skillshift/core/utils/formatters.dart';

void main() {
  test('formatRupiah uses Indonesian grouping', () {
    expect(formatRupiah(25000), 'Rp25.000');
    expect(formatRupiah(157500), 'Rp157.500');
    expect(formatRupiah(0), 'Rp0');
  });

  test('maskNim keeps the first 7 digits', () {
    expect(maskNim('245150500111001'), '2451505••••••');
    expect(maskNim(null), '—');
    expect(maskNim('12345'), '12345');
  });

  test('initialsOf', () {
    expect(initialsOf('Raka Pratama'), 'RP');
    expect(initialsOf('nadia'), 'N');
    expect(initialsOf('  Salsabila   Hanum Putri '), 'SH');
    expect(initialsOf(''), '?');
  });

  group('isUbEmail', () {
    test('accepts both UB domains', () {
      expect(isUbEmail('nadia.putri@student.ub.ac.id'), isTrue);
      expect(isUbEmail('Dosen@UB.ac.id '), isTrue);
    });

    test('rejects look-alikes and other domains', () {
      for (final e in [
        'a@gmail.com',
        'a@evil-ub.ac.id',
        'a@ub.ac.id.evil.com',
        'a@sub.student.ub.ac.id',
        '@ub.ac.id',
        'a@',
        'a b@ub.ac.id',
      ]) {
        expect(isUbEmail(e), isFalse, reason: e);
      }
    });
  });

  test('splitPayment at 10% matches the designs', () {
    final s = splitPayment(25000);
    expect(s.fee, 2500);
    expect(s.net, 22500);
    expect(splitPayment(12500).net, 11250);
  });
}
