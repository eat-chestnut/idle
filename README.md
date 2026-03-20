# 《山海巡厄录》 / idle

当前仓库已进入第一阶段 backend 联调与部署收口阶段，正式实现与联调入口都以 `backend/` 真实代码为准，不再按“空工程初始化”理解仓库状态。

## 统一入口

- 项目总览：[`doc/项目总览.md`](/Users/mumu/game/idle/doc/项目总览.md)
- backend 启动、部署、诊断入口：[`backend/README.md`](/Users/mumu/game/idle/backend/README.md)
- phase-one API 联调与契约：[`backend/docs/api/README.md`](/Users/mumu/game/idle/backend/docs/api/README.md)
- 第一阶段测试与验收说明：[`doc/codex/第一阶段测试与验收说明.md`](/Users/mumu/game/idle/doc/codex/第一阶段测试与验收说明.md)
- 认证与接口公共规则：[`doc/codex/认证与接口公共规则.md`](/Users/mumu/game/idle/doc/codex/认证与接口公共规则.md)

## 仓库说明

- `backend/`
  Laravel backend、最小后台、诊断命令、验收脚本、OpenAPI 契约产物
- `doc/`
  当前阶段正式人读文档
- `CODEX.md` / `AGENTS.md`
  仓库协作规则与开发边界

## 最常用命令

```bash
cd backend
php artisan phase-one:diagnose --profile=interop --json
php artisan phase-one:diagnose --profile=acceptance --json
composer phase-one:acceptance
```
