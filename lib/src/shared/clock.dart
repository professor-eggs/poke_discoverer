/// Abstraction over time retrieval to keep logic testable.
abstract class Clock {
  DateTime now();
}

/// Default implementation using [DateTime.now].
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
