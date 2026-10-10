#!/usr/bin/env bash
# tach.sh — Tách lời nói trong video .mp4 ra văn bản.
# Xem hướng dẫn: ./tach.sh -h
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

usage() {
  cat <<'HELP'
TÁCH LỜI NÓI TRONG VIDEO RA VĂN BẢN
====================================
Cách dùng:   ./tach.sh [tùy chọn] "<file .mp4 hoặc folder>"

Ví dụ:
  ./tach.sh                                     Tách mọi video trong downloads/ chưa có transcript
  ./tach.sh "downloads/2026-10-08/<tên video>"  Tách 1 video (đưa folder hoặc file .mp4 đều được)
  ./tach.sh "downloads/2026-10-08"              Tách tất cả video tải trong ngày đó
  ./tach.sh -m medium -l vi "<folder>"          Tiếng Việt, chính xác hơn  ← nên dùng

Tùy chọn:
  -m <model>   Độ chính xác (càng xuống càng chính xác nhưng càng chậm):
                 tiny      rất nhanh, sai nhiều       ~5 phút cho video 1 tiếng
                 small     mặc định                   ~15 phút cho video 1 tiếng
                 medium    nên dùng cho tiếng Việt    ~40 phút cho video 1 tiếng
                 large-v3  chính xác nhất, rất chậm   ~90 phút cho video 1 tiếng
  -l <ngôn ngữ> Ép ngôn ngữ: vi (tiếng Việt), en (tiếng Anh)...  (mặc định: tự nhận)
  --force      Tách lại cả video đã có transcript
  -h           Hiện hướng dẫn này

Kết quả ghi cạnh file video:
  <tên>.transcript.txt   toàn bộ lời nói, mỗi câu 1 dòng
  <tên>.srt              phụ đề có mốc thời gian (mở cùng video bằng VLC)

Lưu ý:
  - Đường dẫn có dấu cách: để trong ngoặc kép hay không đều được, tool tự ghép lại.
    Có thể bỏ "downloads/" ở đầu, vd: ./tach.sh 2026-10-08/<tên video>
  - Đang chạy thì terminal in dần từng câu kèm % tiến độ. Muốn dừng: Ctrl+C.
  - Tên riêng nước ngoài hay bị phiên âm sai, nên đọc lại.
HELP
}

[[ " $* " == *" -h "* || " $* " == *" --help "* ]] && { usage; exit 0; }
# Không truyền đường dẫn thì quét cả thư mục downloads/
[[ $# -eq 0 ]] && set -- "$DIR/downloads"
exec "$DIR/.venv/bin/python" -I "$DIR/transcribe.py" "$@"
