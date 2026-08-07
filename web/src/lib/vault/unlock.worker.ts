import { deriveKek, type KdfParams } from './crypto';

type Request = {
  password: string;
  passcode: string;
  saltPw: Uint8Array;
  saltPc: Uint8Array;
  kdf: KdfParams;
  passcodeKdf: KdfParams;
};

const encoder = new TextEncoder();

self.onmessage = (event: MessageEvent<Request>) => {
  const { password, passcode, saltPw, saltPc, kdf, passcodeKdf } = event.data;

  try {
    const kek = deriveKek(encoder.encode(password), saltPw, kdf);
    const passcodeKey = deriveKek(encoder.encode(passcode), saltPc, passcodeKdf);
    self.postMessage({ kek, passcodeKey });
  } catch {
    self.postMessage({ error: 'Those secrets could not be turned into a key.' });
  }
};
