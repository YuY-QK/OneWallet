# 备份格式的样本文件

| 文件 | 出处 | 用途 |
|---|---|---|
| `backup_v1_sample.owbak` | `test/backup/backup_golden_test.dart` 的 `encodeGoldenSample`：固定 salt（`01…10`）、nonce（`20…37`）、密码 `fake-backup-password`、Argon2id 8 KiB／迭代 1、固定时间与载荷（`test/support/backup_fixtures.dart` 的 `samplePayload(withCredentials: true)`） | **版本 1 的回归基准。不得修改、不得重新生成。** 测试断言：同样的输入编码出的字节与它完全相同；真实 codec 能解开它。编码结果与它不一致，说明格式被无意改动——要改格式就升版本号，并保证这个旧样本仍然能读 |
| `backup_v1_format_example.owbak` | 同上的固定 salt、nonce、密码与参数，载荷为 `backup_golden_test.dart` 的 `formatExamplePayload()`（一个账户、一组测试助记词） | `tools/backup_decrypt/FORMAT.md` 第 7 节完整十六进制示例的出处。同样**不得修改**；测试断言编码结果与它逐字节相同 |
| `backup_v1_python.owbak` | `generate_python_backup.py`：只依赖 PyNaCl 与标准库，照 `tools/backup_decrypt/FORMAT.md` 独立实现，不 import 本项目代码；salt、nonce 固定，重复运行输出逐字节相同。密码 `python-generated-password` | 反向互操作：证明格式说明本身足以实现。`test/backup/backup_python_sample_test.dart` 断言 Dart 端能解开它且内容正确 |

样本里的助记词是 BIP39 官方测试向量（`abandon … about`、`legal winner …`，附加密码 `TREZOR`），私钥与交易所凭据是明显的假值，不对应任何真实资产。
