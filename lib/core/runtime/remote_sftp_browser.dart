import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import '../transport/ssh/ssh_connection.dart';

class RemoteFileEntry {
  const RemoteFileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
  });

  final String name, path;
  final bool isDirectory;
  final int? size;
}

/// Read-only SFTP browser; files are capped at 256 KiB for UI safety.
class RemoteSftpBrowser {
  const RemoteSftpBrowser();

  Future<String> _resolve(SshConnection ssh, String path) async {
    if (!path.startsWith('~')) return path;
    if (path != '~' && !path.startsWith('~/')) {
      throw ArgumentError('Only ~/ home paths are supported');
    }
    final home = await ssh.run(r'printf %s "$HOME"');
    if (!home.succeeded || home.stdout.trim().isEmpty) {
      throw StateError('Could not resolve remote HOME');
    }
    return home.stdout.trim() + path.substring(1);
  }

  Future<List<RemoteFileEntry>> list(
    SshConnection ssh,
    String path,
  ) async {
    final expanded = await _resolve(ssh, path);
    final client = await ssh.sftp();
    try {
      final entries = await client.listdir(expanded);
      final result = <RemoteFileEntry>[];
      for (final entry in entries) {
        if (entry.filename == '.' || entry.filename == '..') continue;
        final pathJoined =
            expanded.replaceFirst(RegExp(r'/$'), '') + '/' + entry.filename;
        result.add(RemoteFileEntry(
          name: entry.filename,
          path: pathJoined,
          isDirectory: entry.attr.mode?.type == SftpFileType.directory,
          size: entry.attr.size,
        ));
      }
      result.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return result;
    } finally {
      await client.close();
    }
  }

  Future<String> readText(
    SshConnection ssh,
    String path, {
    int maxBytes = 256 * 1024,
  }) async {
    if (maxBytes < 1 || maxBytes > 1024 * 1024) {
      throw RangeError.value(maxBytes, 'maxBytes');
    }
    final expanded = await _resolve(ssh, path);
    final client = await ssh.sftp();
    try {
      final info = await client.stat(expanded);
      if ((info.size ?? 0) > maxBytes) {
        throw StateError('File exceeds preview limit (256 KiB)');
      }
      final file = await client.open(expanded, mode: SftpFileOpenMode.read);
      try {
        final bytes = await file.readBytes(length: maxBytes + 1);
        if (bytes.length > maxBytes) {
          throw StateError('File exceeds preview limit (256 KiB)');
        }
        if (bytes.contains(0)) {
          throw StateError('Binary file cannot be previewed as text');
        }
        return utf8.decode(bytes, allowMalformed: true);
      } finally {
        await file.close();
      }
    } finally {
      await client.close();
    }
  }

  String parent(String path) {
    final clean = path.replaceFirst(RegExp(r'/$'), '');
    final slash = clean.lastIndexOf('/');
    if (slash < 1) return '/';
    return clean.substring(0, slash);
  }
}
