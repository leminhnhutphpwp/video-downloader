#!/usr/bin/env bash
# dl.sh — Tải video .mp4 từ YouTube / Facebook về máy.
# Xem hướng dẫn: ./dl.sh -h
set -euo pipefail

usage() {
  cat <<'HELP'
TẢI VIDEO TỪ YOUTUBE / FACEBOOK
================================
Cách dùng:   ./dl.sh [tùy chọn] "<link>" ["<link 2>" ...]

Ví dụ:
  ./dl.sh "https://www.youtube.com/watch?v=xxxx"     Tải 1 video, chất lượng cao nhất
  ./dl.sh "<link 1>" "<link 2>"                      Tải nhiều video một lúc
  ./dl.sh -f links.txt                               Tải tất cả link trong file links.txt
  ./dl.sh -q 720 "<link>"                            Tải tối đa 720p (file nhẹ hơn)
  ./dl.sh -t "<link>"                                Tải xong tự tách lời ra văn bản
  ./dl.sh -m medium "<link>"                         Như -t nhưng tách chính xác hơn (chậm hơn)

Tùy chọn:
  -q <số>      Chất lượng tối đa: 360, 480, 720, 1080...  (mặc định: cao nhất)
  -t           Tải xong tự tách lời (model small, nhanh)
  -m <model>   Tải xong tự tách lời bằng model chỉ định: small | medium | large-v3
               Video tiếng Việt nên dùng medium.
  -f <file>    Đọc danh sách link từ file (mỗi dòng 1 link, dòng bắt đầu bằng # bỏ qua)
  -c <browser> Lấy đăng nhập từ trình duyệt: chromium | chrome | brave | firefox | edge
               Dùng khi video Facebook riêng tư / trong group, YouTube giới hạn tuổi.
               Khi YouTube báo "Sign in to confirm you're not a bot" tool tự lấy
               đăng nhập từ trình duyệt có sẵn và tải lại, rồi nhớ luôn cho lần sau.
  -o <thư mục> Lưu vào thư mục khác (mặc định: downloads/ trong folder tool)
  -u           Cập nhật yt-dlp (chạy khi YouTube/Facebook bỗng tải lỗi)
  -h           Hiện hướng dẫn này

Video lưu ở:
  downloads/<ngày tải>/<tên video [id]>/<tên video [id]>.mp4
  Tên file không dấu. Link đã tải rồi sẽ tự bỏ qua.

Lưu ý: luôn để link trong dấu ngoặc kép "..." để tránh lỗi với ký tự & ?
HELP
}
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PY="$DIR/.venv/bin/python"
YTDLP="$DIR/.venv/bin/yt-dlp"
FFMPEG="$("$PY" -c 'import imageio_ffmpeg as f; print(f.get_ffmpeg_exe())')"

# Trình duyệt đã dùng thành công lần trước khi YouTube chặn bot
BROWSER_FILE="$DIR/.cookies-browser"

OUT="$DIR/downloads"; QUALITY=""; COOKIES="$(cat "$BROWSER_FILE" 2>/dev/null || true)"; BATCH=""; TRANSCRIBE=""; WMODEL="small"
while getopts "q:c:o:f:m:tuh" opt; do
  case $opt in
    q) QUALITY="$OPTARG" ;;
    c) COOKIES="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    f) BATCH="$OPTARG" ;;
    t) TRANSCRIBE=1 ;;
    m) WMODEL="$OPTARG"; TRANSCRIBE=1 ;;
    u) uv pip install -q --python "$PY" -U "yt-dlp[default]" && "$YTDLP" --version; exit 0 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND-1))
