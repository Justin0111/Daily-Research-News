# HEARTBEAT.md

## 每日简讯发布（GitHub Pages）

目标：保证打开 `https://justin0111.github.io/Daily-Research-News/` 时，能看到当天简讯。

在每次 heartbeat 执行：

1. 计算今天日期（Asia/Shanghai，`YYYY-MM-DD`）。
2. 检查 `docs/daily/<today>.html` 是否存在：
   - 若不存在：执行 `bash automation/run-daily-brief.sh`。
   - 若存在：不重复生成，回复 `HEARTBEAT_OK`。
3. 生成后校验：
   - `docs/daily/<today>.html` 存在；
   - `docs/index.html` 已包含当天入口（最新一期）；
   - 变更已 push 到 `origin/main`。
4. 成功后发送一句简短提示：
   - `今日简讯已发布：<today>`

失败处理：
- 若脚本/推送失败，直接回报错误摘要（不要沉默）。
- 不做破坏性回滚。

Guardrails:
- 每天只发布一次；若当天已存在则不重复发布。
- 只使用现有脚本，不手写替代发布逻辑。
