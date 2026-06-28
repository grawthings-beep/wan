#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
import urllib.request
from pathlib import Path


def profile_matches(model, profile):
    if profile == "all":
        return True
    profiles = model.get("profiles") or []
    return profile in profiles or "base" in profiles


def download_file(url, destination, dry_run):
    print(f"Download: {destination.name}")
    print(f"  -> {destination}")

    if dry_run:
        return

    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": "wan-runpod-downloader/1.0"})

    with urllib.request.urlopen(request) as response, temporary.open("wb") as output:
        total = int(response.headers.get("Content-Length") or 0)
        downloaded = 0
        last_progress = 0.0

        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            output.write(chunk)
            downloaded += len(chunk)

            now = time.time()
            if total and now - last_progress > 5:
                percent = downloaded * 100 / total
                print(f"  {percent:.1f}%")
                last_progress = now

    os.replace(temporary, destination)


def main():
    parser = argparse.ArgumentParser(description="Download direct Hugging Face model URLs from manifests/models.json.")
    parser.add_argument("--comfyui-path", required=True, help="Path to the ComfyUI installation.")
    parser.add_argument("--manifest", default="manifests/models.json", help="Path to models.json.")
    parser.add_argument("--profile", default="gguf", choices=["gguf", "fp8", "mmaudio", "optional", "all"])
    parser.add_argument("--dry-run", action="store_true", help="Print actions without downloading.")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = repo_root / manifest_path

    comfyui_path = Path(args.comfyui_path).resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    selected = [model for model in manifest["models"] if profile_matches(model, args.profile)]
    downloadable = [model for model in selected if model.get("downloadable") is True and model.get("source_url")]
    manual = [model for model in selected if model not in downloadable]

    for model in downloadable:
        target_path = model.get("target_path")
        if not target_path or target_path == "custom-node-specific":
            manual.append(model)
            continue

        destination = comfyui_path / target_path / model["filename"]
        if destination.exists():
            print(f"Exists: {destination}")
            continue

        download_file(model["source_url"], destination, args.dry_run)

    if manual:
        print("")
        print("Manual downloads still needed:")
        for model in manual:
            print(f"- {model['filename']} -> {model.get('target_path', 'unknown')}")
            if model.get("source_url"):
                print(f"  {model['source_url']}")
            if model.get("notes"):
                print(f"  Note: {model['notes']}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
