# zs_pdf_format_converter 构建说明

智数归档通：PDF / 图片 ↔ PDF/A、PDF 降版本、PDF↔OFD、场景模板转换的桌面端工具。

桌面端 = **Tauri 外壳（Rust）** + **C# 后台**（`Zs.PdfFormatConverter.Host` → `pdf-format-host`，自包含发布）
+ **React 前端**（`src/Zs.PdfFormatConverter.Desktop/src`）。
技术栈与 invoice_renamer 同构。

- **源码**：`https://code.zsrhkj.com/zsrhkj/Zs.PdfFormatConverter.git`（分支 `main`）
- **Workflow**：[`.github/workflows/zs_pdf_format_converter.yml`](../../.github/workflows/zs_pdf_format_converter.yml)
- **平台**：Windows x64、Linux x64
- **版本来源**：`src/Zs.PdfFormatConverter.Desktop/src-tauri/tauri.conf.json` 的 `version`

> **macOS 不在 matrix 里**：macos runner 是 10 倍计费。
> 要出 mac 包时加 `macos-latest` + `bash scripts/release-mac.sh`。

> **前置条件**：Gitea 上必须先有 `Zs.PdfFormatConverter` 仓库，且默认分支是 `main`。
> 仓库不存在时 workflow 的 clone 步骤就会失败（`repository not found`）。
> 本产品的默认分支用 `main`，与 invoice_renamer 的 `master` 不同 —— 触发时不传 `ref` 就用 `main`。

## 产物路径

| 平台 | 路径 |
|------|------|
| Linux deb | `src/Zs.PdfFormatConverter.Desktop/src-tauri/target/release/bundle/deb/*.deb` |
| Linux rpm | `…/bundle/rpm/*.rpm` |
| Linux 便携 | `…/bundle/tar/*.tar.gz` |
| Windows 品牌包 | `artifacts/windows-installer/<版本>/ZsPdfFormatConverter-Setup-<版本>.exe` |
| Windows NSIS | `…/bundle/nsis/*-setup.exe`、`…/bundle/msi/*.msi` |

## 所需 GitHub Secrets

在 **build_action 仓库** Settings → Secrets and variables → Actions 配置：

| Secret | 用途 |
|--------|------|
| `REPO_USER` | 代码仓库用户名（clone 私有产品仓库） |
| `REPO_TOKEN` | 代码仓库 access token（需能读 `zsrhkj/Zs.PdfFormatConverter`） |

> OSS 上传 + hub.zsrhkj.com 版本注册**不在 Action 内做**（与其它产品一致），改本地执行，见下。
> 所以本产品也不需要在 GitHub Secrets 里配 `OSS_KEY_*`。

## 平台工具链

| 平台 | runner | CI 里额外装的东西 |
|------|--------|------------------|
| Linux | ubuntu-latest（24.04） | `libwebkit2gtk-4.1-dev`、`libgtk-3-dev`、`libayatana-appindicator3-dev`、`librsvg2-dev`、`libssl-dev`、`libsoup-3.0-dev`、`build-essential`、`curl`、`file`、`patchelf`、`rpm`（提供 rpmbuild）；外加 .NET 8 / Node 22 / Rust stable |
| Windows | windows-latest | WiX **5.0.2**（`dotnet tool install -g wix`）；外加 .NET 8 / Node 22 / Rust stable(MSVC) |

两个平台都还要 `npx @tauri-apps/cli@2`（脚本自己 `npx --yes` 拉，不需要 package.json）。

**Windows 上的 .NET Framework 4.8**：品牌安装包的界面 `packaging/windows/wix/Installer.UI` 是 net48 WPF。
引用程序集由 NuGet 包提供，理论上不需要 Developer Pack；首次跑若在编安装界面这一步报缺 `net48`
引用程序集，就在 workflow 里加一步 `choco install netfx-4.8-devpack -y`。

**CI 的 Windows runner 没有代码签名证书**：`scripts/deploy.env` 不在仓库里，`build-installer.bat`
读不到签名配置，会出**未签名**的安装包（用户装的时候会撞 SmartScreen）。要出签名包得把证书配进 secrets，
再在 workflow 里写进 `scripts/deploy.env`——目前没做。

## 本地发布（OSS + hub 注册）

Action 只打包产出 artifact。OSS 上传与 hub.zsrhkj.com 版本注册在本地做。
产品仓库的 `scripts/ci-build.sh` 把「触发 → 等 → 下载 → 上传 → 登记」串成一条命令，下面两种写法等价：

