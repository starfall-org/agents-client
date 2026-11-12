/// Transport-agnostic command/terminal surface used by the agent adapters.
class RemoteCommandResult {
  const RemoteCommandResult(this.stdout, this.stderr, this.exitCode);
  final String stdout, stderr;
  final int? exitCode;
  bool get succeeded => exitCode == 0;
}

abstract interface class RemoteTerminalChannel {
  Stream<String> get output;
  void write(String text);
  void resize(int columns, int rows);
  Future<void> get done;
  void close();
}

abstract interface class RemoteExecutor {
  bool get connected;
  Future<RemoteCommandResult> run(String command);
  Future<RemoteTerminalChannel> openTerminal(String command);
}
