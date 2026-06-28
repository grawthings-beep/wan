#!/usr/bin/env python3
import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path


TEMPLATE_RE = re.compile(r"\{\{.+?\}\}|\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*")


def expand(value):
    if isinstance(value, str):
        return os.path.expandvars(value)
    if isinstance(value, list):
        return [expand(item) for item in value]
    if isinstance(value, dict):
        return {key: expand(item) for key, item in value.items()}
    return value


def has_unresolved_template(value):
    return isinstance(value, str) and bool(TEMPLATE_RE.search(value))


def profile_matches(model, profile):
    if profile == "all":
        return True
    profiles = model.get("profiles") or []
    return profile in profiles or "base" in profiles


def missing_required_env(names):
    missing = []
    for name in names or []:
        value = os.environ.get(str(name), "").strip()
        if not value or has_unresolved_template(value):
            missing.append(str(name))
    return missing


def cleaned_headers(raw):
    headers = {}
    for key, value in (raw or {}).items():
        value = expand(str(value)).strip()
        if not value or has_unresolved_template(value):
            continue
        headers[key] = value
    return headers


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024 * 8), b""):
            digest.update(chunk)
    return digest.hexdigest().lower()


def civitai_download_url(source_url, model_version_id):
    if model_version_id:
        return f"https://civitai.com/api/download/models/{model_version_id}"

    parsed = urllib.parse.urlparse(source_url)
    query = urllib.parse.parse_qs(parsed.query)
    values = query.get("modelVersionId") or query.get("modelVersionID")
    if values:
        return f"https://civitai.com/api/download/models/{values[0]}"

    return source_url


def normalize_entry(model):
    model = expand(model)
    target_path = model.get("target_path")
    filename = model.get("filename")
    source_url = model.get("download_url") or model.get("source_url") or model.get("url")

    if model.get("path"):
        path = model["path"]
    elif target_path and filename and target_path != "custom-node-specific":
        path = f"{target_path.rstrip('/')}/{filename}"
    else:
        path = filename

    url = source_url
    headers = dict(model.get("headers") or {})
    requires_env = list(model.get("requires_env") or [])
    provider = model.get("provider")

    if source_url and "civitai.com" in source_url:
        provider = provider or "civitai"
        url = civitai_download_url(source_url, model.get("model_version_id"))
        token_name = model.get("token_env") or "CIVITAI_TOKEN"
        if token_name not in requires_env:
            requires_env.append(token_name)
        headers.setdefault("Authorization", f"Bearer ${{{token_name}}}")

    if source_url and "huggingface.co" in source_url:
        provider = provider or "huggingface"
        token_name = model.get("token_env") or "HF_TOKEN"
        if os.environ.get(token_name):
            headers.setdefault("Authorization", f"Bearer ${{{token_name}}}")

    return {
        "name": model.get("name") or filename or path,
        "path": path,
        "url": url,
        "headers": headers,
        "requires_env": requires_env,
        "required": bool(model.get("required", model.get("downloadable", True))),
        "enabled": bool(model.get("enabled", True)),
        "downloadable": bool(model.get("downloadable", bool(url and path))),
        "sha256": model.get("sha256"),
        "min_bytes": int(model.get("min_bytes") or 0),
        "use_aria2": bool(model.get("use_aria2", True)),
        "provider": provider,
        "notes": model.get("notes"),
    }


def resolve_download_url(url, headers, timeout=120):
    request_headers = {"User-Agent": headers.get("User-Agent", "wan-runpod-downloader/1.0")}
    request_headers.update(headers)
    request = urllib.request.Request(url, headers=request_headers)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.geturl()


def run_aria2(url, output, headers, connections, splits):
    output.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "aria2c",
        "-x",
        str(connections),
        "-s",
        str(splits),
        "-k",
        "1M",
        "--continue=true",
        "--allow-overwrite=true",
        "--auto-file-renaming=false",
        "--summary-interval=10",
        "--console-log-level=warn",
        "-d",
        str(output.parent),
        "-o",
        output.name,
    ]
    if headers.get("User-Agent"):
        cmd.append(f"--user-agent={headers['User-Agent']}")
    for key, value in headers.items():
        if key.lower() == "user-agent":
            continue
        cmd.append(f"--header={key}: {value}")
    cmd.append(url)
    subprocess.run(cmd, check=True)


def run_curl(url, output, headers):
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + ".part")
    cmd = [
        "curl",
        "-fL",
        "--retry",
        "5",
        "--retry-delay",
        "3",
        "--retry-all-errors",
        "-A",
        headers.get("User-Agent", "wan-runpod-downloader/1.0"),
    ]
    for key, value in headers.items():
        if key.lower() == "user-agent":
            continue
        cmd.extend(["-H", f"{key}: {value}"])
    cmd.extend(["-o", str(temporary), url])
    subprocess.run(cmd, check=True)
    os.replace(temporary, output)


def run_urllib(url, output, headers):
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + ".part")
    request_headers = {"User-Agent": headers.get("User-Agent", "wan-runpod-downloader/1.0")}
    request_headers.update(headers)
    request = urllib.request.Request(url, headers=request_headers)
    with urllib.request.urlopen(request, timeout=120) as response, temporary.open("wb") as handle:
        total = int(response.headers.get("Content-Length") or 0)
        downloaded = 0
        last_progress = 0.0
        while True:
            chunk = response.read(1024 * 1024 * 8)
            if not chunk:
                break
            handle.write(chunk)
            downloaded += len(chunk)
            now = time.time()
            if total and now - last_progress > 10:
                print(f"  {output.name}: {downloaded * 100 / total:.1f}%")
                last_progress = now
    os.replace(temporary, output)


