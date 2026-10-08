#!/usr/bin/env bash
# Tải video .mp4 từ YouTube / Facebook (và các trang yt-dlp hỗ trợ)
# Dùng:
#   ./dl.sh <url> [url2 ...]          tải 1 hoặc nhiều link
#   ./dl.sh -f links.txt              tải theo danh sách (mỗi dòng 1 link)
#   ./dl.sh -q 720 <url>              giới hạn chất lượng (mặc định: tốt nhất)
#   ./dl.sh -c chrome <url>           dùng cookie trình duyệt (FB riêng tư / YT giới hạn tuổi)
#   ./dl.sh -o /path/out <url>        thư mục lưu (mặc định: ./downloads)
#   ./dl.sh -t <url>                  tải xong tự tách lời ra văn bản (-m medium: chính xác hơn)
#   ./dl.sh -u                        cập nhật yt-dlp
set -euo pipefail
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PY="$DIR/.venv/bin/python"
YTDLP="$DIR/.venv/bin/yt-dlp"
FFMPEG="$("$PY" -c 'import imageio_ffmpeg as f; print(f.get_ffmpeg_exe())')"

OUT="$DIR/downloads"; QUALITY=""; COOKIES=""; BATCH=""; TRANSCRIBE=""; WMODEL="small"
while getopts "q:c:o:f:m:tuh" opt; do
  case $opt in
    q) QUALITY="$OPTARG" ;;
    c) COOKIES="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    f) BATCH="$OPTARG" ;;
    t) TRANSCRIBE=1 ;;
    m) WMODEL="$OPTARG"; TRANSCRIBE=1 ;;
    u) uv pip install -q --python "$PY" -U "yt-dlp[default]" && "$YTDLP" --version; exit 0 ;;
    h|*) sed -n '2,11p' "$0"; exit 0 ;;
  esac
done
shift $((OPTIND-1))
[[ $# -eq 0 && -z "$BATCH" ]] && { sed -n '2,11p' "$0"; exit 1; }

H="${QUALITY:+[height<=$QUALITY]}"
FMT="bv*${H}[vcodec^=avc1]+ba[ext=m4a]/bv*${H}+ba/b${H}/b"

# downloads/<ngày tải>/<tên video [id]>/<tên video [id]>.mp4
NAME='%(epoch>%Y-%m-%d)s/%(title).120B [%(id)s]'
NAME_FILE='%(title).120B [%(id)s]'

ARGS=(
  --ffmpeg-location "$FFMPEG"
  -f "$FMT"
  --merge-output-format mp4 --remux-video mp4
  -o "$OUT/$NAME/$NAME_FILE.%(ext)s"
  -o "thumbnail:$OUT/$NAME/$NAME_FILE.%(ext)s"
  --no-playlist
  --embed-metadata --embed-thumbnail --convert-thumbnails jpg
  --retries 10 --fragment-retries 10 -N 4
  --download-archive "$OUT/.archive.txt"
)
command -v node >/dev/null && ARGS+=(--js-runtimes node)
[[ -n "$COOKIES" ]] && ARGS+=(--cookies-from-browser "$COOKIES")
[[ -n "$BATCH" ]] && ARGS+=(-a "$BATCH")
[[ -n "$TRANSCRIBE" ]] && ARGS+=(--exec "after_move:\"$DIR/tach.sh\" -m $WMODEL {}")

mkdir -p "$OUT"
exec "$YTDLP" "${ARGS[@]}" "$@"
