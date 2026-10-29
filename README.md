# build_action — 多产品聚合构建仓库

统一用 GitHub Actions 构建多个产品。每个产品有**独立代码库**（多在 私有源码仓库），
本仓库只承载 workflow 与编排：CI 内 clone 产品源码 → 跑产品自带构建脚本 → 产出安装包 artifact。
**构建逻辑留在各产品仓库的 `scripts/`，本仓库不复制。**
OSS 上传与版本登记不在 CI 内做，改在本地执行（见 [docs/接入指南.md](docs/接入指南.md)）。

## 为什么需要这个仓库

私有代码托管不是 GitHub，没有 Actions runner，产品仓库自己跑不了 workflow。
所以由这个 GitHub 仓库集中托管 workflow，用 GitHub-hosted runner 构建，敏感信息走 GitHub Secrets。

## 目录结构

```
build_action/
├── .github/workflows/        # 各产品 workflow（文件名带产品前缀，GitHub 要求平铺）
│   ├── pdf_reader.yml
│   ├── invoice_renamer.yml
│   └── zs_dwf_native_markup.yml
├── products/                 # 各产品配置 + 说明（实现"按产品分目录"）
│   ├── pdf_reader/
│   │   ├── product.env       # 非敏感配置：仓库地址/分支/平台/脚本路径
│   │   └── README.md         # 该产品构建说明 + 所需 secrets
│   ├── invoice_renamer/
│   │   ├── product.env
│   │   └── README.md
│   └── zs_dwf_native_markup/
│       ├── product.env
│       └── README.md
├── docs/
│   └── 接入指南.md           # 新产品接入完整说明（推荐先读这份）
└── README.md
```

> GitHub 限制：能触发的 workflow 文件必须平铺在 `.github/workflows/`，子目录里的不会触发。
> 因此"分目录"靠 `products/<name>/` 实现，workflow 文件用产品前缀命名。

## 已接入产品

| 产品 | 技术栈 | 平台 | 说明 |
|------|--------|------|------|
| pdf_reader | .NET 8 / Avalonia | win / mac / linux | [products/pdf_reader](products/pdf_reader/README.md) |
| zssdk | Go（c-shared C ABI 库） | mac / linux | [products/zssdk](products/zssdk/README.md) |
| invoice_renamer | Tauri (Rust) + .NET 8 + 静态前端 | win / linux | [products/invoice_renamer](products/invoice_renamer/README.md) |
| zs_dwf_native_markup | Tauri (Rust) + .NET 8 + 静态前端 | win / linux（cn + intl 两版本） | [products/zs_dwf_native_markup](products/zs_dwf_native_markup/README.md) |
| zs_dwf_toolkit | .NET 8 库 + C++ 原生渲染器 | linux-x64 / linux-arm64 / win-x64 | [products/zs_dwf_toolkit](products/zs_dwf_toolkit/README.md) |

## 新增产品

**完整步骤见 [docs/接入指南.md](docs/接入指南.md)**（含 `product.env` 字段表、workflow 模板要点、
本地发布流程、常见坑，以及 pdf_reader / invoice_renamer 两个参考实现对照）。速览：

1. 建 `products/<name>/`，写 `product.env`（参考 pdf_reader）+ `README.md`（列所需 secrets、产物路径、已知风险）。
2. 建 `.github/workflows/<name>.yml`（拷 pdf_reader.yml 改：源码仓库地址、build 脚本路径、runner / 工具链；非 .NET 栈改对应 setup 步骤）。
3. 在仓库 Settings → Secrets 配置该产品所需密钥。
4. **首次跑先选 `platforms=linux`**（依赖少、无签名环节），跑通再放开 win / mac。

## 安全说明 ⚠️

1. **源码仓库凭据注入**（`https://code.zsrhkj.com`）：workflow 用 git credential helper 注入 token，
   避免内嵌进 remote URL（不进进程列表/日志）。建议用**只读 deploy token**（限单仓库）。
2. **Secrets 不打印**：全部用 `env:` 注入，禁 `echo`；GitHub 自动屏蔽 secret 输出。
3. **第三方 action**：用 major tag（`@v4` 等），可进一步钉 commit SHA。
4. 所有密钥仅在 build_action 仓库 Settings → Secrets 配置，**不写入任何文件**。
