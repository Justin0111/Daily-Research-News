# Daily Brief Automation

## Pipeline

- `generate-brief.sh`：生成当天 `automation/daily-brief/latest.html`
- `publish-brief-to-github.sh`：发布到 `docs/daily/YYYY-MM-DD.html` 并推送 GitHub
- `run-daily-brief.sh`：统一编排（先生成再发布），带日志和状态文件

## Schedule

已安装 crontab：每天 `09:10` 自动执行

```cron
10 9 * * * /Users/jiahaozhe/.openclaw/workspace/automation/run-daily-brief.sh >> /Users/jiahaozhe/.openclaw/workspace/automation/logs/cron.log 2>&1
```

## Observability

- 运行总日志：`automation/logs/cron.log`
- 最近一次流水日志：`automation/logs/daily-brief-latest.log`
- 每次执行日志：`automation/logs/daily-brief-YYYY-MM-DD_HHMMSS.log`
- 状态文件：`automation/daily-brief/last-status.json`

## Manual Run

```bash
bash automation/run-daily-brief.sh --dry-run
bash automation/run-daily-brief.sh
```
