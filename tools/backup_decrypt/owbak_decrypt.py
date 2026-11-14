#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OneWallet 加密备份文件（.owbak）的独立解密工具。

这是什么
    OneWallet 导出的 .owbak 文件只凭备份密码就能解开。本脚本不依赖 OneWallet
    应用、也不 import 本项目的任何代码，按公开的格式说明 FORMAT.md（同目录）
    解密并打印其中的内容：账户、地址、保险库中的助记词与私钥、设置等。
    即使 OneWallet 不再可用，也能用它找回助记词。

支持的格式
    容器版本 1，载荷版本 1（FORMAT.md 第 8 节）。遇到更高的版本会提示升级本工具。

依赖
    Python 3.8 或更新版本，加 PyNaCl（它自带 libsodium，提供 Argon2id 与
    XChaCha20-Poly1305-IETF）。除此之外只用 Python 标准库。本脚本完全不联网。

在断网的电脑上使用（推荐）
    1. 在一台联网的电脑上下载 PyNaCl 的离线安装包（选与断网电脑相同的系统与 Python 版本）：
           python3 -m pip download pynacl -d pynacl-offline
       把 pynacl-offline 目录与本脚本一起拷到 U 盘。
    2. 在断网的电脑上安装：
           python3 -m pip install --no-index --find-links pynacl-offline pynacl
    3. 解密（会提示输入备份密码，输入时不显示）：
           python3 owbak_decrypt.py 备份文件.owbak

用法
    python3 owbak_decrypt.py <文件>                    以缩进的 JSON 打印全部内容
    python3 owbak_decrypt.py <文件> --mnemonics-only   只逐条打印"名称：助记词"与私钥，方便抄写
    python3 owbak_decrypt.py <文件> --out <路径>       写入文件（仅本人可读），不打印到屏幕
    python3 owbak_decrypt.py <文件> --password-stdin   从标准输入读一行作为密码（供自动化测试）

    不提供把密码写在命令行参数里的方式：命令行参数会被记入 shell 历史，且在运行
    期间能被同一台电脑上的其他用户通过进程列表看到。

退出状态
    0 成功；1 密码不正确或文件已损坏；2 文件不是备份文件或格式不合法；
    3 版本过新；4 用法或读写错误；130 被中断。
