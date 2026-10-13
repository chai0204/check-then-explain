#!/usr/bin/env python3
"""Podman の記事: probe/docker-fill.py を --slug podman で呼ぶだけ（道具は docker と podman の記事で共通）。

  python3 -I probe/podman-fill.py [docker-fill.py と同じ引数。--slug は付けなくてよい]
"""
import runpy, sys
from pathlib import Path
sys.argv = [sys.argv[0], "--slug", "podman"] + sys.argv[1:]
runpy.run_path(str(Path(__file__).resolve().parent / "docker-fill.py"), run_name="__main__")
