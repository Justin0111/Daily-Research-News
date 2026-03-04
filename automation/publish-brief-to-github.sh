#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/Users/jiahaozhe/.openclaw/workspace"
BRIEF_DIR="$WORKSPACE/automation/daily-brief"
LATEST_HTML="$BRIEF_DIR/latest.html"
ARCHIVE_DIR="$BRIEF_DIR/archive"
DOCS_DIR="$WORKSPACE/docs"
DAILY_DIR="$DOCS_DIR/daily"
WEEKLY_DIR="$DOCS_DIR/weekly"
MANIFEST="$DOCS_DIR/manifest.json"

if [[ ! -f "$LATEST_HTML" ]]; then
  echo "[publish] latest brief not found: $LATEST_HTML" >&2
  exit 1
fi

TODAY="$(date +%F)"
TARGET_HTML="$DAILY_DIR/$TODAY.html"

mkdir -p "$DAILY_DIR" "$ARCHIVE_DIR" "$WEEKLY_DIR"
cp "$LATEST_HTML" "$TARGET_HTML"
cp "$LATEST_HTML" "$ARCHIVE_DIR/$TODAY.html"

python3 - "$DOCS_DIR" "$TODAY" <<'PY'
import json
import re
import html
from datetime import datetime, timedelta
from pathlib import Path
import sys

docs_dir = Path(sys.argv[1])
today = sys.argv[2]
daily_dir = docs_dir / "daily"
weekly_dir = docs_dir / "weekly"
weekly_dir.mkdir(parents=True, exist_ok=True)

THEMES = {
    "多模态": ["multimodal", "mllm", "mmlm", "mllm", "vlm", "vla", "跨模态", "多模态"],
    "DiT/扩散": ["dit", "diffusion", "扩散", "生成式", "image editing", "视频生成"],
    "微调/对齐": ["sft", "rlhf", "dpo", "peft", "微调", "对齐"],
    "世界模型/RL": ["world model", "世界模型", "reinforcement", "rl", "policy", "agent"],
    "高效推理": ["quant", "moe", "compression", "acceleration", "inference", "蒸馏", "量化", "推理"],
}

def parse_day(path: Path):
    raw = path.read_text(encoding="utf-8", errors="ignore")
    text = re.sub(r"<[^>]+>", " ", raw)
    text = re.sub(r"\s+", " ", text).strip().lower()
    themes = []
    for name, kws in THEMES.items():
        if any(k.lower() in text for k in kws):
            themes.append(name)
    if not themes:
        themes = ["其他"]

    top3 = []
    m = re.search(r"top3[^\n:：]*[\s\S]{0,1200}", raw, re.IGNORECASE)
    if m:
        block = m.group(0)
        candidates = re.findall(r"(?:\n|^)[0-9]+[\)\.、:：\-\s]+([^\n<]{6,160})", block)
        top3 = [c.strip() for c in candidates[:3]]

    return {
        "date": path.stem,
        "path": f"daily/{path.name}",
        "themes": themes,
        "top3": top3,
    }

entries = []
for p in sorted(daily_dir.glob("*.html"), reverse=True):
    if re.match(r"\d{4}-\d{2}-\d{2}", p.stem):
        entries.append(parse_day(p))

history_path = docs_dir / "history.json"
history_path.write_text(json.dumps({"entries": entries}, ensure_ascii=False, indent=2), encoding="utf-8")

latest = entries[0]["path"] if entries else ""
updated = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

# weekly summary (rolling 7 days)
today_dt = datetime.strptime(today, "%Y-%m-%d")
window_start = today_dt - timedelta(days=6)
window = [e for e in entries if window_start.strftime("%Y-%m-%d") <= e["date"] <= today]

theme_counts = {}
for e in window:
    for t in e["themes"]:
        theme_counts[t] = theme_counts.get(t, 0) + 1

iso_year, iso_week, _ = today_dt.isocalendar()
weekly_slug = f"{iso_year}-W{iso_week:02d}"
weekly_file = weekly_dir / f"{weekly_slug}.html"

rows = "\n".join(
    f'<li><a href="../{html.escape(e["path"])}">{e["date"]}</a> · 主题：{html.escape(", ".join(e["themes"]))}</li>'
    for e in window
)
if not rows:
    rows = "<li>本周暂无数据</li>"

