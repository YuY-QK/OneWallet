# 冒烟测试脚本

需要真实网络和真实 Key 的手动测试放在这里，由用户在自己的机器上运行。

- Key 一律从环境变量读取，例如 `OW_ALCHEMY_KEY`、`OW_BINANCE_KEY`、`OW_BINANCE_SECRET`。
- 脚本不得把 Key 写入文件或打印出来。
- 这些脚本不在 CI 中运行。
