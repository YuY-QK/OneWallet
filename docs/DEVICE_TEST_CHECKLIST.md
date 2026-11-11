# 真机整体测试清单

> 开发期间不做逐任务的真机验证。每个任务把"只经过自动化测试、还没在真机上验证"的项目追加到这里，全部开发完成后由用户用真机整体测一遍。
> 测试通过的项目打勾并写日期；不通过的记下现象，开任务修复。
> 不要在本文件中写入真实助记词、私钥、API Key 或完整的个人地址。

## 使用方法

1. 在装有 Flutter 3.47.9 的电脑上连接手机，执行 `cd app && flutter run --release`（iOS 需要 Mac 与 Xcode）。
2. 按下面的分节逐项操作。
3. 最后做 `SECURITY_DESIGN_v1.0.md` 第 8 节的全部项目和 `PRD_v1.0.md` 第 11 节的全部验收标准。

## 0. 构建

- [ ] Android 能构建并启动（任务 M0-10）
- [ ] iOS 能构建并启动（任务 M0-10）
- [ ] 四个 Tab 可切换，浅色与深色显示正常

（各任务在下面追加自己的小节。）

## 1. EVM 链数据（任务 M1-06）

开发环境无法访问 Alchemy 官方文档，适配器是按记忆中的接口实现的，只经过了录制样本的自动化测试。

- [ ] 对照 Alchemy 官方文档核对 `docs/EXTERNAL_APIS.md` 的"Alchemy（EVM）"一节：六条链的主机名、Key 的传递方式、代币余额与元数据接口的参数和返回结构、免费档限频
- [ ] 确认 Alchemy 是否支持 BNB Chain 以及代币接口在该链是否可用；不支持时从 `EvmChainAdapter.alchemyHosts` 删除该条目
- [ ] 用自己的 Key 运行冒烟脚本：在 `packages/ow_chains` 目录执行 `OW_ALCHEMY_KEY=<Key> dart run tool/smoke_evm.dart <地址> [链id]`，六条链各试一次
- [ ] 脚本输出的余额与区块浏览器一致

## 2. 币种映射与价格（任务 M1-03、M1-04）

合约地址主要取自 Uniswap 维护的代币列表（第三方），没有逐个对照发行方文档；合约地址错了会把假币当真币估值。

- [ ] 复核 `packages/ow_pricing/SOURCES.md`：至少 USDT、USDC、DAI、WETH、WBTC 在各链的全部合约，对照发行方官方文档或区块浏览器的认证页
- [ ] 运行 `cd packages/ow_pricing && dart run tool/smoke_price.dart`，能打印 BTC、ETH、USDT 的价格
- [ ] 运行 `dart run tool/smoke_price.dart --catalog`，映射表中每个币种都能取到价格（重点看 POL、SNX、COMP）
- [ ] 对照 CoinGecko 官方文档复核 `docs/EXTERNAL_APIS.md` 的"CoinGecko（价格）"一节中标"未核对"的项