def verify_existing(output, expected_sha, min_bytes):
    if not output.exists() or output.stat().st_size <= 0:
        return False
    if min_bytes and output.stat().st_size < min_bytes:
        print(f"Too small, redownloading: {output}", file=sys.stderr)
        output.unlink()
        return False
    if expected_sha and sha256_file(output) != expected_sha:
        print(f"SHA mismatch, redownloading: {output}", file=sys.stderr)
        output.unlink()
        return False
    return True


def download(entry, root, dry_run, use_aria2, connections, splits):
    if not entry.get("enabled", True):
        print(f"SKIP disabled: {entry.get('name') or entry.get('path')}")
        return

    name = entry.get("name") or entry.get("path")
    if not entry.get("downloadable", True):
        print(f"SKIP manual: {name}")
        if entry.get("notes"):
            print(f"  Note: {entry['notes']}")
        return

    url = entry.get("url")
    path = entry.get("path")
    if not url or not path:
        raise RuntimeError(f"download entry is missing url/path: {name}")

    missing_env = missing_required_env(entry.get("requires_env"))
    if missing_env:
        message = f"missing required env for {name}: {', '.join(missing_env)}"
        if dry_run:
            print(f"DRY-RUN warning: {message}")
            print(f"  -> would require env before real download")
            return
        if entry.get("required", True):
            raise RuntimeError(message)
        print(f"WARN optional model skipped: {message}", file=sys.stderr)
        return

    if has_unresolved_template(url):
        message = f"unresolved template in url for {name}"
        if entry.get("required", True):
            raise RuntimeError(message)
        print(f"WARN optional model skipped: {message}", file=sys.stderr)
        return

    output = root / path
    expected_sha = (entry.get("sha256") or "").lower()
    min_bytes = int(entry.get("min_bytes") or 0)
    if verify_existing(output, expected_sha, min_bytes):
        print(f"SKIP existing: {name}")
        return

    headers = cleaned_headers(entry.get("headers"))
    print(f"DOWNLOAD: {name}")
    print(f"  -> {output}")
    if dry_run:
        print(f"  URL: {url}")
        return

    try:
        if use_aria2 and entry.get("use_aria2", True) and shutil.which("aria2c"):
            final_url = resolve_download_url(url, headers)
            run_aria2(final_url, output, headers, connections, splits)
        elif shutil.which("curl"):
            run_curl(url, output, headers)
        else:
            run_urllib(url, output, headers)

        if min_bytes and output.stat().st_size < min_bytes:
            raise RuntimeError(f"downloaded file is too small: {output} ({output.stat().st_size} bytes)")
        if expected_sha and sha256_file(output) != expected_sha:
            raise RuntimeError(f"sha256 mismatch: {output}")
    except Exception:
        temporary = output.with_name(output.name + ".part")
        if temporary.exists():
            temporary.unlink()
        if output.exists():
            output.unlink()
        raise


def load_entries(manifest_path, profile, required_only):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = []
    for model in manifest.get("models", []):
        if not profile_matches(model, profile):
            continue
        entry = normalize_entry(model)
        if required_only and not entry.get("required", True):
            print(f"SKIP optional: {entry.get('name') or entry.get('path')}")
            continue
        entries.append(entry)
    return entries


def main():
    parser = argparse.ArgumentParser(description="Fast parallel downloader for Wan RunPod model manifests.")
    parser.add_argument("--comfyui-path", help="Path to the ComfyUI installation. Kept for backward compatibility.")
    parser.add_argument("--root", help="Root directory that contains the ComfyUI-style models/ folders.")
    parser.add_argument("--manifest", default="manifests/models.json", help="Path to models.json.")
    parser.add_argument("--profile", default="gguf", choices=["gguf", "fp8", "mmaudio", "optional", "all"])
    parser.add_argument("--dry-run", action="store_true", help="Print actions without downloading.")
    parser.add_argument("--required-only", action="store_true", help="Skip optional manifest entries.")
    parser.add_argument("--no-aria2", action="store_true", help="Do not use aria2c even when available.")
    parser.add_argument("--connections", type=int, default=int(os.environ.get("ARIA2_CONNECTIONS", "16")))
    parser.add_argument("--splits", type=int, default=int(os.environ.get("ARIA2_SPLITS", "16")))
    parser.add_argument("--jobs", type=int, default=int(os.environ.get("MODEL_DOWNLOAD_JOBS", "4")))
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = repo_root / manifest_path

    if args.root:
        model_root = Path(args.root).resolve()
    elif args.comfyui_path:
        model_root = Path(args.comfyui_path).resolve()
    else:
        parser.error("one of --root or --comfyui-path is required")

    entries = load_entries(manifest_path, args.profile, args.required_only)
    jobs = max(1, args.jobs)

    if jobs == 1 or len(entries) <= 1 or args.dry_run:
        for entry in entries:
            download(entry, model_root, args.dry_run, not args.no_aria2, args.connections, args.splits)
        return

    print(f"Downloading {len(entries)} model(s) with {jobs} parallel job(s).")
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
        futures = [
            executor.submit(download, entry, model_root, args.dry_run, not args.no_aria2, args.connections, args.splits)
            for entry in entries
        ]
        for future in concurrent.futures.as_completed(futures):
            future.result()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
