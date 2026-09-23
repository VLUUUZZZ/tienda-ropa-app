/// Exponential backoff: each [next] delay doubles the previous one, up to
/// [max], until [reset] is called after a success.
class Backoff {
  Backoff({required this.initial, required this.max}) : _next = initial;

  final Duration initial;
  final Duration max;
  Duration _next;

  Duration next() {
    final current = _next;
    final doubled = _next * 2;
    _next = doubled > max ? max : doubled;
    return current;
  }

  void reset() => _next = initial;
}
