import '../../sessions/models/agent_session.dart';

enum ProfileProtocol { ssh, http }

/// Non-secret configuration for one coding-agent connection.
/// HTTP credentials are deliberately stored separately in secure storage.
class AgentProfile {
  const AgentProfile({
    required this.id,
    required this.name,
    required this.agent,
    this.hostId = '',
    this.protocol = ProfileProtocol.ssh,
    this.httpUrl,
    this.httpUsername = 'opencode',
  });

  final String id;
  final String name;
  final Agent agent;
  final String hostId;
  final ProfileProtocol protocol;
  final String? httpUrl;
  final String httpUsername;

  bool get usesHttp =>
      agent == Agent.opencode && protocol == ProfileProtocol.http;

  /// Avoid sending HTTP Basic credentials over plaintext remote networks.
  /// Localhost HTTP is supported for local OpenCode development.
  static String? validateHttpUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return 'Enter a valid HTTP(S) URL without credentials, query or fragment.';
    }
    final local = {'localhost', '127.0.0.1', '[::1]', '::1'}
        .contains(uri.host.toLowerCase());
    if (uri.scheme == 'http' && !local) {
      return 'Use HTTPS for remote servers to protect login credentials.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'agent': agent.name,
        'protocol': protocol.name,
        'hostId': usesHttp ? null : hostId,
        'httpUrl': usesHttp ? httpUrl : null,
        'httpUsername': usesHttp ? httpUsername : null,
      };

  factory AgentProfile.fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final name = data['name'];
    final agentName = data['agent'];
    final protocolName = data['protocol'] ?? ProfileProtocol.ssh.name;
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        agentName is! String ||
        protocolName is! String ||
        !Agent.values.any((value) => value.name == agentName) ||
        !ProfileProtocol.values.any((value) => value.name == protocolName)) {
      throw const FormatException('Invalid agent profile');
    }
    final agent = Agent.values.firstWhere((value) => value.name == agentName);
    final protocol = ProfileProtocol.values
        .firstWhere((value) => value.name == protocolName);
    if (protocol == ProfileProtocol.http) {
      final url = data['httpUrl'];
      final username = data['httpUsername'] ?? 'opencode';
      if (agent != Agent.opencode ||
          url is! String ||
          validateHttpUrl(url) != null ||
          username is! String ||
          username.trim().isEmpty) {
        throw const FormatException('Invalid HTTP OpenCode profile');
      }
      return AgentProfile(
        id: id,
        name: name,
        agent: agent,
        protocol: protocol,
        httpUrl: url.trim(),
        httpUsername: username.trim(),
      );
    }
    final hostId = data['hostId'];
    if (hostId is! String || hostId.isEmpty) {
      throw const FormatException('SSH profile requires a host');
    }
    return AgentProfile(
      id: id,
      name: name,
      agent: agent,
      hostId: hostId,
    );
  }
}
