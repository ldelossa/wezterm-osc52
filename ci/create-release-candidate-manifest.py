#!/usr/bin/env python3
"""Create a canonical inventory for a secretless macOS release candidate."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import unicodedata
import zipfile

SHA_RE = re.compile(r"[0-9a-f]{40}\Z")
DIGEST_RE = re.compile(r"[0-9a-f]{64}\Z")
VERSION_RE = re.compile(r"[0-9]{8}-[0-9]{6}-[0-9a-f]{8}-osc52\.[0-9]+\Z")
ID_RE = re.compile(r"[1-9][0-9]*\Z")
MAX_ARCHIVE_SIZE = 500 * 1024 * 1024
MAX_UNCOMPRESSED_SIZE = 2 * 1024 * 1024 * 1024
MAX_FILE_SIZE = 512 * 1024 * 1024
MAX_SYMLINK_SIZE = 4096
MAX_ENTRIES = 10_000
CHUNK_SIZE = 1024 * 1024

parser = argparse.ArgumentParser()
parser.add_argument("--archive", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--version", required=True)
parser.add_argument("--source-sha", required=True)
parser.add_argument("--tree-sha", required=True)
parser.add_argument("--upstream-sha", required=True)
parser.add_argument("--attestation-digest", required=True)
parser.add_argument("--repository-id", required=True)
parser.add_argument("--workflow-run-id", required=True)
parser.add_argument("--workflow-ref", required=True)
args = parser.parse_args()

for field in ("source_sha", "tree_sha", "upstream_sha"):
    if not SHA_RE.fullmatch(getattr(args, field)):
        parser.error(f"{field.replace('_', '-')} must be one full lowercase SHA-1")
if not DIGEST_RE.fullmatch(args.attestation_digest):
    parser.error("attestation-digest must be one lowercase SHA-256")
if not VERSION_RE.fullmatch(args.version):
    parser.error("version is not canonical")
if not ID_RE.fullmatch(args.repository_id) or not ID_RE.fullmatch(args.workflow_run_id):
    parser.error("repository and workflow run IDs must be canonical decimal strings")
if not re.fullmatch(r"ldelossa/wezterm-osc52/\.github/workflows/build-release-candidate\.yml@[0-9a-f]{40}", args.workflow_ref):
    parser.error("workflow-ref must bind the trusted workflow path to a full SHA")
if not args.archive.is_file():
    parser.error("archive does not exist")

archive_size = args.archive.stat().st_size
if archive_size < 1 or archive_size > MAX_ARCHIVE_SIZE:
    raise SystemExit("archive size is outside policy")
archive_hasher = hashlib.sha256()
with args.archive.open("rb") as source:
    while chunk := source.read(CHUNK_SIZE):
        archive_hasher.update(chunk)
entries = []
seen = set()
seen_casefolded = set()
total_size = 0
with zipfile.ZipFile(args.archive) as archive:
    infos = archive.infolist()
    if not infos or len(infos) > MAX_ENTRIES:
        raise SystemExit("archive entry count is outside policy")
    for item in sorted(infos, key=lambda value: value.filename.encode("utf-8")):
        name = item.filename
        try:
            name.encode("utf-8", errors="strict")
        except UnicodeEncodeError as exc:
            raise SystemExit("archive path contains invalid Unicode") from exc
        raw_name = name[:-1] if name.endswith("/") else name
        raw_parts = raw_name.split("/")
        normalized_name = unicodedata.normalize("NFC", raw_name)
        collision_key = normalized_name.casefold()
        if not raw_name or name.startswith("/") or "\\" in name or any(part in ("", ".", "..") for part in raw_parts):
            raise SystemExit(f"unsafe archive path: {name!r}")
        if raw_parts[0] != "WezTerm.app" or name in seen or collision_key in seen_casefolded:
            raise SystemExit("archive must contain one unique case-stable WezTerm.app tree")
        if item.flag_bits & 0x1:
            raise SystemExit("encrypted archive entries are forbidden")
        seen.add(name)
        seen_casefolded.add(collision_key)
        total_size += item.file_size
        if total_size > MAX_UNCOMPRESSED_SIZE:
            raise SystemExit("archive expands beyond policy")
        mode = (item.external_attr >> 16) & 0xFFFF
        if item.is_dir():
            if mode and not stat.S_ISDIR(mode):
                raise SystemExit("directory entry has an invalid file type")
            kind = "directory"
            digest = None
        elif stat.S_ISLNK(mode):
            kind = "symlink"
            if item.file_size > MAX_SYMLINK_SIZE:
                raise SystemExit("archive symlink target is too large")
            target = archive.read(item)
            try:
                target_text = target.decode("utf-8", errors="strict")
            except UnicodeDecodeError as exc:
                raise SystemExit("symlink target is not UTF-8") from exc
            target_parts = target_text.split("/")
            if not target_text or target_text.startswith("/") or "\\" in target_text or any(part in ("", ".", "..") for part in target_parts):
                raise SystemExit("archive symlink target is unsafe")
            digest = hashlib.sha256(target).hexdigest()
        else:
            if not stat.S_ISREG(mode):
                raise SystemExit("non-regular archive entries are forbidden")
            if item.file_size > MAX_FILE_SIZE:
                raise SystemExit("archive entry exceeds the per-file policy")
            kind = "file"
            entry_hasher = hashlib.sha256()
            with archive.open(item) as source:
                while chunk := source.read(CHUNK_SIZE):
                    entry_hasher.update(chunk)
            digest = entry_hasher.hexdigest()
        entries.append({
            "path": name,
            "kind": kind,
            "mode": f"{mode:06o}",
            "size": item.file_size,
            "sha256": digest,
        })

manifest = {
    "schema_version": 1,
    "source": {
        "repository_id": args.repository_id,
        "source_sha": args.source_sha,
        "tree_sha": args.tree_sha,
        "upstream_sha": args.upstream_sha,
        "attestation_digest": args.attestation_digest,
        "version": args.version,
    },
    "build": {
        "workflow_run_id": args.workflow_run_id,
        "workflow_ref": args.workflow_ref,
    },
    "archive": {
        "name": args.archive.name,
        "size": archive_size,
        "sha256": archive_hasher.hexdigest(),
        "entries": entries,
    },
}
encoded = (json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_bytes(encoded)
print(f"Wrote {args.output} with {len(entries)} inventoried entries")
