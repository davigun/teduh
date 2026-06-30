/// The single source of "now" for the whole app, injected via `clockProvider`.
///
/// Calendar / day-index math uses [nowLocal] (then is normalised to a
/// [CalendarDate]); stored instants such as `completedAt` / `updatedAt` use
/// [nowUtc]. Keeping both behind one provider is what kills the classic
/// time-of-day / DST off-by-one bugs in the plan and streak engines.
class SystemClock {
  const SystemClock();

  DateTime nowLocal() => DateTime.now();
  DateTime nowUtc() => DateTime.now().toUtc();
}
