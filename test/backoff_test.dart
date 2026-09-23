import 'package:flutter_test/flutter_test.dart';

import 'package:tienda_ropa_app/data/backoff.dart';

void main() {
  test('doubles each delay up to the max, and reset starts over', () {
    final backoff = Backoff(
      initial: const Duration(seconds: 5),
      max: const Duration(seconds: 30),
    );

    final delays = [for (var i = 0; i < 5; i++) backoff.next().inSeconds];
    expect(delays, [5, 10, 20, 30, 30]);

    backoff.reset();
    expect(backoff.next(), const Duration(seconds: 5));
  });
}
