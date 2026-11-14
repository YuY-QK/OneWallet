# 用电脑解开 OneWallet 备份文件

OneWallet 导出的 `.owbak` 文件只凭备份密码就能解开，不需要手机、也不需要 OneWallet 应用本身。这里的小工具 `owbak_decrypt.py` 能在任何装有 Python 的电脑上把它解开，取回其中的助记词和私钥。它完全不联网。

## 步骤

1. **准备一台电脑**，最好断开网络（拔网线、关 Wi-Fi）。电脑上需要 Python 3（macOS、Linux 一般自带；Windows 从 python.org 安装）。
2. **安装 PyNaCl**（工具唯一的依赖，它自带密码学库 libsodium）。
   - 电脑能联网时：`python3 -m pip install pynacl`
   - 电脑断网时：先在另一台联网的电脑上运行 `python3 -m pip download pynacl -d pynacl-offline`（两台电脑的系统与 Python 版本要相同），把 `pynacl-offline` 文件夹拷过来，再运行 `python3 -m pip install --no-index --find-links pynacl-offline pynacl`
3. **把备份文件和 `owbak_decrypt.py` 放在同一个文件夹**，在该文件夹打开终端。
4. **解密**：运行 `python3 owbak_decrypt.py 你的备份文件.owbak --mnemonics-only`，按提示输入备份密码（输入时屏幕上不显示）。屏幕上会逐条列出"名称：助记词"和私钥，可以照着抄写或导入其他钱包。
   - 去掉 `--mnemonics-only` 会显示全部内容（账户、地址、设置等，JSON 格式）。
   - 想存成文件：加 `--out 结果.json`。文件只有你自己能读；**用完立即删除**，不要放进云盘、邮件或回收站。
5. **用完后**：关闭终端窗口，删除电脑上的备份文件副本与输出文件。

## 常见提示

| 提示 | 原因与处理 |
|---|---|
| 密码不正确，或文件已损坏 | 两者无法区分。检查大小写、输入法（全角/半角）。确认密码无误时，说明文件不完整或被改动过，请换一份备份 |
| 这不是 OneWallet 备份文件 | 选错了文件，或文件在传输中损坏 |
| 版本比本工具新 | 备份来自更新版本的 OneWallet，请获取新版的本工具 |
| 内存不足 | 解密需要约 256 MB 内存来派生密钥，请换一台内存更大的电脑 |

不提供"在命令里直接写密码"的方式：那样密码会留在终端历史里，运行时也能被同一台电脑上的其他用户看到。

格式的完整说明见 `FORMAT.md`，可据此用任何编程语言另写解密程序。
