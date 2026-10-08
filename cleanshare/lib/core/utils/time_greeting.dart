/// Time-of-day greeting copy for the home dashboard.
abstract final class TimeGreeting {
  static String greetingFor(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Good night';
  }

  static String subtitleFor(DateTime time) => 'Add a file to run a privacy scan.';
}
