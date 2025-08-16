#!/bin/bash
set -euo pipefail

SRC_DIR="debian/inotibatch.docs"
DST_DIR="debian/tmp/usr/share/man/man1"

rm -rf "$DST_DIR" || true

mkdir -p "$DST_DIR"

echo "Process all Markdown files from ${SRC_DIR}"

for file in ${SRC_DIR}/*.md; do \
  filename=$(basename "$file" .md); \
  pandoc -s "$file" -t man -o "$DST_DIR/$filename"; \
  echo "Converted $file → $DST_DIR/$filename"; \
done