[[ $# -eq 0 && -z "$BATCH" ]] && { usage; exit 1; }

# Ưu tiên video H.264 + audio AAC để .mp4 mở được trên mọi trình phát
H="${QUALITY:+[height<=$QUALITY]}"
FMT="bv*${H}[vcodec^=avc1]+ba[ext=m4a]/bv*${H}+ba/b${H}/b"

# downloads/<ngày tải>/<tên video [id]>/<tên video [id]>.mp4
NAME='%(epoch>%Y-%m-%d)s/%(fname).120B [%(id)s]'
NAME_FILE='%(fname).120B [%(id)s]'

# Tên file/folder không dấu: chép title sang field fname rồi bỏ dấu tiếng Việt
# (title nhúng trong mp4 vẫn giữ nguyên có dấu)
NODIACRITIC=(
  --parse-metadata 'title:(?P<fname>.+)'
  --replace-in-metadata fname '[àáạảãâầấậẩẫăằắặẳẵ]' a
  --replace-in-metadata fname '[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]' A
  --replace-in-metadata fname '[èéẹẻẽêềếệểễ]' e
  --replace-in-metadata fname '[ÈÉẸẺẼÊỀẾỆỂỄ]' E
  --replace-in-metadata fname '[ìíịỉĩ]' i
  --replace-in-metadata fname '[ÌÍỊỈĨ]' I
  --replace-in-metadata fname '[òóọỏõôồốộổỗơờớợởỡ]' o
  --replace-in-metadata fname '[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]' O
  --replace-in-metadata fname '[ùúụủũưừứựửữ]' u
  --replace-in-metadata fname '[ÙÚỤỦŨƯỪỨỰỬỮ]' U
  --replace-in-metadata fname '[ỳýỵỷỹ]' y
  --replace-in-metadata fname '[ỲÝỴỶỸ]' Y
  --replace-in-metadata fname 'đ' d
  --replace-in-metadata fname 'Đ' D
  --replace-in-metadata fname '[^A-Za-z0-9 ._()\[\]-]+' ' '
  --replace-in-metadata fname '\s+' ' '
  --replace-in-metadata fname '^ | $' ''
)

# Tham số truyền cho yt-dlp
ARGS=(
  "${NODIACRITIC[@]}"
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
# YouTube cần JS runtime để lấy đủ định dạng; dùng node nếu máy có
command -v node >/dev/null && ARGS+=(--js-runtimes node)
[[ -n "$BATCH" ]] && ARGS+=(-a "$BATCH")
# -t / -m: sau khi tải xong mỗi video, gọi tach.sh để tách lời
[[ -n "$TRANSCRIBE" ]] && ARGS+=(--exec "after_move:\"$DIR/tach.sh\" -m $WMODEL {}")

# Trình duyệt đầu tiên trên máy có file cookie
find_browser() {
  local C="$HOME/.config" b f
  shopt -s nullglob
  for b in chromium:"$C/chromium" chrome:"$C/google-chrome" brave:"$C/BraveSoftware/Brave-Browser" \
           edge:"$C/microsoft-edge" firefox:"$HOME/.mozilla/firefox" firefox:"$HOME/snap/firefox/common/.mozilla/firefox"; do
    for f in "${b#*:}"/*/Cookies "${b#*:}"/*/Network/Cookies "${b#*:}"/*/cookies.sqlite; do
      echo "${b%%:*}"; return
    done
  done
}

# Chạy yt-dlp, vừa in lỗi ra màn hình vừa ghi lại để kiểm tra
LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
run() {
  local rc=0
  { "$YTDLP" "${ARGS[@]}" "$@" 2>&1 1>&3 3>&- | tee "$LOG" >&2; } 3>&1 || rc=$?
  return $rc
}

mkdir -p "$OUT"
[[ -n "$COOKIES" ]] && ARGS+=(--cookies-from-browser "$COOKIES")
run "$@" && exit 0 || rc=$?

# YouTube chặn bot (429 / bắt đăng nhập): lấy cookie trình duyệt rồi tải lại
if [[ -z "$COOKIES" ]] && grep -qE "not a bot|HTTP Error 429|--cookies" "$LOG"; then
  COOKIES="$(find_browser)"
  if [[ -z "$COOKIES" ]]; then
    echo ">> YouTube đang chặn. Hãy đăng nhập YouTube trên Chrome/Chromium/Firefox rồi chạy lại." >&2
    exit $rc
  fi
  echo ">> YouTube đang chặn, thử lại bằng đăng nhập từ trình duyệt: $COOKIES" >&2
  ARGS+=(--cookies-from-browser "$COOKIES")
  rc=0; run "$@" || rc=$?
  # Thành công thì nhớ trình duyệt, lần sau dùng luôn khỏi bị chặn
  [[ $rc -eq 0 ]] && echo "$COOKIES" > "$BROWSER_FILE"
fi
exit $rc
