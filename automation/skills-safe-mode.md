# Skills 安全安装模式（Safe Install Mode）

目标：在不直接信任第三方 skills 的前提下，建立“拉取 -> 扫描 -> 人工审批 -> 白名单发布”的流程。

## 目录约定

- 隔离区（仅下载/扫描）：`/Users/jiahaozhe/.openclaw/workspace/.openclaw/skills-quarantine`
- 审批区（人工确认后）：`/Users/jiahaozhe/.openclaw/workspace/.openclaw/skills-approved`
- 白名单：`/Users/jiahaozhe/.openclaw/workspace/automation/skills-allowlist.txt`
- 扫描报告：`/Users/jiahaozhe/.openclaw/workspace/automation/skills-scan-reports/`

## 安全策略（最高优先）

1. 不从 third-party repo 直接安装到生产路径。
2. 固定 commit hash（禁止直接跟随 main 变更）。
3. 先扫描再审批：
   - 供应链：来源、作者、最近改动
   - 行为风险：`exec/curl/wget/bash -c/python -c/os.system/subprocess/eval` 等
   - 数据风险：上传/外传/读取敏感目录行为
4. 仅允许白名单 skill 发布到 approved 目录。
5. 升级时必须重新扫描并复核。

## 使用方式

```bash
bash automation/skills-safe-install.sh \
  --repo https://github.com/VoltAgent/awesome-openclaw-skills.git \
  --name awesome-openclaw-skills
```

执行后会产出：
- pinned commit 信息
- SKILL.md 清单
- 风险关键词命中清单
- 待人工审核列表

## 人工审批后发布

将通过审核的 skill 名称追加到：
`automation/skills-allowlist.txt`

然后手动把对应 skill 拷贝到 approved 目录（保持最小化发布）。
