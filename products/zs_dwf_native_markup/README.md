# zs_dwf_native_markup 构建说明

DWF / DWFx 图纸阅读器：打开图纸、渲染、图层显隐、测量、导出 PDF / 图片。

桌面端 = **Tauri 外壳（Rust）** + **C# 后台**（`Zs.DwfNativeMarkup.Host` → `zs-dwf-host`，自包含发布）
+ **静态前端**（`src/Zs.DwfNativeMarkup.Desktop/ui`，无构建步骤）。
技术栈与 invoice_renamer 同构，多出来的部分是**一套代码两个版本**（见下）。

- **源码**：`https://code.zsrhkj.com/zsrhkj/Zs.DwfNativeMarkup.git`（分支 `master`）
- **Workflow**：[`.github/workflows/zs_dwf_native_markup.yml`](../../.github/workflows/zs_dwf_native_markup.yml)
- **平台**：Windows x64、Linux x64
- **版本来源**：`src/Zs.DwfNativeMarkup.Desktop/src-tauri/tauri.conf.json` 的 `version`

> **macOS 不在 matrix 里**：macos runner 是 10 倍计费，而且 `Zs.DWFToolkit` 里只有 `osx-arm64` 的 native，
> 没有 `osx-x64` —— 也就是说现在只能出 Apple Silicon 包，Intel 包（门户上挂的 `mac-x64.dmg`）打出来也跑不了。
> 要出 mac 包时加 `macos-latest` + `bash scripts/release-mac.sh`。

## 两个版本：cn / intl

产品仓库用环境变量 `EDITION` 切版本（`scripts/edition.sh`），workflow 有对应的 `edition` 输入：

| | `cn` 中国专版（默认） | `intl` 国际版 |
|---|---|---|
| 产品名 | 智数 DWF 阅读器 | Zs DWF Reader |
| hub 应用码 | `ZsDwfReader` | `ZsDwfReaderIntl` |
| Linux 包名 | `zs-dwf-reader` | `zs-dwf-reader-intl` |
| Windows 安装包 | 产品自带 WiX 品牌安装包（中文界面） | Tauri 自带 NSIS（英文） |
| 安装上报 | 首次启动上报一次 | 不上报 |

**Windows 两个版本走的脚本不同**，因为品牌安装包的界面目前只有中文：

| 版本 | 脚本 | 产物 |
|---|---|---|
| `cn` | `scripts\windows\build-installer.bat` | `artifacts\windows-installer\<版本>\ZsDwfReader-Setup-<版本>.exe` |
| `intl` | `scripts\release-win.bat` | `…\bundle\nsis\*-setup.exe`（+ `.msi`） |

## 产物路径

| 平台 | 版本 | 路径 |
|------|------|------|
| Linux deb | 两版 | `src/Zs.DwfNativeMarkup.Desktop/src-tauri/target/release/bundle/deb/*.deb` |
| Linux rpm | 两版 | `…/bundle/rpm/*.rpm` |
| Linux 便携 | 两版 | `…/bundle/tar/*.tar.gz` |
| Windows 品牌包 | `cn` | `artifacts/windows-installer/<版本>/ZsDwfReader-Setup-<版本>.exe` |
| Windows NSIS | `intl` | `…/bundle/nsis/*-setup.exe`、`…/bundle/msi/*.msi` |

## 所需 GitHub Secrets

在 **build_action 仓库** Settings → Secrets and variables → Actions 配置：

| Secret | 用途 |
|--------|------|
| `REPO_USER` | 代码仓库用户名（clone 私有产品仓库） |
| `REPO_TOKEN` | 代码仓库 access token（需能读 `zsrhkj/Zs.DwfNativeMarkup`） |

> OSS 上传 + hub.zsrhkj.com 版本注册**不在 Action 内做**（与其它产品一致），改本地执行，见下。
> 所以本产品也不需要在 GitHub Secrets 里配 `OSS_KEY_*`。

## 平台工具链

| 平台 | runner | CI 里额外装的东西 |
|------|--------|------------------|
| Linux | ubuntu-latest（24.04） | `libwebkit2gtk-4.1-dev`、`libgtk-3-dev`、`libayatana-appindicator3-dev`、`librsvg2-dev`、`libssl-dev`、`libsoup-3.0-dev`、`build-essential`、`curl`、`file`、`patchelf`、`rpm`（提供 rpmbuild）；外加 .NET 8 / Node 22 / Rust stable |
| Windows | windows-latest | WiX **5.0.2**（`dotnet tool install -g wix`，仅 `cn` 需要）；外加 .NET 8 / Node 22 / Rust stable(MSVC) |

两个平台都还要 `npx @tauri-apps/cli@2`（脚本自己 `npx --yes` 拉，不需要 package.json）。

**Windows 上的 .NET Framework 4.8**：品牌安装包的界面 `packaging/windows/wix/Installer.UI` 是 net48 WPF。
引用程序集由 NuGet 包提供，理论上不需要 Developer Pack；首次跑若在编安装界面这一步报缺 `net48`
引用程序集，就在 workflow 里加一步 `choco install netfx-4.8-devpack -y`。

