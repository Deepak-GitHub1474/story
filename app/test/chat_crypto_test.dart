import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/crypto/chat_crypto.dart';

const chat = ChatCrypto();

void main() {
  test('an identity keypair has a 32 byte public key', () async {
    final identity = await chat.newIdentity();
    expect(base64Decode(identity.publicKey).length, 32);
  });

  test('two identities are never the same', () async {
    final first = await chat.newIdentity();
    final second = await chat.newIdentity();
    expect(first.publicKey, isNot(second.publicKey));
  });

  test('both sides derive the same shared secret', () async {
    final ann = await chat.newIdentity();
    final ben = await chat.newIdentity();

    final annSide = await chat.sharedKey(mine: ann, theirPublicKey: ben.publicKey);
    final benSide = await chat.sharedKey(mine: ben, theirPublicKey: ann.publicKey);

    expect(annSide, equals(benSide));
  });

  test('a third party derives a different secret', () async {
    final ann = await chat.newIdentity();
    final ben = await chat.newIdentity();
    final eve = await chat.newIdentity();

    final real = await chat.sharedKey(mine: ann, theirPublicKey: ben.publicKey);
    final wrong = await chat.sharedKey(mine: eve, theirPublicKey: ben.publicKey);

    expect(real, isNot(wrong));
  });

  test('a conversation key survives being wrapped and unwrapped', () async {
    final ann = await chat.newIdentity();
    final ben = await chat.newIdentity();
    final cek = await chat.newConversationKey();

    final wrapped = await chat.wrapForPeer(
      cek: cek,
      mine: ann,
      theirPublicKey: ben.publicKey,
      pair: 'usr_ann:usr_ben',
      recipientId: 'usr_ben',
    );
    final unwrapped = await chat.unwrapFromPeer(
      wrapped: wrapped,
      mine: ben,
      theirPublicKey: ann.publicKey,
      pair: 'usr_ann:usr_ben',
      recipientId: 'usr_ben',
    );

    expect(unwrapped, equals(cek));
  });

  test('a wrapped key meant for someone else does not open', () async {
    final ann = await chat.newIdentity();
    final ben = await chat.newIdentity();
    final cek = await chat.newConversationKey();

    final wrapped = await chat.wrapForPeer(
      cek: cek,
      mine: ann,
      theirPublicKey: ben.publicKey,
      pair: 'usr_ann:usr_ben',
      recipientId: 'usr_ben',
    );

    expect(
      () => chat.unwrapFromPeer(
        wrapped: wrapped,
        mine: ben,
        theirPublicKey: ann.publicKey,
        pair: 'usr_ann:usr_ben',
        recipientId: 'usr_someone_else',
      ),
      throwsA(anything),
    );
  });

  test('a wrapped key moved to another pair does not open', () async {
    final ann = await chat.newIdentity();
    final ben = await chat.newIdentity();
    final cek = await chat.newConversationKey();

    final wrapped = await chat.wrapForPeer(
      cek: cek,
      mine: ann,
      theirPublicKey: ben.publicKey,
      pair: 'usr_ann:usr_ben',
      recipientId: 'usr_ben',
    );

    expect(
      () => chat.unwrapFromPeer(
        wrapped: wrapped,
        mine: ben,
        theirPublicKey: ann.publicKey,
        pair: 'usr_ann:usr_eve',
        recipientId: 'usr_ben',
      ),
      throwsA(anything),
    );
  });

  test('a message round trips', () async {
    final cek = await chat.newConversationKey();

    final sealed = await chat.encryptMessage(
      cek: cek,
      text: 'meet me at the cafe 🌤',
      conversationId: 'cnv_1',
    );
    final opened = await chat.decryptMessage(
      cek: cek,
      ciphertext: sealed,
      conversationId: 'cnv_1',
    );

    expect(opened, 'meet me at the cafe 🌤');
  });

  test('the ciphertext never contains the words', () async {
    final cek = await chat.newConversationKey();
    final sealed = await chat.encryptMessage(
      cek: cek,
      text: 'the secret word is orange',
      conversationId: 'cnv_1',
    );

    expect(utf8.decode(base64Decode(sealed), allowMalformed: true), isNot(contains('orange')));
  });

  test('a message from another conversation does not open', () async {
    final cek = await chat.newConversationKey();
    final sealed = await chat.encryptMessage(
      cek: cek,
      text: 'hello',
      conversationId: 'cnv_1',
    );

    expect(
      () => chat.decryptMessage(cek: cek, ciphertext: sealed, conversationId: 'cnv_2'),
      throwsA(anything),
    );
  });

  test('a wrong key does not open a message', () async {
    final real = await chat.newConversationKey();
    final other = await chat.newConversationKey();
    final sealed = await chat.encryptMessage(
      cek: real,
      text: 'hello',
      conversationId: 'cnv_1',
    );

    expect(
      () => chat.decryptMessage(cek: other, ciphertext: sealed, conversationId: 'cnv_1'),
      throwsA(anything),
    );
  });

  test('two encryptions of the same text differ', () async {
    final cek = await chat.newConversationKey();
    final first = await chat.encryptMessage(cek: cek, text: 'hi', conversationId: 'c');
    final second = await chat.encryptMessage(cek: cek, text: 'hi', conversationId: 'c');

    expect(first, isNot(second));
  });

  test('an identity survives being stored and restored', () async {
    final identity = await chat.newIdentity();
    final restored = await chat.restoreIdentity(identity.privateKey);

    expect(restored.publicKey, identity.publicKey);
  });

  test('emoji only messages work', () async {
    final cek = await chat.newConversationKey();
    final sealed = await chat.encryptMessage(cek: cek, text: '😂🫂❤️', conversationId: 'c');

    expect(
      await chat.decryptMessage(cek: cek, ciphertext: sealed, conversationId: 'c'),
      '😂🫂❤️',
    );
  });

  test('the sender opens their own copy with the peer key, not their own', () async {
    final ann = await chat.newIdentity();
    final ben = await chat.newIdentity();
    final cek = await chat.newConversationKey();
    const pair = 'usr_ann:usr_ben';

    final forAnn = await chat.wrapForPeer(
      cek: cek,
      mine: ann,
      theirPublicKey: ben.publicKey,
      pair: pair,
      recipientId: 'usr_ann',
    );

    expect(
      await chat.unwrapFromPeer(
        wrapped: forAnn,
        mine: ann,
        theirPublicKey: ben.publicKey,
        pair: pair,
        recipientId: 'usr_ann',
      ),
      equals(cek),
    );

    expect(
      () => chat.unwrapFromPeer(
        wrapped: forAnn,
        mine: ann,
        theirPublicKey: ann.publicKey,
        pair: pair,
        recipientId: 'usr_ann',
      ),
      throwsA(anything),
      reason: 'using your own public key derives a different secret',
    );
  });

  test('both sides derive the same key from the other persons public key', () async {
    final ann = await chat.newIdentity();
    final ben = await chat.newIdentity();
    final cek = await chat.newConversationKey();
    const pair = 'usr_ann:usr_ben';

    final forBen = await chat.wrapForPeer(
      cek: cek,
      mine: ann,
      theirPublicKey: ben.publicKey,
      pair: pair,
      recipientId: 'usr_ben',
    );

    expect(
      await chat.unwrapFromPeer(
        wrapped: forBen,
        mine: ben,
        theirPublicKey: ann.publicKey,
        pair: pair,
        recipientId: 'usr_ben',
      ),
      equals(cek),
    );
  });

  test('a long message works', () async {
    final cek = await chat.newConversationKey();
    final text = List.filled(400, 'a sentence that keeps going. ').join();
    final sealed = await chat.encryptMessage(cek: cek, text: text, conversationId: 'c');

    expect(
      await chat.decryptMessage(cek: cek, ciphertext: sealed, conversationId: 'c'),
      text,
    );
  });
}
