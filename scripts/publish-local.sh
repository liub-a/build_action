#!/usr/bin/env bash
# 本地发布：从 GitHub Actions 下载 pdf_reader 构建产物，放进产品目录，
# 再调用产品自带 scripts/upload-oss.sh 做 OSS 上传 + hub.zsrhkj.com 版本注册。
#
# 背景：Action 内传 OSS 太慢，故 Action 只打包产出 artifact，上传/注册改本地做。
#
# 前置：
#   - gh 已登录 (gh auth login)
#   - 本机有产品仓库 (默认 /Volumes/Private/LB/pdf_reader)
#   - 设置 OSS 凭证：export OSS_KEY_ID=...  export OSS_KEY_SECRET=...
#
# 用法：
#   bash scripts/publish-local.sh                  # 用最近一次成功 run
#   bash scripts/publish-local.sh <RUN_ID>         # 指定 run
#   bash scripts/publish-local.sh <RUN_ID> --dry-run   # 只下载+暂存，不真正上传
#
set -euo pipefail

REPO="liub-a/build_action"
WORKFLOW="pdf_reader.yml"
PRODUCT_DIR="${PRODUCT_DIR:-/Volumes/Private/LB/pdf_reader}"

RUN_ID=""
PASSTHRU=()
for a in "$@"; do
  case "$a" in
    --dry-run|-n|--skip-pub) PASSTHRU+=("$a") ;;
    [0-9]*) RUN_ID="$a" ;;
  esac
done

# 默认取最近一次成功的 run
if [[ -z "$RUN_ID" ]]; then
  RUN_ID=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" \
    --status success -L 1 --json databaseId --jq '.[0].databaseId')
  [[ -z "$RUN_ID" ]] && { echo "❌ 找不到成功的 run"; exit 1; }
fi
echo "==> 使用 run: $RUN_ID"

PUB_DIR="$PRODUCT_DIR/build/publish"
mkdir -p "$PUB_DIR"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> 下载 artifacts -> $TMP"
gh run download "$RUN_ID" --repo "$REPO" -D "$TMP"

echo "==> 暂存产物到 $PUB_DIR"
# artifact 内保留 build/publish 目录树，扁平拷贝所有安装包
found=0
while IFS= read -r -d '' f; do
  cp -f "$f" "$PUB_DIR/"
  echo "  + $(basename "$f")"
  found=$((found+1))
done < <(find "$TMP" -type f \( -name '*.dmg' -o -name '*.deb' -o -name '*.rpm' -o -name '*.tar.gz' -o -name '*.exe' \) -print0)
[[ "$found" -eq 0 ]] && { echo "❌ 未找到任何安装包产物"; exit 1; }
echo "==> 共 $found 个产物"

echo "==> 调用产品 upload-oss.sh (OSS 上传 + hub 注册)"
cd "$PRODUCT_DIR"
bash scripts/upload-oss.sh "${PASSTHRU[@]}"
echo "==> 完成"
