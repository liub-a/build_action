# overlay_pdf 构建说明

.NET 8 / Avalonia 桌面应用（双层 PDF 工具）。源码在私有仓库，本仓库只做 CI 编排，构建逻辑全部在产品仓库 `scripts/`。

- **源码**：`https://code.zsrhkj.com/zsrhkj/OverlayPdfBatch.git`（Gitea 自己跑不了 Actions，所以放这里构建）
- **Workflow**：[`.github/workflows/overlay_pdf.yml`](../../.github/workflows/overlay_pdf.yml)
- **平台**：Windows、macOS、Linux
- **版本**：一套代码两个版本，`cn` 中国专版 / `global` 国际版，构建脚本读 `EDITION` 环境变量（Windows 走 `--global` 参数）
- **产物路径**：`build/publish/**`（见下）
- **版本来源**：`OverlayPdfApplication/OverlayPdfApplication/OverlayPdfApplication.csproj` 的 `<Version>`

## 产物

| 平台 | 构建入口 | 产物 |
|------|---------|------|
| Windows | `scripts/release-win-full.bat [--global] --skip-upload` | `build/publish/installer/OverlayPdf-Setup-<ver>.exe`（Burn bundle，内嵌 VC++ Runtime + MSI，用户只下这一个）<br>`build/publish/msi/OverlayPdf-<ver>-x64.msi`（企业/静默部署） |
| macOS | `scripts/build-mac.sh osx-arm64` | `build/publish/OverlayPdf-<ver>-osx-arm64.dmg` |
| Linux | `scripts/build-linux.sh linux-x64` | `build/publish/OverlayPdf-<ver>-linux-x64.tar.gz`、`OverlayPdf-<ver>-amd64.deb`（有 fpm 时还有 `.rpm`） |

> **Windows 没有 Velopack 产物**：`release-win.bat` 里的 `vpk pack` 已停用，`upload-oss.bat` 也只传
> Setup.exe + MSI —— 当前发版与自动更新都走这两个。要恢复 nupkg/RELEASES 得先跑
> `scripts/publish-velopack.sh win-x64`，并同步改本文件与 workflow 的 artifact glob。

> **两个版本的产物文件名相同**（都是 `OverlayPdf-Setup-<ver>.exe`），只靠 artifact 名区分（`overlay_pdf-<edition>-<rid>`）。
> 别把 cn 与 global 的产物混进同一个 `build/publish/`：`upload-oss.bat` 会用 `build/publish/EDITION.txt`
> 校验版本并拦下混装（`EDITION.txt` 只有 Windows 那条会写，Linux/mac 没有这道保护）。

## 所需 GitHub Secrets

在 **build_action 仓库** Settings → Secrets and variables → Actions 配置（**不是**在产品仓库配）：

| Secret | 用途 |
|--------|------|
| `REPO_USER` | Gitea 用户名（clone 私有产品仓库） |
| `REPO_TOKEN` | Gitea 访问令牌，**必须有 `zsrhkj/OverlayPdfBatch` 的读权限**（pdf_reader / invoice_renamer 用的是各自的仓库，本产品要单独确认） |

> OSS 上传 + hub.zsrhkj.com 版本注册**不在 Action 内做**（CI 上传慢，也不该放发布凭证）。
> Action 只产 artifact，开发机 `gh run download` 后跑产品自带的 `scripts/upload-oss*.{bat,sh}`。
> 因此 `OSS_KEY_ID` / `OSS_KEY_SECRET` 不需要配进 GitHub Secrets。

## 本地怎么用

```bash
cd /Volumes/Private/LB/ArchiveOverlayPdf
bash scripts/ci-build.sh linux --edition cn        # 首次验证/改 CI 时就跑这个
bash scripts/ci-build.sh all                       # 三个平台 × 两个版本（6 个 job，mac 是 10x 计费）
```

脚本会触发 workflow、等它跑完、把产物下到 `artifacts/ci/`（在 `.gitignore` 里），并打印上传命令。

## 已知风险与坑

| 风险 | 说明与对策 |
|------|-----------|
| **`REPO_TOKEN` 无本仓库读权限** | 第一次就挂在 clone / 403。换 token 或给现有 token 加 `zsrhkj/OverlayPdfBatch` 读权限 |
| **非 Windows 发布要 `mono`** | csproj 的 `AfterTargets=Publish` 混淆目标在非 Windows 平台写死 `mono Obfuscar.Console.exe`。workflow 里 linux 装 `mono-devel`、mac 用 `brew install mono`；装不上只能临时加 `-p:SkipObfuscation=true`（等于发布未混淆包，别默认这么干） |
| **.NET FW 4.6.2 targeting pack** | WPF 安装界面（`installer/win/bundle-fancy/OverlayPdf.Installer.UI`）是 `net462`。windows-latest 一般带，缺了会报缺引用；最省事的修法是给该 csproj 加 `Microsoft.NETFramework.ReferenceAssemblies` 包（不依赖 runner 预装） |
| **WiX 必须 5.0.2** | 6+ 与现有 `.wxs` 不兼容且要接受付费协议。Bal/Util 扩展由 `release-win-full.bat` 自己 `wix extension add`（装进仓库内 `.wix/`） |
| **mac 的 `create-dmg`** | 装了才有背景图和「如何打开.txt」，缺了 `build-mac.sh` 退化 hdiutil，仍能出 dmg |
| **mac runner 10 倍计费** | 只验证改动时用 `platforms=linux`（1x、依赖最少） |
| **clone 体积 ≈143 MiB** | OCR 模型（PP-OCRv6 det/rec，共 163 MB）随仓库提供，`--depth 1` 也要下这么多；换来安装包自带模型、目标机器无需联网 |
| **Linux 的 `.rpm`** | 依赖 `fpm`（`gem install fpm`）。装不上时 `build-linux.sh` 跳过 rpm，只出 tar.gz + deb，不报错 |
| **Windows 首跑没有代码签名** | `sign-windows.bat` 在 `SIGN_PARAMS` 未设时静默跳过；CI 出来的 Setup.exe 是未签名版，正式发布如要签名得在开发机补签或把证书塞进 Secrets（不建议） |

## 首次跑的建议顺序

1. `platforms=linux, editions=cn` —— 依赖最少（无 WiX、无签名），先确认 clone / 还原 / 混淆这一串能通。
2. `platforms=win, editions=cn` —— 最容易踩 net462 targeting pack 与 WiX 版本。
3. 绿了再放开 `all`，把 mac 与 global 纳入。