```bash
# 前置：gh 已登录；本机有产品仓库 /Volumes/Private/LB/zs_pdf_format_converter
#       产品仓库的 scripts/deploy.env 已填好（不进 Git）
cd /Volumes/Private/LB/zs_pdf_format_converter

# 一条命令走完：触发 CI → 等构建 → 下载产物 → 上传 OSS → 登记版本
bash scripts/ci-build.sh linux --upload
bash scripts/ci-build.sh win   --upload

# 只构建 + 下载、不发布（会打印出该执行的 upload-oss.sh 命令）：
bash scripts/ci-build.sh all

# 不用这个脚本时，手动等价于下面两步：
RUN=$(gh run list --repo liub-a/build_action --workflow zs_pdf_format_converter.yml \
        --status success -L 1 --json databaseId --jq '.[0].databaseId')
gh run download "$RUN" --repo liub-a/build_action -D artifacts/ci

# 逐个上传 + 登记（平台码必须和客户端 ReleaseCheckService.Platform() 用的一致）
bash scripts/upload-oss.sh linux-x64-deb artifacts/ci/…/bundle/deb/*.deb
bash scripts/upload-oss.sh linux-x64-rpm artifacts/ci/…/bundle/rpm/*.rpm
bash scripts/upload-oss.sh linux-x64-tar artifacts/ci/…/bundle/tar/*.tar.gz
bash scripts/upload-oss.sh win-x64 \
     artifacts/ci/…/windows-installer/<版本>/ZsPdfFormatConverter-Setup-<版本>.exe

# 只上传不登记：加 --skip-publish；只打印不执行：先加 --dry-run
```

## 手动触发

Actions → `build-zs_pdf_format_converter` → Run workflow：

| 输入 | 说明 |
|------|------|
| `ref` | 产品仓库分支/标签，默认 `main` |
| `platforms` | `all` / `win` / `linux` |
| `release` | 是否附到 GitHub Release（tag 形如 `zs_pdf_format_converter-v<版本>`） |

**首次验证建议**：先 `platforms=linux`（依赖少、无签名环节），跑通 checkout → build → artifact
之后再放开 `win`。

## 已知风险 / 首次接入的坑

| # | 现象 | 处理 |
|---|------|------|
| 1 | `NU1101: Unable to find package Zs.OfdLite.Core` | 私有包 `Zs.OfdLite.Core` / `Zs.OfdLite.Render` 不在 nuget.org 上。**已把当前版本的 `.nupkg`（47 KB + 16 KB）提交进产品仓库** `packages/local/`，产品仓库的 `nuget.config` 用 `<clear/>` + nuget.org + 相对路径 `packages/local` 指向它。升级版本时要同步更新那个目录并改 csproj 的 `PackageReference Version`，见产品仓库 `packages/local/README.md` |
| 2 | `invalid name "智数归档通"`（Linux 打 rpm 时） | Tauri 在 Linux 上一个 `productName` 同时当包名、`.desktop` 的 `Name` 和 `/usr/lib` 目录名，rpm 拒绝非 ASCII（deb 会「成功」但产出的包实际装不上）。**大概率是本产品 Linux CI 的第一个失败点** —— 需要像 zs_dwf_native_markup 那样拆出 ASCII 的包名配置 |
| 3 | Linux 缺 WebKitGTK 4.1 | runner 已装 `libwebkit2gtk-4.1-dev`；只带 4.0 的旧系统（UOS 20 / 麒麟 V10 早期）装不上也跑不了 |
| 4 | Windows 缺 net48 引用程序集 | 见上，必要时加 `choco install netfx-4.8-devpack -y` |
| 5 | Windows `wix --version` 不是 5.x | 产品脚本会直接报错退出；workflow 里已固定装 `5.0.2` |
| 6 | Windows 品牌安装包内嵌 VC++ 运行库 | `VC_redist.x64.exe`（18 MB）已提交进产品仓库 `packaging/windows/prerequisites/`，CI clone 下来就有，**不需要额外步骤、也不需要联网**。注意：**当前整包实测并不依赖它**（Tauri 外壳静态 CRT、.NET 8 只依赖系统自带 UCRT、pdfium/SkiaSharp 无 CRT 导入），带它是为了 Win7/8 补 UCRT、与家族产品一致、将来引入原生依赖时兜底。产品仓库还有一个 `ImportCheck` 工具在打包时扫导入表，出现真正的 VC++ 运行库依赖就构建失败 |
| 7 | Windows 品牌安装包内嵌 WebView2 引导程序 | `MicrosoftEdgeWebview2Setup.exe`（1.8 MB）同样提交进仓库，打包时校验 SHA-256 和微软签名。它是**在线引导程序**，装机时目标机器要联网 |

| 平台 | 状态 |
|------|------|
| Linux | ⏳ **尚未跑过 CI**。大概率先卡在上面的风险 2（非 ASCII 包名） |
| Windows | ⏳ **尚未跑过 CI**。产品仓库的 `scripts/windows/build-installer.bat` 从未在 Windows 上运行过，失败是预期内的，按上表排查 |
