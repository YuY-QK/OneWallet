#!/usr/bin/env python3
"""从 libsodium 源码包自带的测试套件中提取官方测试向量，写成 libsodium_vectors.json。

这些是 libsodium 项目自己的测试向量（test/default/*.c 与对应的 *.exp 期望输出），
不是本项目生成的。源码包就是 `sodium` 包随附、由构建钩子编译的那一份：
  ~/.pub-cache/hosted/pub.dev/sodium-<版本>/3rdparty/libsodium-<版本>-stable.tar.gz
该源码包的 minisign 签名已用 libsodium 的公钥核对（见 docs/ADR_005_libsodium接入.md）。

用法（仓库根目录）：
  python3 packages/ow_vault/test/fixtures/extract_libsodium_vectors.py [源码包路径]
"""
import glob
import json
import os
import re
import sys
import tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'libsodium_vectors.json')


def find_archive():
    if len(sys.argv) > 1:
        return sys.argv[1]
    pattern = os.path.expanduser(
        '~/.pub-cache/hosted/pub.dev/sodium-*/3rdparty/libsodium-*-stable.tar.gz')
    found = sorted(glob.glob(pattern))
    if not found:
        sys.exit('找不到 libsodium 源码包，请把路径作为参数传入')
    return found[-1]


def read_member(tar, name):
    return tar.extractfile('libsodium-stable/test/default/' + name).read().decode()


def hex_concat(literals):
    return ''.join(re.findall(r'"([0-9a-f]*)"', literals))


def argon2id(tar):
    src = read_member(tar, 'pwhash_argon2id.c')
    exp = read_member(tar, 'pwhash_argon2id.exp').splitlines()
    body = src[src.index('tv(void)'):]
    body = body[:body.index('};')]
    entry = re.compile(
        r'\{\s*((?:"[0-9a-f]*"\s*)+),\s*(\d+),\s*"([0-9a-f]+)",\s*'
        r'(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\s*\}')
    vectors = []
    lines = iter(exp)
    for m in entry.finditer(body):
        passwd_hex = hex_concat(m.group(1))
        passwd_len = int(m.group(2))
        # crypto_pwhash_SALTBYTES 为 16：测试程序用 sodium_hex2bin 只取前 16 字节。
        salt_hex = m.group(3)[:32]
        outlen, opslimit, memlimit = (int(m.group(i)) for i in (4, 5, 6))
        line = next(lines)
        expected = None if line.startswith('[tv]') else line.strip()
        vectors.append({
            'password_hex': passwd_hex[:passwd_len * 2],
            'salt_hex': salt_hex,
            'outlen': outlen,
            'opslimit': opslimit,
            'memlimit_bytes': memlimit,
            'expected_hex': expected,
        })
    return vectors


def kdf(tar):
    src = read_member(tar, 'kdf.c')
    assert 'memcpy(context, "KDF test"' in src
    exp = read_member(tar, 'kdf.exp').splitlines()
    vectors = []
    # 第一段：子密钥 id 0..9，长度 64（crypto_kdf_BYTES_MAX）。
    for i in range(10):
        vectors.append({'subkey_id': i, 'length': 64, 'expected_hex': exp[i]})
    # 第二段：长度 i、子密钥 id i，i = 0..65；不合法的长度输出 Failure。
    for i in range(66):
        line = exp[10 + i]
        if not line.startswith('Failure'):
            vectors.append({'subkey_id': i, 'length': i, 'expected_hex': line})
    return {
        'context': 'KDF test',
        'master_key_hex': bytes(range(32)).hex(),
        'vectors': vectors,
    }


def generichash(tar, count=12):
    src = read_member(tar, 'generichash.c')
    table = src[src.index('} tests[] = {'):]
    table = table[:table.index('\n};')]
    triple = re.compile(r'\{\s*"([0-9a-f]*)",\s*"([0-9a-f]+)",\s*"([0-9a-f]+)"\s*\}')
    out = []
    for m in triple.finditer(table):
        out.append({'in_hex': m.group(1), 'key_hex': m.group(2), 'out_hex': m.group(3)})
    # 取前 count 条，外加最后一条（最长的输入）。
    return out[:count] + [out[-1]]


def xchacha(tar):
    src = read_member(tar, 'aead_xchacha20poly1305.c')
    exp = read_member(tar, 'aead_xchacha20poly1305.exp')
    assert '#define MLEN 114U' in src
    message = ("Ladies and Gentlemen of the class of '99: If I could offer you "
               'only one tip for the future, sunscreen would be it.')
    assert message.split(':')[0] in src
    first = src[src.index('firstkey['):]
    key = re.findall(r'0x([0-9a-f]{2})', first[:first.index('};')])
    nonce_src = src[src.index('nonce[crypto_aead_xchacha20poly1305_ietf_NPUBBYTES]'):]
    nonce = re.findall(r'0x([0-9a-f]{2})', nonce_src[:nonce_src.index('};')])
    ad_src = src[src.index('ad[ADLEN]'):]
    ad = re.findall(r'0x([0-9a-f]{2})', ad_src[:ad_src.index('};')])
    clen = 114 + 16
    ct = re.findall(r'0x([0-9a-f]{2})', exp)[:clen]
    assert len(key) == 32 and len(nonce) == 24 and len(ad) == 12 and len(ct) == clen
    return {
        'key_hex': ''.join(key),
        'nonce_hex': ''.join(nonce),
        'ad_hex': ''.join(ad),
        'plaintext_hex': message.encode().hex(),
        'ciphertext_hex': ''.join(ct),
    }


def main():
    path = find_archive()
    with tarfile.open(path) as tar:
        data = {
            '_source': os.path.basename(path) + ' test/default/*.c 与 *.exp（libsodium 官方测试套件）',
            'argon2id': argon2id(tar),
            'kdf': kdf(tar),
            'generichash_keyed': generichash(tar),
            'aead_xchacha20poly1305_ietf': xchacha(tar),
        }
    with open(OUT, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    print('已写入', OUT)


if __name__ == '__main__':
    main()