theme_list = "\n".join(
    f"<li>{html.escape(k)}：{v} 天</li>" for k, v in sorted(theme_counts.items(), key=lambda kv: (-kv[1], kv[0]))
) or "<li>暂无统计</li>"

weekly_html = f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>周报总结 {weekly_slug}</title>
<style>body{{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;max-width:900px;margin:2rem auto;padding:0 1rem;line-height:1.7}}
.card{{border:1px solid #ddd;border-radius:12px;padding:1rem 1.2rem;margin-bottom:1rem}}</style></head>
<body>
<h1>每周科研简报总结（{weekly_slug}）</h1>
<div class="card"><h2>主题热度（近7天）</h2><ul>{theme_list}</ul></div>
<div class="card"><h2>本周简报列表</h2><ul>{rows}</ul></div>
<p><a href="../index.html">返回首页</a></p>
</body></html>'''
weekly_file.write_text(weekly_html, encoding="utf-8")

# index with theme filter
chips = sorted({t for e in entries for t in e["themes"]})
chip_html = '<button class="chip active" data-theme="ALL">全部</button>' + ''.join(
    f'<button class="chip" data-theme="{html.escape(t)}">{html.escape(t)}</button>' for t in chips
)

cards = []
for e in entries[:90]:
    tags = " ".join(e["themes"])
    top = "；".join(e["top3"][:2]) if e["top3"] else ""
    cards.append(
        f'<li class="item" data-themes="{html.escape(tags)}">'
        f'<a href="./{html.escape(e["path"])}"><strong>{e["date"]}</strong></a>'
        f'<div class="meta">主题：{html.escape(tags)}</div>'
        f'<div class="top">{html.escape(top)}</div>'
        f'</li>'
    )

index_html = f'''<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>每日科研简报</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 2rem auto; max-width: 980px; padding: 0 1rem; }}
    .card {{ padding: 1rem 1.2rem; border: 1px solid #ddd; border-radius: 12px; margin-bottom: 1rem; }}
    .chips {{ display:flex; gap:.5rem; flex-wrap: wrap; margin:.6rem 0 1rem; }}
    .chip {{ border:1px solid #ccc; background:#fff; border-radius:999px; padding:.35rem .7rem; cursor:pointer; }}
    .chip.active {{ background:#0b57d0; color:#fff; border-color:#0b57d0; }}
    ul {{ padding-left: 1.1rem; }}
    .item {{ margin-bottom: .85rem; }}
    .meta {{ color:#666; font-size:.92rem; margin-top:.15rem; }}
    .top {{ color:#333; font-size:.92rem; margin-top:.1rem; }}
    a {{ color:#0b57d0; text-decoration:none; }}
    a:hover {{ text-decoration:underline; }}
  </style>
</head>
<body>
  <div class="card">
    <h1>每日科研简报</h1>
    <p>最新一期：<a href="./{latest}">{today}</a></p>
    <p>周报总结：<a href="./weekly/{weekly_slug}.html">{weekly_slug}</a></p>
  </div>

  <div class="card">
    <h2>按主题筛选</h2>
    <div class="chips" id="chips">{chip_html}</div>
    <ul id="list">{''.join(cards)}</ul>
  </div>

<script>
const chips = document.querySelectorAll('.chip');
const items = document.querySelectorAll('.item');
chips.forEach(btn => btn.addEventListener('click', () => {{
  chips.forEach(x => x.classList.remove('active'));
  btn.classList.add('active');
  const t = btn.dataset.theme;
  items.forEach(li => {{
    const themes = li.dataset.themes || '';
    li.style.display = (t === 'ALL' || themes.includes(t)) ? '' : 'none';
  }});
}}));
</script>
</body>
</html>'''

(docs_dir / "index.html").write_text(index_html, encoding="utf-8")

manifest = {
    "latest": latest,
    "weekly": f"weekly/{weekly_slug}.html",
    "updatedAt": updated,
    "days": len(entries),
}
(docs_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
PY

cd "$WORKSPACE"

git add docs "$ARCHIVE_DIR/$TODAY.html" automation/publish-brief-to-github.sh
if git diff --cached --quiet; then
  echo "[publish] no changes to commit"
  exit 0
fi

git commit -m "feat(brief): add theme filter + weekly summary"
git push

echo "[publish] done: $TODAY"
