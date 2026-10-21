# file_flow 构建说明

本地优先的批量文件整理工作台。桌面端 = **Tauri 外壳（Rust）** + **C# 后台**（`FileFlow.Host`，自包含发布）+ **静态前端**（`prototype/`，无构建步骤）。

与 pdf_reader 的区别：多一层原生外壳，Tauri 链接系统 WebView，所以两个平台的工具链不一样。

- **源码**：`https://code.zsrhkj.com/zsrhkj/FileFlow.git`（分支 `main`）
- **Workflow**：[`.github/workflows/file_flow.yml`](../../.github/workflows/file_flow.yml)
- **平台**：Windows x64、macOS arm64（.app / .dmg）、Linux x64（deb / rpm / tar.gz）
- **版本来源**：`src-tauri/tauri.conf.json` 的 `version`

## 产物路径

| 平台 | 路径 |
|------|------|
| macOS app | `src-tauri/target/release/bundle/macos/*.app` |
| macOS dmg | `src-tauri/target/release/bundle/dmg/*.dmg` |
| Linux deb | `src-tauri/target/release/bundle/deb/*.deb` |
| Linux rpm | `src-tauri/target/release/bundle/rpm/*.rpm` |
| Linux 便携 | `src-tauri/target/release/bundle/tar/*.tar.gz` |
| Windows | `artifacts/windows-installer/<版本>/FileFlow-Setup-<版本>.exe` |

## 所需 GitHub Secrets

在 **build_action 仓库** Settings → Secrets and variables → Actions 配置：

| Secret | 用途 |
|--------|------|
| `REPO_USER` | 代码仓库用户名（clone 私有产品仓库） |
| `REPO_TOKEN` | 代码仓库 access token（需能读 `zsrhkj/FileFlow`） |

> OSS 上传 + hub.zsrhkj.com 版本注册**不在 Action 内做**，改本地执行，见下方「本地发布」。

## 平台工具链

| 平台 | runner | CI 里额外装的东西 |
|------|--------|------------------|
| Linux | ubuntu-latest（24.04） | `libwebkit2gtk-4.1-dev`、`libgtk-3-dev`、`libayatana-appindicator3-dev`、`librsvg2-dev`、`libssl-dev`、`build-essential`、`rpm`；外加 .NET 8 / Node 22 / Rust stable |
| macOS | macos-latest | 系统自带 WebKit；外加 .NET 8 / Node 22 / Rust stable |
| Windows | windows-latest | WiX **5.0.2**（`dotnet tool install -g wix`）；外加 .NET 8 / Node 22 / Rust stable(MSVC) |

三个平台都要 `npx @tauri-apps/cli@2`（脚本自己 `npx --yes` 拉，不需要 package.json）。

**Windows 上的 .NET Framework 4.8**：安装界面 `packaging/windows/wix/Installer.UI` 是 net48 WPF。
如果编安装界面报缺少 `net48` 引用程序集，在 workflow 里加一步 `choco install netfx-4.8-devpack -y`。

> `macos-latest` 计费是 ubuntu 的 10 倍。首次验证先只跑 `linux`。

## 本地发布（OSS + hub 注册）

Action 只打包产出 artifact。OSS 上传与 hub.zsrhkj.com 版本注册在本地做：

```bash
# 前置：gh 已登录；本机有产品仓库 /Volumes/Private/LB/FileFlow
cd /Volumes/Private/LB/FileFlow

# 1) 拉最近一次成功的构建产物
RUN=$(gh run list --repo liub-a/build_action --workflow file_flow.yml \
        --status success -L 1 --json databaseId --jq '.[0].databaseId')
gh run download "$RUN" --repo liub-a/build_action -D /tmp/ff-artifacts

# 2) 逐个上传 + 登记（平台码必须和客户端 UpdateService.PlatformId() 一致）
bash scripts/upload-oss.sh mac-arm64   /tmp/ff-artifacts/file_flow-osx-arm64/…/*.dmg
bash scripts/upload-oss.sh win-x64     /tmp/ff-artifacts/file_flow-win-x64/…/FileFlow-Setup-*.exe
bash scripts/upload-oss.sh linux-x64-deb /tmp/ff-artifacts/file_flow-linux-x64/…/*.deb
```

只上传不登记：加 `--skip-publish`；只打印不执行：先加 `--dry-run`。

## 手动触发

Actions → `build-file_flow` → Run workflow：

| 输入 | 说明 |
|------|------|
| `ref` | 产品仓库分支/标签，默认 `main` |
| `platforms` | `all` / `win` / `linux` / `mac` |
| `release` | 是否附到 GitHub Release（自动按版本号生成 tag `file_flow-v<版本>`） |

## 已知风险

- **没有代码签名**：Windows 出的是未签名包，用户安装时会撞 SmartScreen。正式发布需在
  `scripts/deploy.env` 里配 `SIGN_*` 凭据，macOS 需在 `tauri.conf.json` 里配
  `bundle.macOS.signingIdentity` 与公证凭据。
- **产品仓库尚无 Windows 品牌安装包脚本**：`scripts/windows/build-installer.bat` 与
  `packaging/windows/wix/` 待补。在补齐前 Windows 只能出 `tauri build` 的裸 exe。
- **平台码三处必须一致**：OSS 上传、hub 登记、客户端检查更新用的是同一个平台码
  （`mac-arm64` / `win-x64` / `linux-x64-deb` 等）。不一致的表现是「传上去了但客户端永远检测不到更新」。
