# pdf_reader 构建说明

.NET 8 / Avalonia 桌面应用。源码在 私有源码仓库，本仓库只做 CI 编排，构建逻辑全部在产品仓库 `scripts/`。

- **源码**：`https://code.zsrhkj.com/zsrhkj/pdf-reader.git`
- **Workflow**：[`.github/workflows/pdf_reader.yml`](../../.github/workflows/pdf_reader.yml)
- **平台**：Windows (Setup.exe / WiX)、macOS (.dmg)、Linux (.tar.gz/.deb/.rpm)
- **产物路径**：`build/publish/**`
- **版本来源**：`src/PdfReader.App/PdfReader.App.csproj`（产品脚本自行解析）

## 所需 GitHub Secrets

在 **build_action 仓库** Settings → Secrets and variables → Actions 配置：

| Secret | 用途 |
|--------|------|
| `REPO_USER` | 代码仓库用户名（clone 私有产品仓库） |
| `REPO_TOKEN` | 代码仓库 access token 或密码（建议用只读 deploy token，仅限 pdf-reader 仓库） |
| `OSS_KEY_ID` | 阿里云 OSS Access Key ID（`upload-oss.sh`） |
| `OSS_KEY_SECRET` | 阿里云 OSS Access Key Secret |

> `APP_PUBLISH_KEY` 当前硬编码在产品 `scripts/upload-oss.sh`（hub.zsrhkj.com 注册用，非高敏），本仓库不处理。
> 私有 NuGet 包 `china-esign` 已 vendored 在产品仓库 `packages/`，无需额外 secret。

### 如何取得 `REPO_TOKEN`

**方式 A — Personal Access Token（推荐）**

1. 登录代码托管平台 `https://code.zsrhkj.com`
2. 右上头像 → **Settings（设置）**
3. 左侧 **Applications（应用）** 标签
4. **Generate New Token（生成新令牌）** → 填名字（如 `github-ci`）→ Generate
5. ⚠️ **token 只显示一次**，立刻复制
6. 填到 GitHub Secret `REPO_TOKEN`；`REPO_USER` 填 代码仓库用户名

> clone 时 token 当密码用：`https://<user>:<token>@code.zsrhkj.com/...`

**方式 B — 账号密码（老版代码托管 无 Applications 标签时）**

`REPO_USER`=用户名，`REPO_TOKEN`=登录密码（安全性差，不推荐）。

**更安全做法**：建只读专用账号，仅授予 `zsrhkj/pdf-reader` 仓库读权限，再用它生成 token。即使泄露也只能读单仓库。

## 手动触发

Actions → `build-pdf_reader` → Run workflow：

| 输入 | 说明 |
|------|------|
| `ref` | 产品仓库分支/标签，默认 `main` |
| `platforms` | `all` / `win` / `mac` / `linux` |
| `upload_oss` | 是否上传阿里云 OSS |
| `release` | 是否附到 GitHub Release |

**首次验证建议**：先选 `platforms=linux`（最快、无签名），跑通 checkout → build → artifact 后再放开 mac/win。

## 平台工具链

| 平台 | runner | 额外工具 |
|------|--------|----------|
| Linux | ubuntu-latest | `dpkg`（CI 装）；`fpm` 可选（rpm，缺失时脚本回退） |
| macOS | macos-latest | `create-dmg` 可选（回退 hdiutil）；Python3 自带 |
| Windows | windows-latest | WiX 5.0.2（CI `dotnet tool install`） |
