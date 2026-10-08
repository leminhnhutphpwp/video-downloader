#!/usr/bin/env bash
# Cài môi trường cho tool (cần uv: https://docs.astral.sh/uv/)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
uv venv -q .venv
uv pip install -q --python .venv/bin/python -U "yt-dlp[default]" imageio-ffmpeg faster-whisper
mkdir -p downloads
.venv/bin/yt-dlp --version
