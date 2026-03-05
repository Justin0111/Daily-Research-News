#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/Users/jiahaozhe/.openclaw/workspace"
LOG_DIR="$WORKSPACE/automation/logs"
STATUS_FILE="$WORKSPACE/automation/daily-brief/last-status.json"
LOCK_FILE="$WORKSPACE/automation/daily-brief/.run.lock"
RUN_TS="$(date '+%F %T %z')"
RUN_ID="$(date '+%F_%H%M%S')"
LOG_FILE="$LOG_DIR/daily-brief-$RUN_ID.log"
LATEST_LOG="$LOG_DIR/daily-brief-latest.log"
DRY_RUN="${1:-}"

mkdir -p "$LOG_DIR" "$(dirname "$STATUS_FILE")"

if [[ -f "$LOCK_FILE" ]]; then
  echo "[$RUN_TS] [ERROR] lock exists: $LOCK_FILE" | tee -a "$LOG_FILE"
  exit 1
fi
trap 'rm -f "$LOCK_FILE"' EXIT
: > "$LOCK_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$RUN_TS] [START] run daily brief pipeline"

STEP="generate"
write_status() {
  python3 - "$STATUS_FILE" "$1" "$RUN_TS" "$LOG_FILE" "${2:-}" <<'PY'
import json, sys
path, ok, ts, log, step = sys.argv[1:6]
out = {"ok": ok == "true", "time": ts, "log": log}
if step:
    out["failedStep"] = step
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
PY
}

if ! bash "$WORKSPACE/automation/generate-brief.sh"; then
  write_status false "$STEP"
  cp "$LOG_FILE" "$LATEST_LOG"
  echo "[$RUN_TS] [FAIL] step=$STEP"
  exit 1
fi

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  write_status true
  cp "$LOG_FILE" "$LATEST_LOG"
  echo "[$RUN_TS] [OK] dry run finished"
  exit 0
fi

STEP="publish"
if ! bash "$WORKSPACE/automation/publish-brief-to-github.sh"; then
  write_status false "$STEP"
  cp "$LOG_FILE" "$LATEST_LOG"
  echo "[$RUN_TS] [FAIL] step=$STEP"
  exit 1
fi

write_status true
cp "$LOG_FILE" "$LATEST_LOG"
echo "[$RUN_TS] [OK] pipeline done"
