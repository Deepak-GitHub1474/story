import 'package:story_app/features/calls/data/call_session.dart';

class FakeMedia implements CallMedia {
  final List<String> did = [];
  String? remoteDescription;
  final List<Map<String, dynamic>> candidates = [];
  bool muted = false;
  bool speaker = false;
  void Function(String sdp)? onLocalOffer;
  void Function(Map<String, dynamic> candidate)? onCandidate;
  void Function(bool connected)? onConnection;

  @override
  Future<void> start({
    required List<Map<String, dynamic>> iceServers,
    required bool asCaller,
  }) async {
    did.add(asCaller ? 'start:caller' : 'start:callee');
  }

  @override
  Future<String> createOffer() async {
    did.add('offer');
    return 'sdp-offer';
  }

  @override
  Future<String> createAnswer() async {
    did.add('answer');
    return 'sdp-answer';
  }

  @override
  Future<void> acceptRemote(String sdp) async {
    remoteDescription = sdp;
    did.add('remote');
  }

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async {
    candidates.add(candidate);
  }

  @override
  Future<void> setMuted(bool value) async => muted = value;

  @override
  Future<void> setSpeaker(bool value) async => speaker = value;

  @override
  Future<void> stop() async => did.add('stop');
}

class FakeSignal implements CallSignal {
  final List<Map<String, dynamic>> sent = [];

  @override
  void send(Map<String, dynamic> event) => sent.add(event);
}