"""
import argparse
import base64
import binascii
import getpass
import json
import os
import re
import struct
import sys
import unicodedata

try:
    import nacl.bindings
    import nacl.exceptions
    import nacl.pwhash.argon2id
except ImportError:
    sys.stderr.write('缺少 PyNaCl。请先安装：python3 -m pip install pynacl\n'
                     '（断网电脑的安装方法见本脚本开头的说明）\n')
    sys.exit(4)

MAGIC = b'OWBK'
CONTAINER_VERSION = 1
PAYLOAD_VERSION = 1
PAYLOAD_FORMAT = 'onewallet-backup'
FIXED_LENGTH = 9
MAX_HEADER_LENGTH = 4096
SALT_BYTES = 16
NONCE_BYTES = 24
TAG_BYTES = 16
KEY_BYTES = 32
# 与应用相同的 KDF 参数范围（FORMAT.md 第 3 节）：头部在认证之前就要使用，
# 限制取值防止被改成耗尽内存的参数。
MEM_KIB_RANGE = (8, 1024 * 1024)
ITERS_RANGE = (1, 32)

EXIT_WRONG_PASSWORD = 1
EXIT_CORRUPTED = 2
EXIT_VERSION = 3
EXIT_USAGE = 4

_TIMESTAMP = re.compile(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$')


class ToolError(Exception):
    """带退出状态的、可以直接显示给用户的错误。信息里不含任何文件内容或密码。"""

    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def corrupted(reason):
    return ToolError(EXIT_CORRUPTED, '这不是 OneWallet 备份文件，或文件已损坏（%s）。' % reason)


def _reject_duplicates(pairs):
    obj = {}
    for key, value in pairs:
        if key in obj:
            raise ValueError('duplicate key')
        obj[key] = value
    return obj


def parse_json(data):
    """严格解析 UTF-8 JSON：拒绝重复的键、NaN/Infinity，与应用一致。"""
    def bad_constant(_):
        raise ValueError('constant')
    text = data.decode('utf-8')  # 非 UTF-8 时抛出 UnicodeDecodeError（ValueError 的子类）
    return json.loads(text, object_pairs_hook=_reject_duplicates,
                      parse_constant=bad_constant)


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _strict_b64(value, length):
    if not isinstance(value, str):
        return None
    try:
        raw = base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError):
        return None
    if base64.b64encode(raw).decode('ascii') != value or len(raw) != length:
        return None
    return raw


def parse_container(data):
    """检查容器结构（FORMAT.md 第 2、3 节），返回 (头部, salt, nonce, aad, 密文)。"""
    if len(data) < FIXED_LENGTH or data[:4] != MAGIC:
        raise corrupted('魔数不对')
    version = data[4]
    if version == 0:
        raise corrupted('版本号不合法')
    if version > CONTAINER_VERSION:
        raise ToolError(EXIT_VERSION, '这个备份文件的格式版本（%d）比本工具新，请获取新版的解密工具。' % version)
    (length,) = struct.unpack('>I', data[5:9])
    end = FIXED_LENGTH + length
    if length < 2 or length > MAX_HEADER_LENGTH or len(data) < end + TAG_BYTES + 1:
        raise corrupted('长度不合法')
    try:
        header = parse_json(data[FIXED_LENGTH:end])
    except ValueError:
        raise corrupted('头部不是合法的 JSON') from None
    if not isinstance(header, dict):
        raise corrupted('头部不是 JSON 对象')
    kdf = header.get('kdf')
    if not isinstance(kdf, dict) or kdf.get('alg') != 'argon2id':
        raise corrupted('KDF 不合法')
    mem_kib, iters, parallelism = kdf.get('mem_kib'), kdf.get('iters'), kdf.get('parallelism')
    if not (_is_int(mem_kib) and _is_int(iters) and _is_int(parallelism)
            and MEM_KIB_RANGE[0] <= mem_kib <= MEM_KIB_RANGE[1]
            and ITERS_RANGE[0] <= iters <= ITERS_RANGE[1] and parallelism == 1):
        raise corrupted('KDF 参数超出允许范围')
    salt = _strict_b64(kdf.get('salt'), SALT_BYTES)
    nonce = _strict_b64(header.get('nonce'), NONCE_BYTES)
    created = header.get('created_at')
    if (salt is None or nonce is None or not isinstance(created, str)
            or not _TIMESTAMP.match(created) or not isinstance(header.get('app_version'), str)):
        raise corrupted('头部字段不合法')
    return header, salt, nonce, data[:end], data[end:]


def _password_candidates(password):
    """原样的 UTF-8 字节优先；含非 ASCII 字符时再试 NFC、NFD 两种规范化形式。"""
    seen = []
    for form in (None, 'NFC', 'NFD'):
        text = password if form is None else unicodedata.normalize(form, password)
        raw = text.encode('utf-8')
        if raw not in seen:
            seen.append(raw)
    return seen


def decrypt(data, password):
    """解密并返回载荷 JSON 的字节（FORMAT.md 第 4 节）。"""
    header, salt, nonce, aad, ciphertext = parse_container(data)
    if password == '':
        raise ToolError(EXIT_WRONG_PASSWORD, '密码不能为空。')
    kdf = header['kdf']
    for candidate in _password_candidates(password):
        key = nacl.pwhash.argon2id.kdf(
            KEY_BYTES, candidate, salt,
            opslimit=kdf['iters'], memlimit=kdf['mem_kib'] * 1024)
        try:
            return nacl.bindings.crypto_aead_xchacha20poly1305_ietf_decrypt(
                ciphertext, aad, nonce, key)
        except nacl.exceptions.CryptoError:
            continue
    raise ToolError(EXIT_WRONG_PASSWORD,
                    '密码不正确，或文件已损坏（两者无法区分）。请检查密码后重试；'
                    '若确认密码无误，说明文件已被改动或不完整，请换一份备份。')


def parse_payload(plaintext):
    """解析载荷 JSON 并检查 format 与 payload_version（FORMAT.md 第 5 节）。"""
    try:
        payload = parse_json(plaintext)
    except ValueError:
        raise corrupted('解密后的内容不是合法的 JSON') from None
    if not isinstance(payload, dict) or payload.get('format') != PAYLOAD_FORMAT:
        raise corrupted('解密后的内容不是 OneWallet 备份')
    version = payload.get('payload_version')
    if not _is_int(version) or version < 1:
        raise corrupted('载荷版本不合法')
    if version > PAYLOAD_VERSION:
        raise ToolError(EXIT_VERSION, '这个备份的内容版本（%d）比本工具新，请获取新版的解密工具。' % version)
    return payload


def mnemonic_lines(payload):
    """逐条列出助记词（及附加密码）与私钥，供抄写。"""
    lines = []
    for item in payload.get('vault_items') or []:
        if not isinstance(item, dict):
            continue
        name = item.get('name', '（未命名）')
        hex_note = '（十六进制）' if item.get('encoding') == 'hex' else ''
        if item.get('kind') == 'mnemonic':
            lines.append('%s：%s%s' % (name, item.get('mnemonic'), hex_note))
            if item.get('passphrase') is not None:
                lines.append('  附加密码（第 25 个词）：%s%s' % (item.get('passphrase'), hex_note))
        elif item.get('kind') == 'private_key':
            lines.append('%s（%s 私钥）：%s%s' % (name, item.get('family'), item.get('private_key'), hex_note))
        else:
            lines.append('%s：不认识的条目类型 %s，请查看完整的 JSON 输出' % (name, item.get('kind')))
    return lines


def render(payload, mnemonics_only):
    if mnemonics_only:
        lines = mnemonic_lines(payload)
        return '\n'.join(lines) + '\n' if lines else '（备份中没有助记词或私钥）\n'
    return json.dumps(payload, ensure_ascii=False, indent=2) + '\n'


def write_private(path, text):
    """新建文件并设为仅本人可读写；文件已存在时拒绝覆盖。"""
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_BINARY', 0)
    try:
        fd = os.open(path, flags, 0o600)
    except FileExistsError:
        raise ToolError(EXIT_USAGE, '输出文件已存在，为避免覆盖，请换一个路径。') from None
    except OSError:
        raise ToolError(EXIT_USAGE, '无法创建输出文件。') from None
    with os.fdopen(fd, 'wb') as f:
        f.write(text.encode('utf-8'))
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def read_password(from_stdin):
    if from_stdin:
        line = sys.stdin.buffer.readline()
        try:
            return line.rstrip(b'\r\n').decode('utf-8')
        except UnicodeDecodeError:
            raise ToolError(EXIT_USAGE, '标准输入中的密码不是 UTF-8 文本。') from None
    return getpass.getpass('备份密码：')


def run(argv):
    parser = argparse.ArgumentParser(
        description='解密 OneWallet 的加密备份文件（.owbak）。完全离线运行。')
    parser.add_argument('file', help='备份文件路径')
    parser.add_argument('--mnemonics-only', action='store_true',
                        help='只逐条打印"名称：助记词"与私钥')
    parser.add_argument('--out', metavar='路径', help='写入此文件（仅本人可读），不打印到屏幕')
    parser.add_argument('--password-stdin', action='store_true',
                        help='从标准输入读取一行作为密码（供自动化使用）')
    args = parser.parse_args(argv)
    try:
        with open(args.file, 'rb') as f:
            data = f.read()
    except OSError:
        raise ToolError(EXIT_USAGE, '无法读取文件：%s' % args.file) from None
    parse_container(data)  # 先检查结构，文件不对时不必输入密码
    password = read_password(args.password_stdin)
    payload = parse_payload(decrypt(data, password))
    text = render(payload, args.mnemonics_only)
    if args.out:
        write_private(args.out, text)
        sys.stderr.write('已写入 %s（仅本人可读）。其中含有助记词明文，用完请立即删除，'
                         '不要让它进入云盘、邮件或回收站。\n' % args.out)
    else:
        sys.stdout.write(text)
    return 0


def main():
    try:
        return run(sys.argv[1:])
    except ToolError as e:
        sys.stderr.write(e.message + '\n')
        return e.code
    except KeyboardInterrupt:
        sys.stderr.write('已中断。\n')
        return 130
    except MemoryError:
        sys.stderr.write('内存不足：这个备份需要较多内存来派生密钥，请在内存更大的电脑上重试。\n')
        return EXIT_USAGE
    except Exception as e:  # 兜底：不打印堆栈，避免带出内容
        sys.stderr.write('发生了意外错误（%s），未输出任何内容。\n' % type(e).__name__)
        return EXIT_USAGE


if __name__ == '__main__':
    sys.exit(main())
