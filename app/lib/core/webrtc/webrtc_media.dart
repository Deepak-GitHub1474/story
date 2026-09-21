import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../features/calls/data/call_session.dart';
import '../security/call_ui.dart';

const Map<String, dynamic> _audioOnly = {
  'audio': {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
  },
  'video': false,
};

class WebRtcMedia implements CallMedia {
  WebRtcMedia({
    required this.onLocalCandidate,
    required this.onConnectionChanged,
    required this.onConnectionFailed,
  });

  final void Function(Map<String, dynamic> candidate) onLocalCandidate;
  final void Function(bool connected) onConnectionChanged;
  final void Function() onConnectionFailed;

  RTCPeerConnection? _peer;
  MediaStream? _local;
  bool _asCaller = true;
  final List<RTCIceCandidate> _pending = [];
  bool _remoteReady = false;

  @override
  Future<void> start({
    required List<Map<String, dynamic>> iceServers,
    required bool asCaller,
  }) async {
    _asCaller = asCaller;
    await CallUi.startAudio();
    _local = await navigator.mediaDevices.getUserMedia(_audioOnly);

    final peer = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });

    for (final track in _local!.getTracks()) {
      await peer.addTrack(track, _local!);
    }

    peer.onIceCandidate = (candidate) {
      onLocalCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    peer.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onConnectionFailed();
        return;
      }
      onConnectionChanged(
        state == RTCPeerConnectionState.RTCPeerConnectionStateConnected,
      );
    };

    _peer = peer;
  }

  @override
  Future<String> createOffer() async {
    final peer = _peer!;
    final offer = await peer.createOffer({'offerToReceiveAudio': 1});
    await peer.setLocalDescription(offer);
    return offer.sdp!;
  }

  @override
  Future<String> createAnswer() async {
    final peer = _peer!;
    final answer = await peer.createAnswer({'offerToReceiveAudio': 1});
    await peer.setLocalDescription(answer);
    return answer.sdp!;
  }

  @override
  Future<void> acceptRemote(String sdp) async {
    final peer = _peer;
    if (peer == null) return;

    await peer.setRemoteDescription(
      RTCSessionDescription(sdp, _asCaller ? 'answer' : 'offer'),
    );

    _remoteReady = true;
    for (final candidate in _pending) {
      await peer.addCandidate(candidate);
    }
    _pending.clear();
  }

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async {
    final parsed = RTCIceCandidate(
      candidate['candidate'] as String?,
      candidate['sdpMid'] as String?,
      candidate['sdpMLineIndex'] as int?,
    );

    if (!_remoteReady) {
      _pending.add(parsed);
      return;
    }
    await _peer?.addCandidate(parsed);
  }

  @override
  Future<void> setMuted(bool value) async {
    for (final track in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !value;
    }
  }

  @override
  Future<void> setSpeaker(bool value) async {
    await CallUi.setSpeaker(value);
  }

  @override
  Future<void> stop() async {
    for (final track in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _local?.dispose();
    await _peer?.close();
    await CallUi.stopAudio();
    _local = null;
    _peer = null;
    _asCaller = true;
    _pending.clear();
    _remoteReady = false;
  }
}
