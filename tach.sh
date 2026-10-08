#!/usr/bin/env bash
# Tách lời nói trong video .mp4 ra văn bản (.transcript.txt + .srt)
# Dùng:
#   ./tach.sh <file.mp4 | thư mục> ...    mặc định quét cả ./downloads
#   ./tach.sh -m medium -l vi <file>       model chính xác hơn (chậm hơn), ép tiếng Việt
#   ./tach.sh --force <file>               tách lại
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[[ " $* " == *" -h "* || " $* " == *" --help "* ]] && exec "$DIR/.venv/bin/python" -I "$DIR/transcribe.py" -h
[[ $# -eq 0 ]] && set -- "$DIR/downloads"
exec "$DIR/.venv/bin/python" -I "$DIR/transcribe.py" "$@"
