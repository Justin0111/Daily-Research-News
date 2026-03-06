#!/usr/bin/env bash
set -euo pipefail

REPO=""
NAME=""
WORKSPACE="/Users/jiahaozhe/.openclaw/workspace"
QUARANTINE="$WORKSPACE/.openclaw/skills-quarantine"
REPORT_DIR="$WORKSPACE/automation/skills-scan-reports"
ALLOWLIST="$WORKSPACE/automation/skills-allowlist.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$REPO" || -z "$NAME" ]]; then
  echo "Usage: $0 --repo <git-url> --name <local-name>"
  exit 1
fi

mkdir -p "$QUARANTINE" "$REPORT_DIR" "$(dirname "$ALLOWLIST")"
[[ -f "$ALLOWLIST" ]] || touch "$ALLOWLIST"

TARGET="$QUARANTINE/$NAME"
rm -rf "$TARGET"

echo "[safe-mode] cloning into quarantine: $TARGET"
git clone --depth 1 "$REPO" "$TARGET" >/dev/null

cd "$TARGET"
PINNED_COMMIT="$(git rev-parse HEAD)"
TS="$(date '+%Y-%m-%d_%H%M%S')"
REPORT="$REPORT_DIR/${NAME}_${TS}.md"

SKILL_FILES=$(find . -type f -name 'SKILL.md' | sort || true)
SKILL_COUNT=$(printf "%s\n" "$SKILL_FILES" | sed '/^$/d' | wc -l | tr -d ' ')

{
  echo "# Skills Scan Report"
  echo
  echo "- Repo: $REPO"
  echo "- Local: $TARGET"
  echo "- Pinned commit: $PINNED_COMMIT"
  echo "- Time: $(date '+%F %T %z')"
  echo "- SKILL.md count: $SKILL_COUNT"
  echo
  echo "## SKILL.md files"
  if [[ -n "$SKILL_FILES" ]]; then
    printf "%s\n" "$SKILL_FILES"
  else
    echo "(none found)"
  fi
  echo
  echo "## Heuristic Risk Hits"
  echo "Patterns: exec|process|curl|wget|bash -c|python -c|subprocess|os.system|eval|token|secret|password|ssh|scp|rsync|upload|webhook"
  echo
} > "$REPORT"

# search all text-ish files
if command -v grep >/dev/null 2>&1; then
  grep -RInE "exec|process|curl|wget|bash -c|python -c|subprocess|os\.system|eval\(|token|secret|password|ssh|scp|rsync|upload|webhook" . \
    --exclude-dir=.git \
    --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.gif' --exclude='*.webp' \
    >> "$REPORT" || true
fi

{
  echo
  echo "## Decision"
  echo "- Default: DO NOT auto-install."
  echo "- Next: manually review report + source, then add approved skill names to: $ALLOWLIST"
  echo "- Publish target (manual copy only): $WORKSPACE/.openclaw/skills-approved"
} >> "$REPORT"

echo "[safe-mode] report: $REPORT"
echo "[safe-mode] pinned commit: $PINNED_COMMIT"
