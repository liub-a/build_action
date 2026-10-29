# zssdk 构建说明

Go 版 PDF 核心库的 C ABI 共享库（`-buildmode=c-shared`）。源码在 私有源码仓库，本仓库只做 CI 编排，
构建逻辑全部在产品仓库 `scripts/`。

- **源码**：`https://code.zsrhkj.com/zsrhkj/zssdk.git`
- **Workflow**：[`.github/workflows/zssdk.yml`](../../.github/workflows/zssdk.yml)
- **平台 / 产物**：`zssdk-darwin-arm64.tar.gz`、`zssdk-linux-x64.tar.gz`、`zssdk-linux-arm64.tar.gz`
- **Artifact 路径**：`out/*.tar.gz`（checkout 根目录下）
- **版本来源**：`csdk/main.go` 的 `const version`

## 包内容

```
zssdk-<rid>/
├── lib/libzs-<rid>.<dylib|so>     # C ABI 共享库（sdk_release：未授权拒绝打开文档）
├── lib/libpdfium.<dylib|so>       # PDFium 原生库，必须与 libzs 同目录
├── include/libzs-<rid>.h          # cgo 生成的头文件
├── LICENSE                        # PDFium 的 BSD-3-Clause
└── SHA256SUMS
```

加载方式：库内带 `@loader_path`（macOS）/ `$ORIGIN`（Linux）rpath，宿主把两个库放同一目录即可，
不需要设置 `DYLD_LIBRARY_PATH` / `LD_LIBRARY_PATH`。

## 所需 GitHub Secrets

与本仓库其它产品共用（已配置则无需重复添加）：

| Secret | 用途 |
|--------|------|
| `REPO_USER` | 代码仓库用户名（clone 私有产品仓库） |
| `REPO_TOKEN` | 代码仓库 access token（只读即可） |

## 平台工具链

| 平台 | runner | 构建方式 |
|------|--------|----------|
| macOS arm64 | `macos-latest` | 原生编译，`MACOSX_DEPLOYMENT_TARGET=13.0` |
| Linux x64 | `ubuntu-latest` + `debian:bullseye` 容器 | 容器内下载 Go 1.26.0 与 PDFium，glibc 基线 2.31 |
| Linux arm64 | `ubuntu-24.04-arm` + `debian:bullseye` 容器 | 同上（原生 arm64，不走 QEMU） |

Linux 必须在容器里编：Go 的 cgo 产物会引用构建机 libc 的符号版本，直接在 ubuntu-latest（glibc 2.39）上
编出来的 `.so` 在老发行版上会报 `GLIBC_2.xx not found`。workflow 用 `check-glibc.sh --max 2.31` 断言。

## 本地触发

产品仓库里一条命令（触发 → 等待 → 下载到 `dist/ci`）：

```bash
bash scripts/ci-build.sh              # all
bash scripts/ci-build.sh linux        # 只跑两个 Linux
bash scripts/ci-build.sh mac --release
bash scripts/ci-build.sh --no-wait    # 只触发
```

## 已知限制

- **Windows 暂不支持**：PDFium 的 `.lib` 导入库命名与 cgo 链接参数对不上，需要单独适配。
- **loong64 无法出 c-shared**：上游 pdfium-binaries 不提供 loong64 原生库；该平台只能用纯 Go（WASM 后端）的 CLI。
- 构建仓库是 public，运行日志与 artifact 14 天内任何人可下载；发布完可 `--delete-run` 清掉。
- 离线证书无法吊销：签出去的授权只能等到期。
