#!/usr/bin/env python3
"""生成"独立实现对照"样本 crosscheck_vectors.json。

注意：这里的值**不是官方测试向量**，而是用与本项目 Dart 绑定无关的另一条调用路径算出的
对照值，用来确认我们按本项目实际使用的参数（32 字节输出、16 字节截取等）调用时结果正确：
  - Argon2id、XChaCha20-Poly1305：PyNaCl（它自带并绑定 libsodium，与 Dart 的 `sodium` 包
    是两套独立的绑定代码）；
  - 带密钥的 BLAKE2b 与 crypto_kdf：Python 标准库 hashlib.blake2b（CPython 自带的 BLAKE2
    实现，与 libsodium 无代码关系）。crypto_kdf_derive_from_key 按 libsodium 文档的定义
    等价于 BLAKE2b(key=主密钥, salt=子密钥 id 的 8 字节小端 ‖ 8 个零字节,
    person=上下文 8 字节 ‖ 8 个零字节, message=空)。
官方向量见同目录的 libsodium_vectors.json 与测试中引用的 IETF 草案向量。

所有输入都是明显的假数据，不对应任何真实密码或密钥。

用法（仓库根目录）：
  pip install pynacl
  python3 packages/ow_vault/test/fixtures/generate_crosscheck_vectors.py
"""
import hashlib
import json
import os

import nacl
import nacl.bindings as sodium

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'crosscheck_vectors.json')

# draft-irtf-cfrg-xchacha-03 附录 A.3.1 的测试向量。生成时断言 PyNaCl 得出相同的密文与标签。
DRAFT_KEY = bytes(range(0x80, 0xa0))
DRAFT_NONCE = bytes(range(0x40, 0x58))
DRAFT_AAD = bytes.fromhex('50515253c0c1c2c3c4c5c6c7')
DRAFT_PLAINTEXT = (b"Ladies and Gentlemen of the class of '99: If I could offer you "
                   b'only one tip for the future, sunscreen would be it.')
DRAFT_CIPHERTEXT = bytes.fromhex(
    'bd6d179d3e83d43b9576579493c0e939572a1700252bfaccbed2902c21396cbb'
    '731c7f1b0b4aa6440bf3a82f4eda7e39ae64c6708c54c216cb96b72e1213b452'
    '2f8c9ba40db5d945b11b69b982c1bb9e3f3fac2bc369488f76b2383565d3fff9'
    '21f9664c97637da9768812f615c68b13b52e')
DRAFT_TAG = bytes.fromhex('c0875924c1c7987947deafd8780acf49')


def argon2id_cases():
    cases = [
        (b'correct horse battery staple', bytes(range(16)), 8, 1),
        (b'correct horse battery staple', bytes(range(16)), 64, 2),
        (b'another fake password', bytes([0xaa] * 16), 1024, 3),
        ('含中文的假密码'.encode(), bytes(range(16, 32)), 256, 1),
        # 保险库默认参数：64 MiB、迭代 3。
        (b'default-params fake password', bytes([0x5a] * 16), 65536, 3),
    ]
    out = []
    for password, salt, mem_kib, iters in cases:
        key = sodium.crypto_pwhash_alg(
            32, password, salt, iters, mem_kib * 1024,
            sodium.crypto_pwhash_ALG_ARGON2ID13)
        out.append({
            'password_hex': password.hex(), 'salt_hex': salt.hex(),
            'mem_kib': mem_kib, 'iterations': iters, 'expected_hex': key.hex(),
        })
    return out


def kdf(master, subkey_id, context, length=32):
    salt = subkey_id.to_bytes(8, 'little') + bytes(8)
    person = context.encode('ascii') + bytes(8)
    return hashlib.blake2b(b'', digest_size=length, key=master, salt=salt,
                           person=person).digest()


def kdf_cases():
    master = bytes([0x42] * 32)
    out = []
    for context in ('ow_items', 'ow_fprnt'):
        for subkey_id in (0, 1, 2**32 + 7):
            out.append({
                'master_key_hex': master.hex(), 'context': context,
                'subkey_id': subkey_id, 'expected_hex': kdf(master, subkey_id, context).hex(),
            })
    return out


def keyed_hash_cases():
    out = []
    for key, message, length in (
        (bytes([0x33] * 32), b'', 16),
        (bytes([0x33] * 32), b'fingerprint input', 16),
        (bytes([0x34] * 32), b'fingerprint input', 16),
        (bytes(range(32)), bytes(range(200)), 32),
    ):
        digest = hashlib.blake2b(message, digest_size=length, key=key).digest()
        out.append({'key_hex': key.hex(), 'message_hex': message.hex(),
                    'length': length, 'expected_hex': digest.hex()})
    return out


def draft_xchacha():
    ct = sodium.crypto_aead_xchacha20poly1305_ietf_encrypt(
        DRAFT_PLAINTEXT, DRAFT_AAD, DRAFT_NONCE, DRAFT_KEY)
    assert ct == DRAFT_CIPHERTEXT + DRAFT_TAG, 'PyNaCl 与草案向量不一致'
    return {'confirmed_by_pynacl': True}


def main():
    data = {
        '_note': '独立实现对照，不是官方向量。生成脚本：generate_crosscheck_vectors.py',
        '_tools': 'PyNaCl %s；Python hashlib.blake2b' % nacl.__version__,
        'argon2id_32': argon2id_cases(),
        'kdf_32': kdf_cases(),
        'keyed_hash': keyed_hash_cases(),
        'xchacha_draft_a31': draft_xchacha(),
    }
    with open(OUT, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print('已写入', OUT)


if __name__ == '__main__':
    main()
