abstract class Logger {
  void d(String message);
  void i(String message);
  void w(String message);
  void e(String message, {Object? error});
  void n(String message);
}
