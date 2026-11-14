#!/usr/bin/env python3
"""按 tools/backup_decrypt/FORMAT.md 独立生成一个备份文件 backup_v1_python.owbak。

目的：证明格式说明本身足以实现。本脚本只依赖 PyNaCl 与标准库，**不 import 本项目的
任何代码**（包括 owbak_decrypt.py），完全照 FORMAT.md 写。Dart 测试
test/backup/backup_python_sample_test.dart 读取生成的文件并断言能解开、内容正确。

为了覆盖解析器，载荷 JSON 故意使用与 Dart 编码器不同的写法：缩进与换行、不同的键顺序、
非 ASCII 字符写成 \\u 转义（ensure_ascii）、未知字段、十六进制形式的私钥。
salt、nonce 固定，所以重复运行得到逐字节相同的文件。

所有内容都是公开测试向量或明显的假数据（BIP39 向量 abandon…about，附加密码 TREZOR）。

用法（仓库根目录）：
  pip install pynacl
  python3 packages/ow_vault/test/fixtures/generate_python_backup.py
"""
import base64
import json
import os
import struct

import nacl.bindings
import nacl.pwhash.argon2id

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'backup_v1_python.owbak')

PASSWORD = 'python-generated-password'
SALT = bytes(range(0x40, 0x50))        # 16 字节
NONCE = bytes(range(0x60, 0x78))       # 24 字节
MEM_KIB, ITERS = 8, 1                  # 测试用的极小参数（真实文件用 262144、3）

ABANDON = ('abandon abandon abandon abandon abandon abandon abandon abandon '
           'abandon abandon abandon about')

payload = {
    'payload_version': 1,
    'format': 'onewallet-backup',
    'generator_note': '未知字段，解码时应被忽略',
    'exported_at': '2026-11-13T17:00:00+08:00',
    'settings': {'theme': 'light', 'auto_lock': 'after1Min', 'quote': 'cny',
                 'hide_small': True},
    'accounts': [{
        'type': 'wallet', 'id': 'py-acc-1', 'name': '主钱包', 'color_index': 3,
        'note': '', 'wallet_source': 'trustWallet', 'exchange': None,
        'vault_item_id': 'py-item-1',
        'backup': {'keyless': False, 'offline_backed_up': False},
        'created_at': '2026-01-01T00:00:00Z',
    }],
    'addresses': [{
        'id': 'py-addr-1', 'account_id': 'py-acc-1', 'family': 'evm',
        'address': '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        'enabled_chains': ['base', 'ethereum'], 'scheme': 'evmStandard',
        'derivation_index': 0, 'note': '', 'label_color': 'unknown-field',
    }],
    'vault_items': [
        {'kind': 'mnemonic', 'id': 'py-item-1', 'name': '测试助记词',
         'created_at': '2026-01-01T00:00:00.000Z', 'mnemonic': ABANDON,
         'passphrase': 'TREZOR', 'linked_account_ids': ['py-acc-1']},
        {'kind': 'private_key', 'id': 'py-item-2', 'name': '假 Solana 私钥',
         'created_at': '2026-01-02T00:00:00Z', 'family': 'solana',
         'encoding': 'hex', 'private_key': '33' * 32, 'linked_account_ids': []},
    ],
    'exchange_credentials': [
        {'account_id': 'py-acc-1', 'api_key': 'test-api-key',
         'api_secret': 'test-api-secret'},
    ],
}

header = {
    'app_version': 'python-generator',
    'created_at': '2026-11-13T09:00:00Z',
    'nonce': base64.b64encode(NONCE).decode('ascii'),
    'kdf': {'parallelism': 1, 'iters': ITERS, 'mem_kib': MEM_KIB,
            'salt': base64.b64encode(SALT).decode('ascii'), 'alg': 'argon2id'},
}


def main():
    header_bytes = json.dumps(header, indent=1).encode('utf-8')
    prefix = b'OWBK' + bytes([1]) + struct.pack('>I', len(header_bytes)) + header_bytes
    key = nacl.pwhash.argon2id.kdf(32, PASSWORD.encode('utf-8'), SALT,
                                   opslimit=ITERS, memlimit=MEM_KIB * 1024)
    plaintext = json.dumps(payload, indent=2, ensure_ascii=True).encode('utf-8')
    ciphertext = nacl.bindings.crypto_aead_xchacha20poly1305_ietf_encrypt(
        plaintext, prefix, NONCE, key)
    with open(OUT, 'wb') as f:
        f.write(prefix + ciphertext)
    print('写入 %s（%d 字节）' % (OUT, len(prefix) + len(ciphertext)))


if __name__ == '__main__':
    main()
