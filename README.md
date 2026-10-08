# video-downloader

Tool local tải video `.mp4` từ YouTube / Facebook và tách lời nói ra văn bản.

- Tải: [yt-dlp](https://github.com/yt-dlp/yt-dlp) + ffmpeg đóng gói sẵn (`imageio-ffmpeg`), không cần sudo
- Tách lời: [faster-whisper](https://github.com/SYSTRAN/faster-whisper), chạy CPU

## Cài đặt

```bash
./setup.sh
```

Cần [uv](https://docs.astral.sh/uv/). Nếu có `node` trong PATH, tool tự dùng làm JS runtime cho YouTube.

## Tải video

```bash
./dl.sh "<link>"                 # chất lượng cao nhất
./dl.sh -q 720 "<link>"          # tối đa 720p
./dl.sh -f links.txt             # tải theo danh sách (mỗi dòng 1 link)
./dl.sh -c chrome "<link>"       # dùng cookie trình duyệt (FB riêng tư, YT giới hạn tuổi)
./dl.sh -o ~/Videos "<link>"     # đổi thư mục lưu
./dl.sh -t "<link>"              # tải xong tự tách lời
./dl.sh -m medium "<link>"       # như -t, dùng model chính xác hơn
./dl.sh -u                       # cập nhật yt-dlp
```

Link đã tải sẽ được bỏ qua (`downloads/.archive.txt`).

## Tách lời

```bash
./tach.sh                          # tách mọi video trong downloads/ chưa có transcript
./tach.sh "<file.mp4 | thư mục>"
./tach.sh -m medium -l vi "<file>" # model chính xác hơn, ép tiếng Việt
./tach.sh --force "<file>"         # tách lại
```

Model: `tiny`, `base`, `small` (mặc định), `medium`, `large-v3`. Trên CPU, `medium` mất khoảng 0.7× thời lượng video. Tên riêng nước ngoài thường bị phiên âm sai, nên rà lại.

## Cấu trúc lưu

```
downloads/
└── <ngày tải YYYY-MM-DD>/
    └── <tên video [id]>/
        ├── <tên video [id]>.mp4
        ├── <tên video [id]>.transcript.txt   # văn bản liền mạch
        └── <tên video [id]>.srt              # phụ đề có mốc thời gian
```
