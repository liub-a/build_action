# invoice_renamer 构建说明

离线发票整理工具（PDF / OFD / 数电发票批量识别、重命名、归档）。
桌面端 = **Tauri 外壳（Rust）** + **C# 后台**（`InvoiceRenamer.Host`，自包含发布）+ **静态前端**（`prototype/v3`，无构建步骤）。

比 pdf_reader 多一层原生外壳，两个平台的前置工具链都不一样，见下方「平台工具链」。

- **源码**：`https://code.zsrhkj.com/zsrhkj/InvoiceRenamer.git`（分支 `master`）
- **Workflow**：[`.github/workflows/invoice_renamer.yml`](../../.github/workflows/invoice_renamer.yml)
- **平台**：Windows x64（WiX 品牌安装包）、Linux x64（deb / rpm / tar.gz）
- **版本来源**：`src-tauri/tauri.conf.json` 的 `version`（`src-tauri/Cargo.toml` 建议同步）

> **macOS 暂不对外发布**，所以 matrix 里没有 macos runner（顺带省下 10 倍计费分钟）。
> 要出 mac 包时加 `macos-latest` + `scripts/release-mac.sh`，产物是 `.app` / `.dmg`。

## 产物路径

| 平台 | 路径 |
|------|------|
| Linux deb | `src-tauri/target/release/bundle/deb/*.deb` |
| Linux rpm | `src-tauri/target/release/bundle/rpm/*.rpm` |
| Linux 便携 | `src-tauri/target/release/bundle/tar/*.tar.gz` |
| Windows | `artifacts/windows-installer/<版本>/InvoiceRenamer-Setup-<版本>.exe` |

## 所需 GitHub Secrets

在 **build_action 仓库** Settings → Secrets and variables → Actions 配置：

| Secret | 用途 |
|--------|------|
| `REPO_USER` | 代码仓库用户名（clone 私有产品仓库） |
| `REPO_TOKEN` | 代码仓库 access token（用通用的，需能读 `zsrhkj/InvoiceRenamer`） |

> OSS 上传 + hub.zsrhkj.com 版本注册**不在 Action 内做**（与 pdf_reader 一致），改本地执行，见下方「本地发布」。
> 因此本产品也不需要把 `OSS_KEY_*` / `APP_PUBLISH_KEY` 配进 GitHub Secrets。
> OCR 模型：必需的 v5 mobile（`ch_PP-OCRv5_rec_mobile.onnx` + 字典）已随源码进 Git，CI 不需要额外下载；
> 只在本地想换高精度 v6 模型时才跑产品仓库的 `scripts/fetch-ocr-models.sh`（该目录被 git 忽略）。

## 平台工具链

| 平台 | runner | CI 里额外装的东西 |
|------|--------|------------------|
| Linux | ubuntu-latest（24.04） | `libwebkit2gtk-4.1-dev`、`libgtk-3-dev`、`libayatana-appindicator3-dev`、`librsvg2-dev`、`libssl-dev`、`build-essential`、`rpm`（提供 rpmbuild）；外加 .NET 8 / Node 22 / Rust stable |
| Windows | windows-latest | WiX **5.0.2**（`dotnet tool install -g wix`）；外加 .NET 8 / Node 22 / Rust stable(MSVC) |

两个平台都还要 `npx @tauri-apps/cli@2`（脚本自己 `npx --yes` 拉，不需要 package.json）。

**Windows 上的 .NET Framework 4.8**：安装界面 `packaging/windows/wix/Installer.UI` 是 net48 WPF。
引用程序集由 NuGet 包提供，理论上不需要 Developer Pack；如果首次运行在编安装界面这步报缺少
`net48` 引用程序集，就在 workflow 里加一步 `choco install netfx-4.8-devpack -y`。

## 本地发布（OSS + hub 注册）

Action 只打包产出 artifact。OSS 上传与 hub.zsrhkj.com 版本注册在本地做：

