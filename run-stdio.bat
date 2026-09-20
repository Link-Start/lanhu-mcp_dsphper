@echo off
cd /d "%~dp0"
if not exist ".\venv\Scripts\lanhu-mcp.exe" (
    echo Lanhu MCP 尚未安装。请先在项目目录运行 easy-install.bat 1>&2
    exit /b 1
)
.\venv\Scripts\lanhu-mcp.exe --transport stdio
exit /b %errorlevel%
