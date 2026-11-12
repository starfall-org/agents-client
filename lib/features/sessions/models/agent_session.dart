enum Agent { claude, codex, opencode }

enum WorkState { running, approval, ready, available, done, disconnected }

class ChatLine {
  ChatLine(this.content, this.byUser, this.when);
  final String content;
  final bool byUser;
  final String when;
}

class AgentSession {
  AgentSession(this.id, this.project, this.host, this.path, this.agent,
      this.state, this.summary, this.updated, this.lines,
      {this.showActivity = false,
      this.remoteHostId,
      this.tmuxName,
      this.providerSessionId,
      this.providerSourcePath,
      this.httpProfileId});
  final String id, project, host, path;
  final Agent agent;
  WorkState state;
  String summary, updated;
  List<ChatLine> lines;
  final bool showActivity;
  final String? remoteHostId,
      providerSessionId,
      providerSourcePath,
      httpProfileId;
  String? tmuxName;
  bool get isHttpRemote => httpProfileId != null && providerSessionId != null;
  bool get isSshRemote =>
      remoteHostId != null && (tmuxName != null || providerSessionId != null);
  bool get isRemote => isSshRemote || isHttpRemote;
  bool resolved = false;
}
