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


# Thời gian tách / thời lượng video, đo trên máy này (CPU 6 nhân, không GPU)
SPEED = {"tiny": 0.08, "base": 0.12, "small": 0.25, "medium": 0.7, "large-v3": 1.5}


def load_model(name: str) -> WhisperModel:
    """Ưu tiên model đã có trong máy; chưa có thì tải về (chỉ lần đầu)."""
    try:
        return WhisperModel(name, device="cpu", compute_type="int8", local_files_only=True)
    except Exception:
        print(f"[model] chưa có model '{name}' trong máy, đang tải về (chỉ lần đầu)...")
        return WhisperModel(name, device="cpu", compute_type="int8")


def fmt_ts(sec: float) -> str:
    ms = int(round(sec * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


DOWNLOADS = Path(__file__).resolve().parent / "downloads"


def locate(s: str):
    """Tìm đường dẫn thật: thử nguyên văn, rồi thử tương đối với downloads/."""
    s = s.strip().strip("'\"")
    rel = s.lstrip("/")
    if rel.startswith("downloads/"):
        rel = rel[len("downloads/"):]
    for c in (Path(s).expanduser(), DOWNLOADS / rel):
        if c.exists():
            return c
    return None


def resolve_paths(args):
    """Ghép lại đường dẫn bị shell cắt theo dấu cách khi quên để trong ngoặc kép.
    Với mỗi vị trí, lấy cụm từ dài nhất mà ghép lại thành đường dẫn có thật."""
    out, missing, i = [], [], 0
    while i < len(args):
        for j in range(len(args), i, -1):
            p = locate(" ".join(args[i:j]))
            if p:
                if missing:
                    out.append(" ".join(missing))
                    missing = []
                out.append(p)
                i = j
                break
        else:
            missing.append(args[i])
            i += 1
    if missing:
        out.append(" ".join(missing))
    return out


def find_videos(paths, force):
    for p in resolve_paths(paths):
        if isinstance(p, str):
            print(f"[bỏ qua] không tìm thấy: {p}", file=sys.stderr)
            continue
        files = sorted(p.rglob("*.mp4")) if p.is_dir() else [p]
        for f in files:
            if not f.is_file():
                print(f"[bỏ qua] không tìm thấy: {f}", file=sys.stderr)
            elif not force and f.with_suffix(".transcript.txt").exists():
                print(f"[bỏ qua] đã có transcript: {f.name}")
            else:
                yield f


def transcribe(model, video: Path, language, model_name):
    t0 = time.time()
    print(f"[tách] {video.name}")
    segments, info = model.transcribe(
        load_audio(video), language=language, vad_filter=True, beam_size=5
    )
    eta = info.duration * SPEED.get(model_name, 1) / 60
    print(f"       ngôn ngữ: {info.language} ({info.language_probability:.0%}), "
          f"video dài {info.duration / 60:.0f} phút, "
          f"ước tính xong sau ~{max(eta, 1):.0f} phút (model {model_name})")
    print("       đang tách... mỗi dòng dưới đây là 1 câu, số % là tiến độ. Dừng: Ctrl+C")

    srt, text = [], []
    for i, seg in enumerate(segments, 1):
        line = seg.text.strip()
        srt.append(f"{i}\n{fmt_ts(seg.start)} --> {fmt_ts(seg.end)}\n{line}\n")
        text.append(line)
        print(f"       {min(seg.end / max(info.duration, 1), 1):4.0%}  {line[:70]}", flush=True)

    video.with_suffix(".srt").write_text("\n".join(srt), encoding="utf-8")
    video.with_suffix(".transcript.txt").write_text("\n".join(text) + "\n", encoding="utf-8")
    print(f"       xong sau {(time.time() - t0) / 60:.1f} phút, đã ghi:")
    print(f"         {video.with_suffix('.transcript.txt')}")
    print(f"         {video.with_suffix('.srt')}")


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
        print("Không có video nào cần tách (đã có transcript hoặc sai đường dẫn).")
        return
    print(f"Tìm thấy {len(videos)} video cần tách.")
    model = load_model(args.model)
    for v in videos:
        try:
            transcribe(model, v, args.lang, args.model)
        except Exception as e:
            print(f"[lỗi] {v.name}: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
