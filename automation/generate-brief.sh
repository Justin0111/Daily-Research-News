#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/Users/jiahaozhe/.openclaw/workspace"
OUT="$WORKSPACE/automation/daily-brief/latest.html"
TODAY="$(date +%F)"

python3 - "$OUT" "$TODAY" <<'PY'
import html
import re
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime

out_path = sys.argv[1]
today = sys.argv[2]

queries = [
    "multimodal pretraining",
    "video diffusion",
    "world model reinforcement learning",
    "vision-language-action",
    "diffusion acceleration",
    "quantization large model",
]

THEMES = {
    "多模态": ["multimodal", "vision-language", "vlm", "mllm"],
    "DiT/扩散": ["diffusion", "dit", "video generation", "image generation"],
    "世界模型/RL": ["world model", "reinforcement", "policy", "control"],
    "高效推理": ["quantization", "compression", "acceleration", "inference", "moe"],
    "VLA/机器人": ["vision-language-action", "robot", "manipulation", "embodied"],
}


base = "http://export.arxiv.org/api/query?"
ns = {"a": "http://www.w3.org/2005/Atom"}
seen = set()
items = []

for q in queries:
    url = base + urllib.parse.urlencode(
        {
            "search_query": f"all:{q}",
            "start": 0,
            "max_results": 8,
            "sortBy": "submittedDate",
            "sortOrder": "descending",
        }
    )
    data = urllib.request.urlopen(url, timeout=25).read()
    root = ET.fromstring(data)
    for e in root.findall("a:entry", ns):
        idurl = (e.find("a:id", ns).text or "").strip()
        key = idurl.split("/")[-1]
        if key in seen:
            continue
        seen.add(key)

        title = " ".join((e.find("a:title", ns).text or "").split())
        summary = " ".join((e.find("a:summary", ns).text or "").split())
        published = (e.find("a:published", ns).text or "")[:10]

        text = f"{title} {summary}".lower()
        themes = [name for name, kws in THEMES.items() if any(k in text for k in kws)] or ["其他"]

        importance = "学术上提供新的可验证思路；商业上可用于下一轮能力评估与落地选型。"
        if "quant" in text or "acceleration" in text or "inference" in text:
            importance = "学术上推进高效推理研究；商业上可直接降低部署成本与时延。"
        elif "robot" in text or "manipulation" in text or "vision-language-action" in text:
            importance = "学术上强化具身智能泛化证据；商业上利好机器人训练与场景落地。"
        elif "diffusion" in text or "video" in text:
            importance = "学术上扩展生成模型边界；商业上提升内容生产效率与质量。"

        items.append(
            {
                "published": published,
                "title": title,
                "url": idurl,
                "summary": summary,
                "themes": themes,
                "importance": importance,
            }
        )

items.sort(key=lambda x: x["published"], reverse=True)
items = items[:20]
if len(items) < 8:
    raise SystemExit("not enough papers fetched; abort generation")

# choose top3 by theme richness + title length heuristic
ranked = sorted(items, key=lambda x: (len(x["themes"]), len(x["title"])), reverse=True)
top3 = ranked[:3]

all_themes = sorted({t for it in items for t in it["themes"]})

def short_cn(s: str, n=56):
    s = re.sub(r"\s+", " ", s).strip()
    return s[:n] + ("…" if len(s) > n else "")

lis = []
for i, it in enumerate(items, 1):
    lis.append(
        f"<li><b>{html.escape(it['title'])}</b>：{html.escape(short_cn(it['summary'], 72))}<br/>"
        f"重要性：{html.escape(it['importance'])}<br/>"
        f"链接：<a href='{html.escape(it['url'])}'>arXiv</a>｜复现信号：论文公开，代码以作者仓库为准。"
        f"</li>"
    )

html_doc = f"""<!doctype html><html lang='zh'><head><meta charset='utf-8'><title>每日科研情报简报 {today}</title>
<style>body{{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;line-height:1.6;max-width:980px;margin:24px auto;padding:0 16px}}h1,h2{{margin:.4em 0}}li{{margin:.6em 0}}.meta{{color:#666}}</style></head>
<body><h1>每日科研情报简报（{today}）</h1>
<p class='meta'>覆盖：arXiv 最新论文自动聚合｜主题：{'/'.join(all_themes)}</p>
<h2>Top3 必读</h2><ol>
{''.join([f"<li><a href='{html.escape(x['url'])}'>{html.escape(x['title'])}</a></li>" for x in top3])}
</ol>
<h2>20条主简报</h2><ol>
{''.join(lis)}
</ol>
<h2>今日行动建议</h2>
<ul>
<li>优先精读 Top3，抽取可复现配置（数据、算力、评测）。</li>
<li>将“高效推理/世界模型/VLA”三条线分别建一个实验看板。</li>
<li>针对业务场景，标记 3 篇最有近期落地价值的论文做深读。</li>
</ul>
<p><b>反馈区：</b>请按编号回复“有用/一般/不相关”。</p>
</body></html>"""

with open(out_path, "w", encoding="utf-8") as f:
    f.write(html_doc)

print(f"[generate] wrote {out_path} with {len(items)} items at {datetime.now().isoformat(timespec='seconds')}")
PY