```bash
# 前置：gh 已登录；本机有产品仓库 /Volumes/Private/LB/InvoiceRenamer
#       产品仓库的 scripts/deploy.env 已填好（不进 Git）
cd /Volumes/Private/LB/InvoiceRenamer

# 1) 拉最近一次成功的构建产物
RUN=$(gh run list --repo liub-a/build_action --workflow invoice_renamer.yml \
        --status success -L 1 --json databaseId --jq '.[0].databaseId')
gh run download "$RUN" --repo liub-a/build_action -D /tmp/ir-artifacts

# 2) 逐个上传 + 登记（平台码必须和客户端 UpdateService.PlatformId() 一致）
bash scripts/upload-oss.sh win-x64     /tmp/ir-artifacts/invoice_renamer-win-x64/…/InvoiceRenamer-Setup-3.0.0.exe
bash scripts/upload-oss.sh linux-x64-deb /tmp/ir-artifacts/invoice_renamer-linux-x64/…/*.deb
bash scripts/upload-oss.sh linux-x64-rpm /tmp/ir-artifacts/invoice_renamer-linux-x64/…/*.rpm
bash scripts/upload-oss.sh linux-x64-tar /tmp/ir-artifacts/invoice_renamer-linux-x64/…/*.tar.gz

# 只上传不登记：加 --skip-publish；只打印不执行：先加 --dry-run
```

可选的更新说明写在产品仓库 `scripts/release-notes.txt`，没有则用「- 日常优化」。

## 手动触发

Actions → `build-invoice_renamer` → Run workflow：

| 输入 | 说明 |
|------|------|
| `ref` | 产品仓库分支/标签，默认 `master` |
| `platforms` | `all` / `win` / `linux` |
| `release` | 是否附到 GitHub Release（自动按版本号生成 tag `invoice_renamer-v<版本>`） |

**首次验证建议**：先选 `platforms=linux`（依赖少、无签名环节），跑通 checkout → build → artifact 后再放开 `win`。

## 已知风险 / 首次接入记录

产品仓库里这两个脚本**最初都是在 macOS 上写的，从没在真实的 Windows / Linux 上跑过**。
接入过程连撞两个问题，都已修好并写进 [docs/接入指南.md](../../docs/接入指南.md) 当作实例：

| # | 现象 | 修复 |
|---|------|------|
| 1 | `NU1301: The local source '/Volumes/.../Zs.OfdLite/dist' doesn't exist` | 私有包内置到产品仓库 `nuget-local/`，`NuGet.config` 改相对路径 |
| 2 | `failed to bundle project: invalid name "发票整理助手"` | Linux 单独覆盖 `productName` 为 ASCII + 自定义 `desktopTemplate` 保留中文菜单名 |

| 平台 | 状态 |
|------|------|
| Linux | ✅ **CI 已跑通**（run 38848155722）。三个产物下载后逐项验过：deb 的 `Package: invoice-renamer` + 中文桌面项 + 正确的 WebKitGTK 依赖、rpm 的 `Name` 标签与装后脚本、tar.gz 的启动脚本权限与 `backend/` 结构。**但未在真实 Linux 上安装运行过** |
| Windows | ✅ **CI 一次通过**（run 38848805573）。预案的 net48 Developer Pack 和 WiX 5.x 都没用上。产物 66 MB，SHA256 三方一致，有效 PE32+ x86-64。**但从未在真机装过** |

> 两个平台都是"能构建"，不等于"能用" —— 装机验证还没做。

Windows 首次跑常见可能的坑：

- Windows 缺 net48 引用程序集 → `choco install netfx-4.8-devpack -y`（见上）。
- Windows 品牌包要求 `wix --version` 是 5.x，装了 6/7 会直接报错。
- Linux 若 `rpmbuild` 缺失，脚本会自己降级为只出 deb（CI 里已装 `rpm`）。
- WebView2 引导程序在 Windows job 里临时用 curl 下载（`go.microsoft.com`），CI 需要外网。
- **没有代码签名**：`scripts/deploy.env` 里的 `IR_SIGN_*` 全为空 → Windows 出的是未签名包，
  用户安装时会撞 SmartScreen。要正式发布得先配证书。
