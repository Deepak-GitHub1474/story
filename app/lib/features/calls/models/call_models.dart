enum CallDirection { incoming, outgoing }

enum CallOutcome { answered, missed, declined, busy, failed }

enum CallPhase { idle, dialling, ringing, connecting, connected, ended }

class IceServer {
  const IceServer({required this.urls, this.username, this.credential});

  factory IceServer.fromJson(Map<String, dynamic> json) => IceServer(
    urls: (json['urls'] as List<dynamic>).map((url) => url as String).toList(),
    username: json['username'] as String?,
    credential: json['credential'] as String?,
  );

  final List<String> urls;
  final String? username;
  final String? credential;

  Map<String, dynamic> toMap() => {
    'urls': urls,
    if (username != null) 'username': username,
    if (credential != null) 'credential': credential,
  };
}

class CallPeer {
  const CallPeer({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarSeed,
  });

  factory CallPeer.fromJson(Map<String, dynamic> json) => CallPeer(
    userId: json['user_id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String? ?? json['username'] as String,
    avatarSeed: json['avatar_seed'] as String?,
  );

  final String userId;
  final String username;
  final String displayName;
  final String? avatarSeed;
}

class CallStart {
  const CallStart({
    required this.callId,
    required this.conversationId,
    required this.media,
    required this.peer,
    required this.iceServers,
    required this.ringTimeoutSeconds,
  });

  factory CallStart.fromJson(Map<String, dynamic> json) => CallStart(
    callId: json['call_id'] as String,
    conversationId: json['conversation_id'] as String,
    media: (json['media'] as List<dynamic>).map((kind) => kind as String).toList(),
    peer: CallPeer.fromJson(Map<String, dynamic>.from(json['peer'] as Map)),
    iceServers: (json['ice_servers'] as List<dynamic>)
        .map((server) => IceServer.fromJson(Map<String, dynamic>.from(server as Map)))
        .toList(),
    ringTimeoutSeconds: json['ring_timeout_seconds'] as int? ?? 45,
  );

  final String callId;
  final String conversationId;
  final List<String> media;
  final CallPeer peer;
  final List<IceServer> iceServers;
  final int ringTimeoutSeconds;

  bool get hasVideo => media.contains('video');

  List<Map<String, dynamic>> get iceServerMaps =>
      iceServers.map((server) => server.toMap()).toList();
}

class CallRecord {
  const CallRecord({
    required this.callId,
    required this.peerId,
    required this.peer,
    required this.conversationId,
    required this.direction,
    required this.outcome,
    required this.media,
    required this.relayed,
    required this.startedAt,
    required this.durationSeconds,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    callId: json['call_id'] as String,
    peerId: json['peer_id'] as String,
    conversationId: json['conversation_id'] as String,
    peer: json['peer'] == null
        ? null
        : CallPeer.fromJson(Map<String, dynamic>.from(json['peer'] as Map)),
    direction: json['direction'] == 'in'
        ? CallDirection.incoming
        : CallDirection.outgoing,
    outcome: _outcome(json['outcome'] as String?),
    media: (json['media'] as List<dynamic>? ?? const ['audio'])
        .map((kind) => kind as String)
        .toList(),
    relayed: json['relayed'] as bool? ?? false,
    startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
    durationSeconds: json['duration_seconds'] as int? ?? 0,
  );

  final String callId;
  final String peerId;
  final CallPeer? peer;
  final String conversationId;
  final CallDirection direction;
  final CallOutcome outcome;
  final List<String> media;
  final bool relayed;
  final DateTime startedAt;
  final int durationSeconds;

  bool get wasAnswered => outcome == CallOutcome.answered;

  String? get spoken {
    if (durationSeconds <= 0) return null;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static CallOutcome _outcome(String? value) => switch (value) {
    'answered' => CallOutcome.answered,
    'missed' => CallOutcome.missed,
    'declined' => CallOutcome.declined,
    'busy' => CallOutcome.busy,
    _ => CallOutcome.failed,
  };
}

class CallHistoryPage {
  const CallHistoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory CallHistoryPage.fromJson(Map<String, dynamic> json) => CallHistoryPage(
    items: (json['items'] as List<dynamic>)
        .map((row) => CallRecord.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(),
    nextCursor: json['next_cursor'] as String?,
    hasMore: json['has_more'] as bool? ?? false,
  );

  final List<CallRecord> items;
  final String? nextCursor;
  final bool hasMore;
}


class CallInvite {
  const CallInvite({required this.start, required this.sdp});

  factory CallInvite.fromJson(Map<String, dynamic> json) => CallInvite(
    start: CallStart.fromJson({
      'call_id': json['call_id'],
      'conversation_id': json['conversation_id'] ?? '',
      'media': json['media'] ?? const ['audio'],
      'peer': json['peer'] ?? const {'user_id': '', 'username': '', 'display_name': 'Someone'},
      'ice_servers': json['ice_servers'] ?? const [],
      'ring_timeout_seconds': json['ring_timeout_seconds'] ?? 45,
    }),
    sdp: json['sdp'] as String,
  );

  final CallStart start;
  final String sdp;
}
