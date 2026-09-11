"""Validate the installed host. Model warmup is explicit; no microphone capture.

Run with runtime/agent/backtalk/.venv/Scripts/python.exe. This is installation
verification, not an AgentBridge or authenticated Claude integration test.
"""
from __future__ import annotations

import argparse
import importlib.metadata
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def configure() -> None:
    paths = {
        "BACKTALK_CONFIG": ROOT / "runtime/config/backtalk.json",
        "HF_HOME": ROOT / ".tools/models/huggingface",
        "TORCH_HOME": ROOT / ".tools/models/torch",
        "XDG_CACHE_HOME": ROOT / ".tools/cache",
        "PHONEMIZER_ESPEAK_LIBRARY": ROOT / ".tools/espeak/eSpeak NG/libespeak-ng.dll",
        "ESPEAK_DATA_PATH": ROOT / ".tools/espeak/eSpeak NG/espeak-ng-data",
        "TEMP": ROOT / "runtime/temp",
        "TMP": ROOT / "runtime/temp",
    }
    for name, value in paths.items():
        os.environ[name] = str(value)
    # Restrict upstream phonemizer's temporary-file sweep to our own directory.
    (ROOT / "runtime/temp").mkdir(parents=True, exist_ok=True)
    os.environ["PYTHONNOUSERSITE"] = "1"
    sys.path.insert(0, str(ROOT / "runtime/agent/backtalk"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--warm-voice", action="store_true", help="Download/load upstream speech models and test inference")
    parser.add_argument("--offline", action="store_true", help="Require cached models; never download")
    args = parser.parse_args()
    configure()
    if args.offline:
        os.environ["HF_HUB_OFFLINE"] = "1"
        os.environ["TRANSFORMERS_OFFLINE"] = "1"
    from backtalk.config import CFG
    import backtalk.brain  # noqa: F401: imports only, no Claude connection
    from backtalk import ears, mouth
    import sounddevice

    report = {
        "python": sys.version.split()[0],
        "sdk": importlib.metadata.version("claude-agent-sdk"),
        "backtalk_imports": "passed",
        "permission_mode": CFG["permission_mode"],
        "microphone_mode": CFG["mic_mode"],
        "audio_device_count": len(sounddevice.query_devices()),
        "claude_integration": "blocked: account not configured",
        "remote_voice": "not implemented",
    }
    if CFG["permission_mode"] != "ask":
        raise RuntimeError("Unexpected permissive local voice configuration")
    if args.warm_voice:
        import spacy.util
        if not spacy.util.is_package("en_core_web_sm"):
            raise RuntimeError("Voice language pipeline missing. Run scripts/Host.ps1 sync first.")
        import numpy as np
        import soundfile
        print("Loading existing backtalk STT/TTS models; no microphone or speakers are opened.", flush=True)
        started = time.monotonic()
        model = ears.warm()
        pipeline = mouth.warm()
        phrase = "The local voice test is complete."
        audio = np.concatenate([
            np.asarray(result.audio, dtype=np.float32)
            for result in pipeline(phrase, voice=CFG["voice"])
            if result.audio is not None
        ])
        if not np.isfinite(audio).all() or len(audio) < 24000 or float(np.max(np.abs(audio))) < 0.001:
            raise RuntimeError("TTS did not produce valid audible PCM")
        out = ROOT / "artifacts/verification"
        out.mkdir(parents=True, exist_ok=True)
        wav = out / "local-voice-test.wav"
        soundfile.write(wav, audio, 24000, subtype="PCM_16")
        segments, _ = model.transcribe(str(wav), language="en", temperature=0.0)
        transcript = " ".join(segment.text.strip() for segment in segments)
        if "voice test" not in transcript.casefold() or "complete" not in transcript.casefold():
            raise RuntimeError(f"Local TTS/STT round trip failed: {transcript!r}")
        report["local_synthetic_voice_roundtrip"] = {
            "status": "passed", "text": transcript,
            "duration_seconds": round(len(audio) / 24000, 2),
            "warmup_and_test_seconds": round(time.monotonic() - started, 2),
            "artifact": str(wav),
            "microphone_capture": False, "speaker_playback": False,
        }
        (out / "host-check.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
