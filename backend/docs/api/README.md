# 第一阶段前台 API 联调入口

## 1. 正式契约文件

- 契约产物：`backend/docs/api/phase-one-frontend.openapi.json`
- 口径来源：`backend/routes/api.php`、各 `ApiRequest`、各 `Resource`、现有 Feature Tests
- 认证方式：所有前台业务接口统一使用 `Authorization: Bearer <api_token>`

当前本地最小联调用测试 token：

- `Bearer test-token-2001`

该 token 对应 `DatabaseSeeder` 写入的测试用户 `users.id = 2001`。

## 2. 一键诊断

用于快速判断“现在是否可联调”：

```bash
php artisan phase-one:diagnose
php artisan phase-one:diagnose --json
```

诊断会检查：

- workflow lock 是否具备正式互斥能力
- `auth:api` 是否仍是 hash token guard
- 第一阶段前台 API 路由是否齐全且都挂了 `auth:api`
- 最小联调 seed 数据是否完整
- OpenAPI 契约文件是否存在且可解析

## 3. 当前收口后的强相关口径

以下以真实 backend 代码为准，已在 OpenAPI 示例中修正：

- `POST /api/characters` 当前真实存在，旧示例文档未覆盖；本轮已补入正式契约。
- `POST /api/characters` 在当前最小联调 seed 用户（`user_id = 2001`）下会创建“次角色”，返回 `is_active = 0`；只有该用户首个创建角色才会默认激活。
- `GET /api/inventory` 当前真实实现返回全量摘要，不返回 `pagination`；`page/page_size` 仅保留接收，不代表已启用正式分页。
- `GET /api/chapters` 当前真实 schema 下 `chapter_desc`、`chapter_group`、`unlock_condition` 示例应为 `null`，而不是旧文档中的扩展字段值。
- `GET /api/stages/{stage_id}/difficulties` 当前 seed 下 `stage_nanshan_001_normal` 与 `stage_nanshan_001_hard` 都绑定 `reward_first_clear_001`。
- 错误码必须以当前 `App\\Support\\ErrorCode` 与《错误码总表》为准：例如角色不存在是 `10101`，无权限访问角色是 `10102`，装备相关是 `102xx`，关卡相关是 `103xx`，结算相关是 `105xx`。
- 战斗示例中的怪物、属性和奖励示例值已切到当前最小 seed 数据口径，不再沿用旧示例中的历史占位值。

## 4. 最小联调建议顺序

1. `php artisan migrate:fresh --seed`
2. `php artisan phase-one:diagnose --json`
3. 先调用 `POST /api/characters`
4. 再调用 `POST /api/characters/{character_id}/equip`
5. 再调用 `POST /api/battles/prepare`
6. 最后调用 `POST /api/battles/settle`

如需一条真实闭环基线，可直接看 `backend/tests/Feature/Api/PhaseOnePlayerJourneySmokeTest.php`。
