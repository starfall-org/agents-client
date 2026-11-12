/// POSIX shell quote for untrusted arguments.
String shellQuote(String value) => "'" + value.replaceAll("'", r"'\''") + "'";

/// Supports ~/ in a path without evaluating arbitrary shell expressions.
String shellPath(String path) {
  if (path == '~') return r'"$HOME"';
  if (path.startsWith('~/')) {
    return r'"$HOME"/' + shellQuote(path.substring(2));
  }
  return shellQuote(path);
}

String tmuxTarget(String name) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,96}$').hasMatch(name)) {
    throw ArgumentError.value(name, 'name', 'Invalid tmux session name');
  }
  return name;
}
