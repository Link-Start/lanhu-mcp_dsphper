"""Regression checks for the source checkout installers."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize("script", ["easy-install.sh", "quickstart.sh", "run-stdio.sh"])
def test_posix_install_scripts_have_valid_bash_syntax(script):
    subprocess.run(["bash", "-n", str(ROOT / script)], check=True)


def test_easy_installer_rejects_python_39_before_creating_venv(tmp_path):
    installer = tmp_path / "easy-install.sh"
    shutil.copy2(ROOT / "easy-install.sh", installer)
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    fake_python = """#!/bin/sh
case "$*" in
  *"raise SystemExit"*) exit 1 ;;
  *"version_info[:3]"*) echo 3.9.6; exit 0 ;;
esac
exit 1
"""
    for name in ("python3", "python", "python3.13", "python3.12", "python3.11", "python3.10"):
        executable = fake_bin / name
        executable.write_text(fake_python, encoding="utf-8")
        executable.chmod(0o755)

    env = os.environ.copy()
    env["PATH"] = f"{fake_bin}{os.pathsep}{os.defpath}"
    env["TERM"] = "dumb"
    result = subprocess.run(
        ["bash", str(installer)],
        cwd=tmp_path,
        env=env,
        input="\n",
        text=True,
        capture_output=True,
        timeout=10,
    )

    output = result.stdout + result.stderr
    assert result.returncode == 1
    assert "Python 3.10" in output
    assert "3.9.6" in output
    assert not (tmp_path / "venv").exists()


def test_installers_install_the_package_and_default_to_domestic_mirrors():
    for filename in ("easy-install.sh", "quickstart.sh"):
        content = (ROOT / filename).read_text(encoding="utf-8")
        assert "pip install --timeout 60 --retries 5 -e ." in content
        assert "pip install --upgrade pip" not in content
        assert "https://pypi.tuna.tsinghua.edu.cn/simple" in content
        assert "https://cdn.npmmirror.com/binaries/playwright" in content

    for filename in ("easy-install.bat", "quickstart.bat"):
        content = (ROOT / filename).read_text(encoding="utf-8")
        assert "pip install --timeout 60 --retries 5 -e ." in content
        assert "pip install --upgrade pip" not in content
        assert "https://pypi.tuna.tsinghua.edu.cn/simple" in content
        assert "https://cdn.npmmirror.com/binaries/playwright" in content


def test_stdio_launcher_reports_missing_install(tmp_path):
    launcher = tmp_path / "run-stdio.sh"
    shutil.copy2(ROOT / "run-stdio.sh", launcher)
    result = subprocess.run(
        ["bash", str(launcher)],
        cwd=tmp_path,
        text=True,
        capture_output=True,
        timeout=10,
    )
    assert result.returncode == 1
    assert "easy-install.sh" in result.stderr