**CI 的 Windows runner 没有代码签名证书**：`scripts/deploy.env` 不在仓库里，`build-installer.bat`
读不到签名配置，会出**未签名**的安装包（用户装的时候会撞 SmartScreen）。要出签名包得把证书配进 secrets，
再在 workflow 里写进 `scripts/deploy.env`——目前没做。

## 本地发布（OSS + hub 注册）

Action 只打包产出 artifact。OSS 上传与 hub.zsrhkj.com 版本注册在本地做：

```bash
# 前置：gh 已登录；本机有产品仓库 /Volumes/Private/LB/Zs.DwfNativeMarkup
#       产品仓库的 scripts/deploy.env 已填好（不进 Git）
cd /Volumes/Private/LB/Zs.DwfNativeMarkup

# 1) 拉最近一次成功的构建产物
RUN=$(gh run list --repo liub-a/build_action --workflow zs_dwf_native_markup.yml \
        --status success -L 1 --json databaseId --jq '.[0].databaseId')
gh run download "$RUN" --repo liub-a/build_action -D /tmp/dwf-artifacts

# 2) 逐个上传 + 登记（平台码必须和客户端 UpdateService 用的一致）
bash scripts/upload-oss.sh linux-x64-deb /tmp/dwf-artifacts/…/bundle/deb/*.deb
bash scripts/upload-oss.sh linux-x64-rpm /tmp/dwf-artifacts/…/bundle/rpm/*.rpm
bash scripts/upload-oss.sh linux-x64-tar /tmp/dwf-artifacts/…/bundle/tar/*.tar.gz
bash scripts/upload-oss.sh win-x64 \
     /tmp/dwf-artifacts/…/windows-installer/<版本>/ZsDwfReader-Setup-<版本>.exe

# 只上传不登记：加 --skip-publish；只打印不执行：先加 --dry-run
```

**国际版要登记上，`deploy.env` 里的 `APP_CODE` 必须是 `ZsDwfReaderIntl`。**
`upload-oss.sh` 会拿它跟 `EDITION` 对应的应用码核对，不对就拒绝登记——这是防止两个版本的用户
被互相强制更新。这也是国际版目前最大的阻塞：`scripts/deploy.env` 只有一份、写的全是国内版的值，
国际版要么登记不上、要么把国内版的安装包覆盖掉。详见产品仓库 `portal/README.md`。

## 手动触发

Actions → `build-zs_dwf_native_markup` → Run workflow：

| 输入 | 说明 |
|------|------|
| `ref` | 产品仓库分支/标签，默认 `master` |
| `platforms` | `all` / `win` / `linux` |
| `edition` | `cn` / `intl`，默认 `cn` |
| `release` | 是否附到 GitHub Release（tag 形如 `zs_dwf_native_markup-cn-v<版本>`） |

**首次验证建议**：先 `platforms=linux` + `edition=intl`（依赖少、无签名环节、包名本来就是 ASCII），
跑通 checkout → build → artifact 之后再放开 `cn` 和 `win`。

## 已知风险 / 首次接入的坑

| # | 现象 | 处理 |
|---|------|------|
| 1 | `NU1101: Unable to find package Zs.DWFToolkit` | 私有包 `Zs.DWFToolkit` 只在开发机的 `packages/local/` 里，CI clone 下来是空的。已把当前版本 **28 MB 的 `.nupkg` 提交进产品仓库**（`.gitignore` 开了一行例外）。升级版本时要同步改那行例外并删掉旧包，见 `packages/local/README.md` |
| 2 | `invalid name "智数 DWF 阅读器"`（Linux 打 rpm 时） | Tauri 在 Linux 上一个 `productName` 同时当包名、`.desktop` 的 `Name` 和 `/usr/lib` 目录名，rpm 拒绝非 ASCII（deb 会「成功」但产出的包实际装不上）。已按版本拆开：`tauri.<版本>.linux.conf.json` 把包名覆盖成 ASCII，`packaging/linux/zs-dwf-reader{,-intl}.desktop.hbs` 保留中文 / 英文显示名 |
| 3 | Linux 缺 WebKitGTK 4.1 | runner 已装 `libwebkit2gtk-4.1-dev`；只带 4.0 的旧系统（UOS 20 / 麒麟 V10 早期）装不上也跑不了 |
| 4 | Windows 缺 net48 引用程序集 | 见上，必要时加 `choco install netfx-4.8-devpack -y` |
| 5 | Windows `wix --version` 不是 5.x | 产品脚本会直接报错退出；workflow 里已固定装 `5.0.2` |
| 6 | WebView2 引导程序要联网 | `build-installer.bat` 用 curl 从 `go.microsoft.com` 取，CI 需要外网。`release-win.bat`（intl）不需要 |

| 平台 | 状态 |
|------|------|
| Linux | ⏳ **尚未跑过 CI**。产品脚本在 macOS 上写的，从没在 Linux 上运行过 |
| Windows | ⏳ **尚未跑过 CI**。两个 .bat 同样从未在 Windows 上运行过 |

> 产品仓库 `scripts/README.md` 的「现状」一节记的是同一件事：Linux / Windows 的打包脚本都还没在
> 对应系统上真跑过。首次 CI 失败是预期内的，按上表排查。
