#!/usr/bin/env python3
import json
import re
import sys
from collections import Counter
from pathlib import Path


MODEL_FILE_RE = re.compile(r"[^\\/\\n\\r\\t\\0]*\\.(?:safetensors|gguf|pth|pkl|ckpt|pt|bin|onnx)\\b", re.I)
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)
BUILTIN_NODE_TYPES = {
    "GetNode",
    "MarkdownNote",
    "SetNode",
}


def walk(value):
    if isinstance(value, dict):
        yield value
        for item in value.values():
            yield from walk(item)
    elif isinstance(value, list):
        for item in value:
            yield from walk(item)


def collect_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from collect_strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from collect_strings(item)


def main():
    repo = Path(__file__).resolve().parents[1]
    workflow = json.loads((repo / "workflows/WAN2.2-I2V-AutoPrompt-Story.json").read_text(encoding="utf-8"))
    models = json.loads((repo / "manifests/models.json").read_text(encoding="utf-8"))
    custom_nodes = json.loads((repo / "manifests/custom_nodes.json").read_text(encoding="utf-8"))

    manifest_files = {entry.get("filename") for entry in models.get("models", []) if entry.get("filename")}
    workflow_files = set()
    for text in collect_strings(workflow):
        for match in MODEL_FILE_RE.finditer(text):
            workflow_files.add(Path(match.group(0).strip()).name)

    missing_files = sorted(workflow_files - manifest_files)

    covered_node_types = set()
    for entry in custom_nodes.get("custom_nodes", []):
        covered_node_types.update(entry.get("node_types") or [])

    missing_node_types = []
    seen_node_types = Counter()
    for obj in walk(workflow):
        node_type = obj.get("type")
        if not isinstance(node_type, str):
            continue
        if not ("widgets_values" in obj or "inputs" in obj or "outputs" in obj):
            continue
        seen_node_types[node_type] += 1
        props = obj.get("properties") or {}
        identifier = props.get("aux_id") or props.get("cnr_id")
        if identifier == "comfy-core" or node_type in BUILTIN_NODE_TYPES or UUID_RE.match(node_type):
            continue
        if node_type not in covered_node_types:
            missing_node_types.append(node_type)

    missing_node_types = sorted(set(missing_node_types))

    if missing_files:
        print("Workflow model-like files missing from manifests/models.json:", file=sys.stderr)
        for filename in missing_files:
            print(f"- {filename}", file=sys.stderr)
    if missing_node_types:
        print("Workflow custom node types missing from manifests/custom_nodes.json:", file=sys.stderr)
        for node_type in missing_node_types:
            print(f"- {node_type}", file=sys.stderr)

    print(f"Workflow audit passed. Node types: {len(seen_node_types)}; model-like files: {len(workflow_files)}")
    if missing_files or missing_node_types:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
