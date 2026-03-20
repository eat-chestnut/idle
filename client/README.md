# Phase-one Godot Client

## 目标

这是根目录 Godot 工程的第一批 phase-one 客户端接入入口。

当前只做一条最小可玩的真接口竖切：

1. backend 地址与 Bearer Token 配置
2. 角色创建
3. 角色详情
4. 背包读取
5. 穿戴槽读取 + equip / unequip
6. 章节列表
7. 难度列表 + 首通奖励状态
8. battle prepare
9. battle settle 结果

## 运行方式

1. 先启动 backend，并确保：
   - `GET /readyz?profile=acceptance` 可用
   - `php artisan phase-one:contract-drift-check --json` 通过
2. 打开仓库根目录 Godot 项目：
   - `/Users/mumu/game/idle/project.godot`
3. 运行主场景：
   - `res://client/scenes/PhaseOneClient.tscn`
4. 在“环境与 Token”页填写：
   - `Backend Base URL`
   - `Bearer Token`
5. 文档默认联调值：
   - `http://127.0.0.1:8000`
   - `test-token-2001`
   - `character_id = 1001`

## 当前联调链

推荐按这个顺序手工联调：

1. 环境与 Token
2. 角色
3. 背包
4. 穿戴
5. 章节与难度
6. Battle Prepare
7. Battle Settle

## 当前约束说明

- 当前 phase-one 公开接口没有正式 `stage list` 接口。
- 因此章节页会真实显示 `GET /api/chapters` 的结果，但读取难度仍需要显式提供 `stage_id`。
- 默认联调值使用当前文档和 seed 中稳定存在的 `stage_nanshan_001`。
- 当前真实 backend 的 `battle prepare / settle` 需要 `is_active=1` 的角色。
- 新建角色当前默认返回 `is_active=0`，所以客户端会把新角色同步到角色页/穿戴页，但 battle 页默认继续保留 seed 里的可战斗角色 `1001`。

## 页面状态

每个页面至少处理：

- loading
- success
- empty
- error
- unauthorized

战斗相关额外处理：

- preparing
- settling
- reward available / claimed
