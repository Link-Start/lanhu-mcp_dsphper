#!/bin/bash
# 蓝湖 MCP 服务器快速启动脚本

set -e

# 国内用户默认使用国内镜像；已设置环境变量时尊重用户配置。
export PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
export PLAYWRIGHT_DOWNLOAD_HOST="${PLAYWRIGHT_DOWNLOAD_HOST:-https://cdn.npmmirror.com/binaries/playwright}"

echo "🎨 蓝湖 MCP 服务器 - 快速启动"
echo "=================================="
echo ""

# 检查 Python 版本。macOS 仍可能自带 Python 3.9，不能只检查命令是否存在。
PYTHON_BIN=""
for candidate in python3 python python3.13 python3.12 python3.11 python3.10; do
    if command -v "$candidate" >/dev/null 2>&1 \
        && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
        PYTHON_BIN=$(command -v "$candidate")
        break
    fi
done
if [ -z "$PYTHON_BIN" ]; then
    echo "❌ 错误：需要 Python 3.10 或更高版本"
    echo "Mac 可执行 brew install python；其他系统请访问 https://www.python.org/downloads/"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_BIN -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
echo "✅ Python 版本：$PYTHON_VERSION ($PYTHON_BIN)"

# 检查虚拟环境是否存在
if [ ! -d "venv" ]; then
    echo ""
    echo "📦 正在创建虚拟环境..."
    "$PYTHON_BIN" -m venv venv
    echo "✅ 虚拟环境创建完成"
fi

VENV_PYTHON="venv/bin/python"
if [ ! -x "$VENV_PYTHON" ] \
    || ! "$VENV_PYTHON" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then
    echo "❌ 现有 venv 不可用或 Python 版本低于 3.10"
    echo "请删除 venv 目录后重新运行本脚本。"
    exit 1
fi

# 安装依赖
echo ""
echo "📥 正在安装依赖..."
if ! "$VENV_PYTHON" -m pip install --timeout 60 --retries 5 -e .; then
    echo "❌ 项目依赖下载失败"
    echo "请检查网络或代理，然后重新运行本脚本。"
    echo "如需使用自定义 PyPI 镜像，可先设置 PIP_INDEX_URL。"
    exit 1
fi
"$VENV_PYTHON" -m pip check

# 安装 Playwright 浏览器
echo ""
echo "🌐 正在安装 Playwright 浏览器..."
if ! "$VENV_PYTHON" -m playwright install chromium; then
    echo "❌ Chromium 下载失败"
    echo "请检查网络后重试；也可通过 PLAYWRIGHT_DOWNLOAD_HOST 指定其他镜像。"
    exit 1
fi

# 检查 .env 是否存在
if [ ! -f ".env" ]; then
    echo ""
    echo "⚠️  未找到配置文件 .env"
    
    if [ -f "config.example.env" ]; then
        echo "📝 正在从模板创建 .env..."
        cp config.example.env .env
        echo "✅ .env 文件已创建"
        echo ""
        echo "⚠️  重要提示：请编辑 .env 文件并设置你的 LANHU_COOKIE"
        echo "   1. 在编辑器中打开 .env 文件"
        echo "   2. 将 'your_lanhu_cookie_here' 替换为你的实际 Cookie"
        echo "   3. 保存文件"
        echo ""
        read -p "配置完成后按 Enter 继续..."
    else
        echo "❌ 错误：未找到 config.example.env"
        exit 1
    fi
fi

# 检查并加载 .env 文件中的环境变量
echo ""
echo "🔧 正在加载配置..."

# 使用 export 导出环境变量，让子进程（Python）可以访问
set -a  # 自动导出所有变量
source .env
set +a  # 关闭自动导出

if [ -z "$LANHU_COOKIE" ] || [ "$LANHU_COOKIE" = "your_lanhu_cookie_here" ]; then
    echo ""
    echo "❌ 错误：LANHU_COOKIE 未配置"
    echo "请编辑 .env 文件并设置你的蓝湖 Cookie"
    echo ""
    echo "获取 Cookie 的方法："
    echo "1. 登录 https://lanhuapp.com"
    echo "2. 打开浏览器开发者工具（F12）"
    echo "3. 切换到 Network（网络）标签"
    echo "4. 刷新页面"
    echo "5. 点击任意请求"
    echo "6. 从请求头（Request Headers）中复制 'Cookie'"
    exit 1
fi

echo "✅ 配置加载完成"
echo "   Cookie 长度: ${#LANHU_COOKIE} 字符"

# 创建数据目录
mkdir -p data logs

echo ""
echo "🚀 正在启动蓝湖 MCP 服务器..."
echo "=================================="
echo ""
bash scripts/print-mcp-config.sh
echo ""
echo "按 Ctrl+C 停止服务器"
echo ""

# 运行服务器
./venv/bin/lanhu-mcp --transport http

