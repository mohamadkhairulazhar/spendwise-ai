/// Exact decimal MYR conversion. Never passes through a floating-point value.
abstract final class Money {
  static const maxSen = 999999999999;

  static int parse(String value) {
    final match = RegExp(
      r'^(\d{1,10})(?:\.(\d{1,2}))?$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw const FormatException('Enter MYR with up to two decimal places.');
    }
    final sen =
        int.parse(match[1]!) * 100 +
        int.parse((match[2] ?? '').padRight(2, '0'));
    if (sen > maxSen) throw const FormatException('Amount is too large.');
    return sen;
  }

  static String format(int sen) =>
      'RM ${sen < 0 ? '-' : ''}${sen.abs() ~/ 100}.${(sen.abs() % 100).toString().padLeft(2, '0')}';
}
