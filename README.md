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
./dl.sh -c chromium "<link>"     # dùng cookie trình duyệt (FB riêng tư, YT giới hạn tuổi)
                                 # YouTube báo "not a bot" thì tool tự lấy cookie trình duyệt và tải lại
./dl.sh -o ~/Videos "<link>"     # đổi thư mục lưu
./dl.sh -t "<link>"              # tải xong tự tách lời
./dl.sh -m medium "<link>"       # như -t, dùng model chính xác hơn
./dl.sh -u                       # cập nhật yt-dlp
./dl.sh -h                       # hướng dẫn đầy đủ
```

Tên file/folder không dấu. Link đã tải sẽ được bỏ qua (`downloads/.archive.txt`). Luôn để link trong `"..."`.

## Tách lời

```bash
./tach.sh -m medium -l vi "downloads/2026-10-08/<tên video>"   # nên dùng cho tiếng Việt
./tach.sh                                  # tách mọi video trong downloads/ chưa có transcript
./tach.sh "downloads/2026-10-08"           # tách tất cả video tải trong ngày đó
./tach.sh --force "<folder>"               # tách lại
./tach.sh -h                               # hướng dẫn đầy đủ
```

Đưa vào folder hoặc file `.mp4` đều được. Đường dẫn có dấu cách nên để trong `"..."`.

| Model (`-m`) | Ghi chú | Video 1 tiếng mất khoảng (CPU) |
|---|---|---|
| `tiny` | rất nhanh, sai nhiều | 5 phút |
| `small` | mặc định | 15 phút |
| `medium` | nên dùng cho tiếng Việt | 40 phút |
| `large-v3` | chính xác nhất | 90 phút |

Lúc chạy, terminal báo thời gian ước tính rồi in dần từng câu kèm % tiến độ. Dừng bằng `Ctrl+C`. Tên riêng nước ngoài hay bị phiên âm sai, nên đọc lại.

## Cấu trúc lưu

```
downloads/
└── <ngày tải YYYY-MM-DD>/
    └── <tên video [id]>/
        ├── <tên video [id]>.mp4
        ├── <tên video [id]>.transcript.txt   # văn bản liền mạch
        └── <tên video [id]>.srt              # phụ đề có mốc thời gian
```
