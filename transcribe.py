"""Tách lời nói trong video .mp4 thành văn bản (faster-whisper, chạy CPU).

Ghi cạnh file video:
  <tên>.transcript.txt   văn bản liền mạch
  <tên>.srt              phụ đề có mốc thời gian
"""
import argparse
import subprocess
import sys
import time
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from faster_whisper import WhisperModel


def load_audio(video: Path) -> np.ndarray:
    """Giải mã audio 16kHz mono bằng ffmpeg đóng gói sẵn (tránh lỗi PyAV)."""
    out = subprocess.run(
        [imageio_ffmpeg.get_ffmpeg_exe(), "-nostdin", "-v", "error", "-i", str(video),
         "-vn", "-ac", "1", "-ar", "16000", "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(out, np.float32)


def fmt_ts(sec: float) -> str:
    ms = int(round(sec * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def find_videos(paths, force):
    for p in map(Path, paths):
        files = sorted(p.rglob("*.mp4")) if p.is_dir() else [p]
        for f in files:
            if not f.is_file():
                print(f"[bỏ qua] không tìm thấy: {f}", file=sys.stderr)
            elif not force and f.with_suffix(".transcript.txt").exists():
                print(f"[bỏ qua] đã có transcript: {f.name}")
            else:
                yield f


def transcribe(model, video: Path, language):
    t0 = time.time()
    print(f"[tách] {video.name}")
    segments, info = model.transcribe(
        load_audio(video), language=language, vad_filter=True, beam_size=5
    )
    print(f"       ngôn ngữ: {info.language} ({info.language_probability:.0%}), "
          f"dài {info.duration:.0f}s")

    srt, text = [], []
    for i, seg in enumerate(segments, 1):
        line = seg.text.strip()
        srt.append(f"{i}\n{fmt_ts(seg.start)} --> {fmt_ts(seg.end)}\n{line}\n")
        text.append(line)
        print(f"       {min(seg.end / max(info.duration, 1), 1):4.0%}  {line[:70]}", flush=True)

    video.with_suffix(".srt").write_text("\n".join(srt), encoding="utf-8")
    video.with_suffix(".transcript.txt").write_text("\n".join(text) + "\n", encoding="utf-8")
    print(f"       xong sau {time.time() - t0:.0f}s")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="file .mp4 hoặc thư mục (quét đệ quy)")
    ap.add_argument("-m", "--model", default="small",
                    help="tiny | base | small (mặc định) | medium | large-v3")
    ap.add_argument("-l", "--lang", default=None, help="vd: vi, en (mặc định: tự nhận)")
    ap.add_argument("--force", action="store_true", help="tách lại kể cả khi đã có")
    args = ap.parse_args()

    videos = list(find_videos(args.paths, args.force))
    if not videos:
        return
    model = WhisperModel(args.model, device="cpu", compute_type="int8")
    for v in videos:
        try:
            transcribe(model, v, args.lang)
        except Exception as e:
            print(f"[lỗi] {v.name}: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
