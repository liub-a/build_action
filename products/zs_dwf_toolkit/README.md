# zs_dwf_toolkit 构建说明

DWF/DWFx 编辑与预览库（.NET 8 托管库 + C++ 原生渲染器）。与其它产品不同，这里**没有安装包**，
最终产物是一个 NuGet 包 `Zs.DWFToolkit`：

```
lib/net8.0/Zs.DWFToolkit.dll
runtimes/<rid>/native/libzs_dwf_toolkit_native.{so,dylib,dll}
runtimes/<rid>/native/zs_dwf_worker[.exe]
```

- **源码**：`https://code.zsrhkj.com/zsrhkj/Zs.DWFToolkit.git`（分支 `master`）
- **Workflow**：[`.github/workflows/zs_dwf_toolkit.yml`](../../.github/workflows/zs_dwf_toolkit.yml)
- **平台**：linux-x64、linux-arm64、win-x64（原生库）；osx-arm64 用仓库里已提交的 prebuilt
- **版本来源**：`src/Zs.DWFToolkit/Zs.DWFToolkit.csproj` 的 `<Version>`

## 两个 job

| job | 做什么 |
|-----|--------|
| `native (<rid>)` | clone 源码 → `scripts/build-native-release.sh`（内部 `setup-oda-dwftoolkit.sh` + cmake + CTest）→ 把 `lib`/`worker` stage 到 `native-prebuilt/<rid>/` → 上传 artifact，名字就是 RID |
| `package` | 重新 clone → 下载全部 `native` artifact（按名字落到 `native-prebuilt/<rid>/`）→ `dotnet test` → `dotnet pack` → 校验包内 `runtimes/` 齐全 → 上传 `nuget` artifact / 可选 GitHub Release |

**为什么分开**：`dotnet pack` 只能在一个工作目录里做，而原生库要在各自平台（尤其老 glibc）上编译。
package job 在 ubuntu 上汇总，没参与本次构建的 RID 沿用仓库里已提交的 prebuilt。

## Linux 为什么在容器里编

manylinux2014（glibc 2.17）：glibc 向后兼容、向前不兼容，在 ubuntu-24.04（glibc 2.38）上编出来的 `.so`
在旧服务器上直接加载失败。不用 job 级 `container:`，因为 checkout 的 node20 需要 glibc 2.28——
checkout/解包在宿主跑，只有编译和 CTest 进容器。

## 所需 GitHub Secrets

在 **build_action 仓库** Settings → Secrets and variables → Actions 配置：

| Secret | 用途 |
|--------|------|
| `REPO_USER` | 代码仓库用户名（clone 私有源码） |
| `REPO_TOKEN` | 代码仓库 access token（需能读 `zsrhkj/Zs.DWFToolkit`） |

> 与其它产品共用同一对 `REPO_USER` / `REPO_TOKEN`。如果 token 是限单仓库的 deploy token，
> 需要给 `Zs.DWFToolkit` 也授权。

## 手动触发

Actions → `build-zs_dwf_toolkit` → Run workflow：

| 输入 | 说明 |
|------|------|
| `ref` | 产品仓库分支/标签，默认 `master` |
| `platforms` | `all` / `linux` / `win` |
| `release` | 是否把 `.nupkg` / `.snupkg` 附到 GitHub Release（tag 形如 `zs_dwf_toolkit-v<版本>`） |

**首次验证建议**：先 `platforms=linux`（依赖最少），跑通 checkout → 原生编译 → CTest → pack 之后再放开 `win`。

## 本地流程（触发 → 等待 → 下载）

产品仓库的 `scripts/ci-build.sh` 把三步串成一条命令：

```bash
cd /Volumes/Private/LB/Zs.DWFToolkit

bash scripts/ci-build.sh linux              # 只跑 Linux（含 arm64）
bash scripts/ci-build.sh all --release      # 全平台 + 附到 Release
bash scripts/ci-build.sh --no-wait          # 只触发
```

产物落在 `artifacts/ci/`（gitignored）：`nuget/*.nupkg` + 每个 RID 一个目录。
用 CI 产物刷新已提交的 prebuilt：

```bash
cp artifacts/ci/linux-x64/* native-prebuilt/linux-x64/
git add native-prebuilt && git commit -m "chore(native): refresh prebuilt"
```

发布到 nuget.org 不在 CI 内做（与其它产品的 OSS 上传一致，凭证只在本机）：

```bash
dotnet nuget push artifacts/ci/nuget/Zs.DWFToolkit-<版本>.nupkg \
  --api-key <key> --source https://api.nuget.org/v3/index.json
```

## 已知风险

| # | 现象 | 处理 |
|---|------|------|
| 1 | `gh workflow run` 报权限错误 | gh token 缺 `workflow` scope：`gh auth refresh -s workflow` |
| 2 | Linux 编译被 OOM kill | 每个 WhipTk TU 要数 GB 内存，脚本默认 `ZS_JOBS=2`；不要改成无上限的 `-j` |
| 3 | 包里缺某个 `runtimes/<rid>/native/` | package job 的 `Verify native payload` 会直接失败；检查 csproj 的 `Exists` 条件与 artifact 名是否等于 RID |
| 4 | Windows 构建失败 | 首次跑预期内；`cmake`/MSVC 由 runner 自备，必要时看 `zs_dwf_native_markup` 的 Windows 排查经验 |
| 5 | 只跑 `platforms=linux` 时包里仍有 win-x64 | 正常：那是仓库里已提交的 prebuilt，不是本次构建产物 |
