import { cryptoFramework } from '@kit.CryptoArchitectureKit';

const KEY_SHARE_A: number[] = [
  192, 122, 58, 20, 106, 115, 192, 84, 70, 158, 17, 89, 236, 21, 199, 177,
  227, 46, 81, 206, 96, 147, 120, 241, 231, 232, 151, 65, 210, 153, 93, 251
];

const KEY_SHARE_B: number[] = [
  134, 235, 89, 167, 249, 141, 63, 194, 110, 102, 9, 59, 245, 65, 117, 219,
  169, 94, 180, 105, 87, 26, 11, 116, 157, 131, 182, 24, 63, 114, 108, 194
];

export class FoodDatabaseCrypto {
  static async decrypt(encrypted: Uint8Array): Promise<Uint8Array> {
    const nonceLength: number = 12;
    const tagLength: number = 16;
    if (encrypted.length <= nonceLength + tagLength) {
      throw new Error('Encrypted food database is invalid');
    }

    const keyBytes: Uint8Array = new Uint8Array(KEY_SHARE_A.length);
    for (let index: number = 0; index < KEY_SHARE_A.length; index++) {
      keyBytes[index] = KEY_SHARE_A[index] ^ KEY_SHARE_B[index];
    }

    const keyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
    const key = await keyGenerator.convertKey({ data: keyBytes });
    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    const nonce: Uint8Array = encrypted.slice(0, nonceLength);
    const authTag: Uint8Array = encrypted.slice(encrypted.length - tagLength);
    const ciphertext: Uint8Array = encrypted.slice(nonceLength, encrypted.length - tagLength);
    const params: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: nonce },
      aad: { data: new Uint8Array(0) },
      authTag: { data: authTag }
    };
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, key, params);
    const plaintext = await cipher.doFinal({ data: ciphertext });
    return plaintext.data;
  }
}
