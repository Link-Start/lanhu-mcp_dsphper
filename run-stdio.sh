#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -x "./venv/bin/lanhu-mcp" ]; then
    exec ./venv/bin/lanhu-mcp --transport stdio
fi

echo "Lanhu MCP 尚未安装。请先在项目目录运行：bash easy-install.sh" >&2
exit 1
