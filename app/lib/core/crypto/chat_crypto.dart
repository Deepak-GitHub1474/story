import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';


class ChatIdentity {
  const ChatIdentity({required this.publicKey, required this.privateKey});

  final String publicKey;
  final String privateKey;
}

class ChatCrypto {
  const ChatCrypto();

  static const keyLength = 32;
  static const nonceLength = 12;
  static const cekAadPrefix = 'story.cek.v1|';
  static const messageAadPrefix = 'story.msg.v1|';
  static const sharedInfo = 'story.chat.shared.v1';
  static const identityAadPrefix = 'story.chat.identity.v1|';
  static const saltLength = 16;
  static const identityIterations = 600000;

  X25519 get _exchange => X25519();

  AesGcm get _cipher => AesGcm.with256bits();

  Future<ChatIdentity> newIdentity() async {
    final pair = await _exchange.newKeyPair();
    final private = await pair.extractPrivateKeyBytes();
    final public = await pair.extractPublicKey();
    return ChatIdentity(
      publicKey: base64Encode(public.bytes),
      privateKey: base64Encode(private),
    );
  }

  Future<ChatIdentity> restoreIdentity(String privateKey) async {
    final pair = await _exchange.newKeyPairFromSeed(base64Decode(privateKey));
    final public = await pair.extractPublicKey();
    return ChatIdentity(publicKey: base64Encode(public.bytes), privateKey: privateKey);
  }

  Future<Uint8List> sharedKey({
    required ChatIdentity mine,
    required String theirPublicKey,
  }) async {
    final pair = await _exchange.newKeyPairFromSeed(base64Decode(mine.privateKey));
    final secret = await _exchange.sharedSecretKey(
      keyPair: pair,
      remotePublicKey: SimplePublicKey(
        base64Decode(theirPublicKey),
        type: KeyPairType.x25519,
      ),
    );

    final derived = await Hkdf(hmac: Hmac.sha256(), outputLength: keyLength).deriveKey(
      secretKey: secret,
      info: utf8.encode(sharedInfo),
      nonce: const <int>[],
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  Future<Uint8List> newConversationKey() async {
    final key = await _cipher.newSecretKey();
    return Uint8List.fromList(await key.extractBytes());
  }

  Future<String> seal({
    required Uint8List key,
    required Uint8List plaintext,
    required String aad,
  }) async {
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      aad: utf8.encode(aad),
    );
    return base64Encode([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<Uint8List> open({
    required Uint8List key,
    required String sealed,
    required String aad,
  }) async {
    final raw = base64Decode(sealed);
    final macLength = _cipher.macAlgorithm.macLength;
    final box = SecretBox(
      raw.sublist(nonceLength, raw.length - macLength),
      nonce: raw.sublist(0, nonceLength),
      mac: Mac(raw.sublist(raw.length - macLength)),
    );
    final opened = await _cipher.decrypt(
      box,
      secretKey: SecretKey(key),
      aad: utf8.encode(aad),
    );
    return Uint8List.fromList(opened);
  }

  static String pairKey(String first, String second) =>
      ([first, second]..sort()).join(':');

  Future<String> wrapForPeer({
    required Uint8List cek,
    required ChatIdentity mine,
    required String theirPublicKey,
    required String pair,
    required String recipientId,
  }) async {
    final key = await sharedKey(mine: mine, theirPublicKey: theirPublicKey);
    return seal(key: key, plaintext: cek, aad: '$cekAadPrefix$pair|$recipientId');
  }

  Future<Uint8List> unwrapFromPeer({
    required String wrapped,
    required ChatIdentity mine,
    required String theirPublicKey,
    required String pair,
    required String recipientId,
  }) async {
    final key = await sharedKey(mine: mine, theirPublicKey: theirPublicKey);
    return open(key: key, sealed: wrapped, aad: '$cekAadPrefix$pair|$recipientId');
  }

  Future<String> encryptMessage({
    required Uint8List cek,
    required String text,
    required String conversationId,
  }) => seal(
    key: cek,
    plaintext: Uint8List.fromList(utf8.encode(text)),
    aad: '$messageAadPrefix$conversationId',
  );

  Future<String> decryptMessage({
    required Uint8List cek,
    required String ciphertext,
    required String conversationId,
  }) async {
    final opened = await open(
      key: cek,
      sealed: ciphertext,
      aad: '$messageAadPrefix$conversationId',
    );
    return utf8.decode(opened);
  }
}


extension ChatIdentityBackup on ChatCrypto {
  Future<String> randomSalt() async {
    final key = await AesGcm.with256bits().newSecretKey();
    final bytes = await key.extractBytes();
    return base64Encode(bytes.take(ChatCrypto.saltLength).toList());
  }

  Future<Uint8List> _identityKey(String password, String salt) async {
    final derived = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: ChatCrypto.identityIterations,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: base64Decode(salt),
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  Future<String> wrapIdentity({
    required ChatIdentity identity,
    required String password,
    required String salt,
    required String userId,
  }) async {
    final key = await _identityKey(password, salt);
    return seal(
      key: key,
      plaintext: Uint8List.fromList(base64Decode(identity.privateKey)),
      aad: '${ChatCrypto.identityAadPrefix}$userId',
    );
  }

  Future<ChatIdentity> unwrapIdentity({
    required String wrapped,
    required String password,
    required String salt,
    required String userId,
  }) async {
    final key = await _identityKey(password, salt);
    final privateKey = await open(
      key: key,
      sealed: wrapped,
      aad: '${ChatCrypto.identityAadPrefix}$userId',
    );
    return restoreIdentity(base64Encode(privateKey));
  }
}
