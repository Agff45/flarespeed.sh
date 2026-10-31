#!/usr/bin/env bash
set -euo pipefail

# ---------- 配置 ----------
SRC_DIR="/usr/local/src/flarespeed"
REPO_URL="https://github.com/cempack/flarespeed.git"
INSTALL_BIN="/usr/local/bin/flarespeed"

# ---------- 颜色 ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ---------- 检查 root ----------
if [[ $EUID -ne 0 ]]; then
  error "请使用 root 运行：sudo bash $0"
fi

# ---------- 1. 安装编译依赖 ----------
info "安装编译依赖 (build-essential, pkg-config, libcurl4-openssl-dev, git)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential \
  pkg-config \
  libcurl4-openssl-dev \
  git \
  ca-certificates

# 验证 pkg-config 能找到 libcurl
if ! pkg-config --exists libcurl; then
  error "pkg-config 无法找到 libcurl，请检查 libcurl4-openssl-dev 是否安装成功"
fi
info "libcurl 编译参数: $(pkg-config --cflags --libs libcurl)"

# ---------- 2. 获取源码 ----------
if [[ -d "$SRC_DIR/.git" ]]; then
  info "检测到已有源码，更新到最新版本..."
  git -C "$SRC_DIR" fetch --all --prune
  git -C "$SRC_DIR" reset --hard origin/HEAD
else
  info "克隆源码到 $SRC_DIR ..."
  mkdir -p "$(dirname "$SRC_DIR")"
  rm -rf "$SRC_DIR"
  git clone --depth=1 "$REPO_URL" "$SRC_DIR"
fi

cd "$SRC_DIR"

# ---------- 3. 清理历史构建产物 ----------
info "清理历史构建产物..."
# 如果存在同名目录导致链接失败，先删除
if [[ -d "$SRC_DIR/flarespeed" ]]; then
  warn "发现冲突目录 $SRC_DIR/flarespeed，删除它"
  rm -rf "$SRC_DIR/flarespeed"
fi
# 尽量用 make clean，失败也不影响
make clean 2>/dev/null || true
# 手动清理残留的 .o
find "$SRC_DIR" -name '*.o' -delete

# ---------- 4. 编译 ----------
info "开始编译..."
make -j"$(nproc)"

if [[ ! -x "$SRC_DIR/flarespeed" ]]; then
  error "编译失败：未生成可执行文件 $SRC_DIR/flarespeed"
fi

# ---------- 5. 安装 ----------
info "安装到 $INSTALL_BIN ..."
install -m 0755 "$SRC_DIR/flarespeed" "$INSTALL_BIN"

# ---------- 6. 验证 ----------
info "验证安装："
"$INSTALL_BIN" -version 2>/dev/null || "$INSTALL_BIN" --version 2>/dev/null || true
echo
info "安装完成 ✅"
info "可执行文件位置: $INSTALL_BIN"
info "测试运行: flarespeed -json"
