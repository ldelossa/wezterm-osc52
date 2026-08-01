#!/usr/bin/env python3
"""Render the immutable Homebrew cask for a packaged release."""

import argparse
import hashlib
import pathlib
import re

parser = argparse.ArgumentParser()
parser.add_argument("--version", required=True)
parser.add_argument("--upstream-sha", required=True)
parser.add_argument("--archive", required=True, type=pathlib.Path)
parser.add_argument("--output", required=True, type=pathlib.Path)
args = parser.parse_args()

if not re.fullmatch(r"[0-9A-Za-z._-]+", args.version):
    parser.error("version contains unsupported characters")
if not re.fullmatch(r"[0-9a-f]{40}", args.upstream_sha):
    parser.error("upstream SHA must be a 40-character lowercase hexadecimal commit")

sha256 = hashlib.sha256(args.archive.read_bytes()).hexdigest()
template_path = pathlib.Path(__file__).with_name("wezterm-osc52.rb.template")
template = template_path.read_text(encoding="utf-8")
if (
    template.count("@VERSION@") != 1
    or template.count("@UPSTREAM_SHA@") != 1
    or template.count("@SHA256@") != 1
):
    raise SystemExit("cask template placeholders are invalid")

rendered = (
    template
    .replace("@VERSION@", args.version)
    .replace("@UPSTREAM_SHA@", args.upstream_sha)
    .replace("@SHA256@", sha256)
)
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(rendered, encoding="utf-8")
print(f"Wrote {args.output} with sha256 {sha256}")
