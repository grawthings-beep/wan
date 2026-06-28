#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path


def run(command, cwd=None, dry_run=False):
    printable = " ".join(command)
    if cwd:
        printable = f"(cd {cwd} && {printable})"
    print(printable)
    if dry_run:
        return
    subprocess.run(command, cwd=cwd, check=True)


def repo_dir_name(repo_url):
    name = repo_url.rstrip("/").split("/")[-1]
    if name.endswith(".git"):
        name = name[:-4]
    return name


def main():
    parser = argparse.ArgumentParser(description="Install ComfyUI custom nodes from manifests/custom_nodes.json.")
    parser.add_argument("--comfyui-path", help="Path to the ComfyUI installation.")
    parser.add_argument("--custom-nodes-dir", help="Install directly into this custom_nodes directory.")
    parser.add_argument("--manifest", default="manifests/custom_nodes.json", help="Path to custom_nodes.json.")
    parser.add_argument("--dry-run", action="store_true", help="Print actions without installing.")
    parser.add_argument("--skip-requirements", action="store_true", help="Do not pip install custom node requirements.")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = repo_root / manifest_path

    if args.custom_nodes_dir:
        custom_nodes_dir = Path(args.custom_nodes_dir).resolve()
    elif args.comfyui_path:
        comfyui_path = Path(args.comfyui_path).resolve()
        custom_nodes_dir = comfyui_path / "custom_nodes"
    else:
        parser.error("one of --comfyui-path or --custom-nodes-dir is required")

    if not args.dry_run:
        custom_nodes_dir.mkdir(parents=True, exist_ok=True)

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for node in manifest["custom_nodes"]:
        repo = node.get("repo")
        if not repo:
            continue

        destination = custom_nodes_dir / repo_dir_name(repo)
        if destination.exists():
            if (destination / ".git").exists():
                run(["git", "pull", "--ff-only"], cwd=destination, dry_run=args.dry_run)
            else:
                print(f"Skip existing non-git directory: {destination}")
        else:
            run(["git", "clone", "--depth", "1", repo, str(destination)], dry_run=args.dry_run)

        requirements = destination / "requirements.txt"
        if not args.skip_requirements and requirements.exists():
            run([sys.executable, "-m", "pip", "install", "-r", str(requirements)], dry_run=args.dry_run)


if __name__ == "__main__":
    main()
