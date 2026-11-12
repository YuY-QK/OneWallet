# 页面截图

这些图由 `app/test/screenshots/screenshots_test.dart` 渲染生成，使用的是示例数据（虚构的账户名、公开或明显的占位地址、示意价格），不是真实资产。

图片是测试的 golden 文件的副本，便于没有手机的人直接查看界面。

## 重新生成

在仓库根目录执行：

```bash
cd app && flutter test --update-goldens --run-skipped -t screenshots test/screenshots/
```

然后把 `app/test/screenshots/goldens/*.png` 复制到本目录：

```bash
cp app/test/screenshots/goldens/*.png docs/screenshots/
```

截图测试带有 `screenshots` 标签，并在 `app/dart_test.yaml` 中默认跳过，所以普通的 `flutter test` 和 `tools/check.sh` 不会运行它们。

注意：不同机器的字形渲染可能有细微差异；中文字体取决于本机是否装有中文字体（参见下文）。

## 文件对应的页面

| 文件 | 页面 | 尺寸 |
|---|---|---|
| `overview_light.png` / `overview_dark.png` | P02 总览（有数据，按币种） | 390×844，像素比 2 |
| `overview_by_account_light.png` / `overview_by_account_dark.png` | P02 总览，切换到"按账户" | 390×844，像素比 2 |
| `overview_empty_light.png` / `overview_empty_dark.png` | P02 总览（没有账户） | 390×844，像素比 2 |
| `accounts_light.png` / `accounts_dark.png` | P03 账户列表 | 390×844，像素比 2 |
| `wallet_detail_assets_light.png` / `wallet_detail_assets_dark.png` | P07 钱包详情，"资产"分段 | 390×844，像素比 2 |
| `wallet_detail_addresses_light.png` / `wallet_detail_addresses_dark.png` | P07 钱包详情，"地址"分段 | 390×844，像素比 2 |
| `add_account_light.png` / `add_account_dark.png` | P04 添加账户（三个选项） | 390×844，像素比 2 |
| `add_wallet_light.png` / `add_wallet_dark.png` | P05 添加钱包账户（输入 EVM 地址，显示六条链） | 390×844，像素比 2 |
| `data_sources_light.png` / `data_sources_dark.png` | P20 数据源设置 | 390×844，像素比 2 |
| `settings_light.png` / `settings_dark.png` | P18 设置首页 | 390×844，像素比 2 |
| `accounts_wide_light.png` | P03 账户列表与 P07 钱包详情并排（仅浅色） | 1280×900，像素比 1 |

## 字体

- 西文与数字：IBM Plex Sans / IBM Plex Mono（随应用打包的字体）。
- 中文：测试会加载本机的中文字体文件（在 Linux 上找到的是 WenQuanYi Zen Hei），并注册为 `PingFang SC`。如果机器上没有任何候选中文字体，中文会显示为方块。
- 图标：从 Flutter SDK 缓存中加载 Material 图标字体。
