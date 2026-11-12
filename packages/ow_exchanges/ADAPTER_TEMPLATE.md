# 照 Binance 新增一家交易所（OKX、Bybit、Bitget）

1. **先读该家官方文档，再写 `docs/EXTERNAL_APIS.md` 的一节**（照「Binance」一节的结构）。读不到的项如实写「未能核对」。
2. 新建目录 `lib/src/<name>/`：
   - `<name>_paths.dart` <- `binance/binance_paths.dart`：路径常量类 + `<name>ReadOnlyPaths` 白名单集合。
   - `<name>_adapter.dart` <- `binance/binance_adapter.dart`：实现 `ExchangeAdapter`；静态 `notIncluded`；构造参数 `clock`、`clientBuilder`、`rateLimiter`、`onLog`；`verify` / `fetchHoldings`（每个子账户一个步骤，任一失败整体失败）/ `fetchDepositAddresses`。
3. 在 `lib/ow_exchanges.dart` 导出；在 `tool/smoke_exchange.dart` 的 `switch` 加一支；`tools/smoke/README.md`、`docs/DEVICE_TEST_CHECKLIST.md` 第 6 节对应小标题补内容。
4. 公共层已备好，**不要重写**：`common/signing.dart`（该家的待签名串、请求头名常量、签名函数已在其中，可直接用，核对官方文档后再用）、`common/error_mapping.dart`（该家的错误码表）、`common/response_judges.dart`（`judgeOkx` / `judgeBybit` / `judgeBitget`：把响应判定为业务数据或 `Failure`）、`ExchangeClient`（限速 + 时间偏差校正重试一次）、`ClockSync`、`HoldingsAccumulator`（求和、丢零、大写符号）、`parseAmount` / `amountOrZero`（保留精度）。
5. **各家不同、必须对照官方文档确认**：待签名串的拼接与时间戳格式（毫秒 / ISO 8601 / 秒）；签名编码（十六进制 / Base64）；请求头名；Passphrase；GET 参数是否算进路径；业务错误码表（时间偏差、Key 无效、IP 白名单、限频、过期、维护）与「账户未开通」码；时间接口；各子账户的接口与字段（总量 = 可用 + 冻结）；统一账户模式下账户类型的对应关系；权限查询接口的字段；充值地址接口能否只读批量查；限频数值（取一半）。
6. **可能因 Key 权限读不到的子账户（合约、杠杆等）：先尝试，再按结果降级**。不要根据权限接口的开关事先跳过；基础账户（现货）成功后，这些子账户若返回鉴权类失败（`UnauthorizedFailure`）则视为空，产品名记入适配器的 `lastSkipped`（`fetchHoldings` 开头重置，类文档说明供 P08 显示"未包含"）；限频、网络、5xx、时间偏差等其他失败仍使整体失败。参见 `BinanceAdapter` 的 `optional(...)`。
7. 每个请求由 `CallBuilder(timestampMs)` 构造：时间戳、待签名串、请求头都在回调里生成（重试时用校正后的时间戳重新调用）。Key、Passphrase 用 `headerValue()` 在构造请求那一刻读取，不缓存。
8. 把该家的 Key 头加入 `OwHttpConfig.extraSensitiveNames`（已有 `exchangeSensitiveHeaderNames`）。限速器按官方数值的一半设默认值。
9. **测试**（照 `test/binance/binance_adapter_test.dart`，用 `test/support/fake_adapter.dart`，样本放 `test/fixtures/<name>/`，取自官方响应示例）：签名（至少一个官方示例；没有可复算示例就用待签名串对官方文本 + 固定输入回归，并注明非官方向量）；`verify` 三种权限 + Key 无效；每个子账户的解析与合并；零余额过滤；总量 = 可用 + 冻结；时间偏差校正后成功 / 仍失败；限频；某子账户失败导致整体失败；「未开通」视为空；Key 头与签名与实际发出的请求一致；`pathsOutsideAllowlist(fake.paths, <name>ReadOnlyPaths)` 为空；白名单路径不含 `order|trade|withdraw|transfer|convert`；开关为假但接口成功 → 计入；无权限错误且基础账户成功 → 子账户为空、`lastSkipped` 含名称、整体成功；该接口限频 → 整体失败。
10. 若 `tools/ci/check_deps.dart` 误拦只读字段名（如 `withdraw` 字样的返回字段），向 `readOnlyPathAllowlist` 加**带引号的精确条目**并注释用途与文档出处。
11. 最后：`tools/check.sh` 全部通过；用户用真实只读 Key 跑冒烟脚本，总资产与官方 app 相差不超过 1% 才算完成。
