#!/usr/bin/env python3
"""Wrap a lab's architecture body fragment in the shared house-style shell.

    ./scripts/make-doc.py labs/03-rds-multi-az --title "RDS Failover" \
        --artifact-out /path/to/scratchpad/lab03-architecture.html

Reads  LAB/docs/body.html   (everything that goes inside <div class="sheet">)
Writes LAB/docs/architecture.html  — a complete standalone printable page
       and optionally an artifact-ready copy with the wrapper tags stripped,
       since the Artifact runtime supplies its own <html>/<head>/<body>.

The shell lives in scripts/doc-shell.html so every lab's document shares one
palette and one set of SVG diagram classes.
"""
import argparse, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHELL = ROOT / "scripts" / "doc-shell.html"


def strip_wrapper(html: str) -> str:
    """Remove tags the Artifact runtime provides itself."""
    for pat in (r"<!DOCTYPE html>\s*", r"</?html[^>]*>\s*", r"</?head>\s*",
                r"</?body>\s*", r'<meta charset="utf-8">\s*',
                r'<meta name="viewport"[^>]*>\s*'):
        html = re.sub(pat, "", html, flags=re.I)
    return html.strip() + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("lab")
    ap.add_argument("--title", required=True)
    ap.add_argument("--artifact-out")
    args = ap.parse_args()

    lab = pathlib.Path(args.lab.rstrip("/"))
    body_file = lab / "docs" / "body.html"
    if not body_file.exists():
        sys.exit(f"no body fragment at {body_file}")

    page = (SHELL.read_text()
            .replace("{{TITLE}}", args.title)
            .replace("{{BODY}}", body_file.read_text().strip()))

    # A body fragment must not carry its own page scaffolding.
    for stray in ("<!doctype", "<html", "<head>", "<body>", '<div class="sheet">'):
        if stray in body_file.read_text().lower():
            sys.exit(f"body fragment should not contain {stray}")

    out = lab / "docs" / "architecture.html"
    out.write_text(page)
    print(f"wrote {out} ({len(page)} bytes)")

    if args.artifact_out:
        pathlib.Path(args.artifact_out).write_text(strip_wrapper(page))
        print(f"wrote {args.artifact_out}")


if __name__ == "__main__":
    main()
