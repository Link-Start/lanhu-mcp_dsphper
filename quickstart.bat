@echo off
setlocal enabledelayedexpansion

REM 国内用户默认使用国内镜像；已设置环境变量时尊重用户配置。
if not defined PIP_INDEX_URL set "PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple"
if not defined PLAYWRIGHT_DOWNLOAD_HOST set "PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright"
chcp 65001 >nul 2>&1  :: 强制切换控制台编码为 UTF-8
powershell -Command "$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding" >nul 2>&1
REM 蓝湖 MCP 服务器快速启动脚本（Windows）

echo ======================================
echo 蓝湖 MCP 服务器 - 快速启动
echo ======================================
echo.

REM 检查 Python 版本
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 未检测到 Python
    echo 请从 https://www.python.org/downloads/ 安装 Python 3.10 或更高版本
    echo 安装时请勾选 "Add Python to PATH"
    pause
    exit /b 1
)

set "PYTHON_OK="
for /f %%V in ('python -c "import sys; print(1 if sys.version_info ^>= (3, 10) else 0)" 2^>nul') do set "PYTHON_OK=%%V"
if not "!PYTHON_OK!"=="1" (
    for /f "tokens=2" %%V in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%V"
    echo [ERROR] 需要 Python 3.10 或更高版本，当前版本：!PYTHON_VERSION!
    echo 请从 https://www.python.org/downloads/ 安装新版 Python 后重新运行
    pause
    exit /b 1
)

for /f "tokens=2" %%V in ('python --version') do set "PYTHON_VERSION=%%V"
echo [OK] Python !PYTHON_VERSION!
python -m pip --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 当前 Python 没有可用的 pip
    pause
    exit /b 1
)

REM 检查虚拟环境是否存在
if not exist "venv" (
    echo.
    echo 正在创建虚拟环境...
    python -m venv venv
    echo [OK] 虚拟环境创建完成
)
if not exist "venv\Scripts\python.exe" (
    echo [ERROR] venv 目录不是可用的 Python 虚拟环境
    echo 请删除 venv 目录后重新运行本脚本
    pause
    exit /b 1
)
set "VENV_PYTHON_OK="
for /f %%V in ('venv\Scripts\python.exe -c "import sys; print(1 if sys.version_info ^>= (3, 10) else 0)" 2^>nul') do set "VENV_PYTHON_OK=%%V"
if not "!VENV_PYTHON_OK!"=="1" (
    echo [ERROR] 现有 venv 的 Python 版本低于 3.10
    echo 请删除 venv 目录后重新运行本脚本
    pause
    exit /b 1
)

REM 安装项目及依赖
echo.
echo 正在安装项目及依赖...
venv\Scripts\python.exe -m pip install --timeout 60 --retries 5 -e .
if errorlevel 1 (
    echo [ERROR] 项目依赖下载失败
    echo 请检查网络或代理，然后重新运行本脚本
    echo 如需使用自定义 PyPI 镜像，可先设置 PIP_INDEX_URL
    pause
    exit /b 1
)
venv\Scripts\python.exe -m pip check

REM 安装 Playwright 浏览器
echo.
echo 正在安装 Playwright 浏览器...
venv\Scripts\python.exe -m playwright install chromium
if errorlevel 1 (
    echo [ERROR] Chromium 下载失败
    echo 请检查网络后重试，也可通过 PLAYWRIGHT_DOWNLOAD_HOST 指定其他镜像
    pause
    exit /b 1
)

REM 检查 .env 是否存在
if not exist ".env" (
    echo.
    echo [WARN] 未找到配置文件 .env
    
    if exist "config.example.env" (
        echo 正在从模板创建 .env...
        copy config.example.env .env
        echo [OK] .env 文件已创建
        echo.
        echo [WARN] 重要提示：请编辑 .env 文件并设置你的 LANHU_COOKIE
        echo    1. 在编辑器中打开 .env 文件
        echo    2. 将 'your_lanhu_cookie_here' 替换为你的实际 Cookie
        echo    3. 保存文件
        echo.
        pause
    ) else (
        echo [ERROR] 未找到 config.example.env
        pause
        exit /b 1
    )
)

REM 加载并导出 .env 文件中的环境变量
echo.
echo 正在加载配置...

REM 读取 .env 文件并设置环境变量
for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
    set "line=%%a"
    REM 跳过注释行和空行
    if not "!line:~0,1!"=="#" if not "!line!"=="" (
        REM 移除引号并设置环境变量
        set "value=%%b"
        set "value=!value:"=!"
        set "%%a=!value!"
    )
)

REM 检查 LANHU_COOKIE 是否已设置
if not defined LANHU_COOKIE (
    echo.
    echo [ERROR] LANHU_COOKIE 未配置
    echo 请编辑 .env 文件并设置你的蓝湖 Cookie
    echo.
    echo 获取 Cookie 的方法：
    echo 1. 登录 https://lanhuapp.com
    echo 2. 打开浏览器开发者工具（F12）
    echo 3. 切换到 Network（网络）标签
    echo 4. 刷新页面
    echo 5. 点击任意请求
    echo 6. 从请求头（Request Headers）中复制 'Cookie'
    pause
    exit /b 1
)

if "%LANHU_COOKIE%"=="your_lanhu_cookie_here" (
    echo.
    echo [ERROR] LANHU_COOKIE 未配置
    echo 请编辑 .env 文件并设置你的蓝湖 Cookie
    pause
    exit /b 1
)

echo [OK] 配置加载完成
call :strlen LANHU_COOKIE cookie_len
echo    Cookie 长度: %cookie_len% 字符

REM 创建数据目录
if not exist "data" mkdir data
if not exist "logs" mkdir logs

if not defined SERVER_PORT set SERVER_PORT=8000

echo.
echo 正在启动蓝湖 MCP 服务器...
echo ======================================
echo.
call scripts\print-mcp-config.bat
echo.
echo 按 Ctrl+C 停止服务器
echo.

REM 运行服务器
venv\Scripts\lanhu-mcp.exe --transport http

pause

REM 计算字符串长度的函数
:strlen
setlocal enabledelayedexpansion
set "str=!%~1!"
set "len=0"
:strlen_loop
if defined str (
    set "str=!str:~1!"
    set /a len+=1
    goto :strlen_loop
)
endlocal & set "%~2=%len%"
goto :eof
