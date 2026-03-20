# Phase-one Godot Client

## 目标

这是根目录 Godot 工程下的 phase-one 第二轮客户端接入。

本轮仍然只做真实 backend 联调，不做本地 mock 成功页；并把上一轮“临时兼容选择流”切到真实接口驱动：

1. 页面拆分为独立分页脚本
2. 角色 / chapter / stage / difficulty 选择流程收口
3. battle prepare / settle 上下文自动承接
4. 补 `/readyz` 联调预检入口
5. 角色激活动作接入真实 backend 接口

## 当前结构

- 主场景：`res://client/scenes/PhaseOneClient.tscn`
- 主协调器：`res://client/scripts/phase_one_client.gd`
- API 封装：`res://client/scripts/backend_api.gd`
- 配置存储：`res://client/scripts/client_config_store.gd`
- 分页脚本：
  - `res://client/scripts/pages/phase_one_config_page.gd`
  - `res://client/scripts/pages/phase_one_character_page.gd`
  - `res://client/scripts/pages/phase_one_inventory_page.gd`
  - `res://client/scripts/pages/phase_one_equipment_page.gd`
  - `res://client/scripts/pages/phase_one_stage_page.gd`
  - `res://client/scripts/pages/phase_one_prepare_page.gd`
  - `res://client/scripts/pages/phase_one_settle_page.gd`

## 当前真实口径

- 当前已提供 `GET /api/characters`，客户端会读取当前用户真实角色列表。
- 当前已提供 `GET /api/chapters/{chapter_id}/stages`，客户端会先选章节，再读取章节下真实关卡列表。
- `GET /api/chapters` 仍只返回章节，不直接返回 `stage_id`。
- 新建角色在当前真实实现下通常默认 `is_active=0`；battle prepare / settle 仍要求使用可战斗角色。
- 当前已提供 `POST /api/characters/{character_id}/activate`，客户端可在角色页或 Prepare 页切换当前启用角色。

因此本客户端当前的主流程是：

- 角色选择优先来自真实角色列表
- 关卡选择优先来自真实章节/关卡列表
- 最近成功记录只作为兜底兼容，不再作为主流程真相

## 运行方式

1. 启动 backend，并确保 phase-one 联调前提可用。
2. 打开仓库根目录 Godot 工程：
   - `/Users/mumu/game/idle/project.godot`
3. 运行主场景：
   - `res://client/scenes/PhaseOneClient.tscn`
4. 在“环境与 Token”页填写或使用默认值：
   - `Backend Base URL`
   - `Bearer Token`
5. 先点击：
   - `联调预检 /readyz`
6. 再按主链逐步联调。

默认联调值：

- `http://127.0.0.1:8000`
- `test-token-2001`
- `character_id = 1001`
- `stage_id = stage_nanshan_001`
- `stage_difficulty_id = stage_nanshan_001_normal`

## 推荐联调顺序

1. 环境与 Token
   - 先跑 `/readyz` 预检
   - 再用“探测章节接口”验证保护接口 + token
2. 角色
   - 先读取真实角色列表
   - 创建角色或读取已有角色
   - 若目标角色 `is_active=0`，先调用激活接口
3. 背包
   - 读取背包
   - 直接从装备实例列表跳到穿戴页
4. 穿戴
   - 读取槽位
   - 选择槽位并 equip / unequip
5. 章节与难度
   - 读取章节
   - 读取当前章节关卡
   - 选择真实 `stage_id` 后读取难度
   - 选择难度并刷新首通奖励状态
6. Battle Prepare
   - 选择真实角色列表中的可战斗角色
   - 直接承接已选难度执行 prepare
7. Battle Settle
   - 自动承接 `battle_context_id`
   - 可一键填入 prepare 阶段的 monster 列表

## 页面状态

每个页面继续保证：

- loading
- success
- empty
- error
- unauthorized

战斗页额外保证：

- preparing / settling
- battle_context 自动承接
- reward status 以后端返回为准

## 本地最小验证

脚本和场景的本地 smoke check：

```bash
godot --headless --path /Users/mumu/game/idle --quit
godot --headless --path /Users/mumu/game/idle res://client/scenes/PhaseOneClient.tscn --quit-after 1
```

backend 联调前建议先确认：

```bash
cd /Users/mumu/game/idle/backend
php artisan phase-one:diagnose --profile=interop --json
curl http://127.0.0.1:8000/readyz
```

## 本轮体验改进点

- 页面不再全部堆在一个脚本里，主脚本只负责编排与跨页同步。
- 角色页会先读取真实角色列表，再驱动详情、穿戴和 battle 角色选择。
- 章节页会先读取章节，再读取章节下的真实关卡列表，不再以手输 `stage_id` 为主流程。
- 角色页和 Prepare 页都可以直接调用真实激活接口，减少 `is_active=0` 导致的 prepare 失败。
- prepare 成功后会自动同步：
  - `battle_context_id`
  - `stage_difficulty_id`
  - `killed_monsters`
- 配置页新增 `/readyz` 联调预检入口。
