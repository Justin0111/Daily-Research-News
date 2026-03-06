# HEARTBEAT.md

## Daily Brief Auto-Generation

On each heartbeat:

1. Ensure `memory/` exists.
2. If `memory/heartbeat-state.json` is missing, initialize it with:
   ```json
   { "lastDailyBriefDate": null }
   ```
3. Read `memory/heartbeat-state.json`.
4. If `lastDailyBriefDate` is not today (`YYYY-MM-DD`, Asia/Shanghai):
   - Create or append to `memory/<today>.md` under a `## 简讯` section.
   - Generate a concise daily brief (3-6 bullets) based on available context in this workspace/session.
   - Include generation time.
   - Update `memory/heartbeat-state.json` with today as `lastDailyBriefDate`.
   - Commit and push to GitHub so the brief is visible on the repo page:
     - `git add memory/<today>.md memory/heartbeat-state.json`
     - `git commit -m "chore: daily brief <today>"` (skip commit if no staged changes)
     - `git push origin main`
   - Send a short alert message that today's brief has been generated and pushed.
5. If today's brief already exists, do nothing and reply `HEARTBEAT_OK`.

Guardrails:
- Only generate once per calendar day.
- Do not overwrite existing user-written content.
- Keep each brief short and practical.
- Never run broad adds like `git add .`; only add the daily brief files.
- If push fails, report the error in chat and keep local files intact.
