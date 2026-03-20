# 第一阶段前台 API 联调入口

## 1. 契约与文档分工

- 机器可读契约：`backend/docs/api/phase-one-frontend.openapi.json`
- 真实口径来源：`backend/routes/api.php`、各 `ApiRequest`、各 `Resource`、当前 Feature Tests
- 前台认证方式：`Authorization: Bearer <api_token>`
- 根目录人读示例：`doc/codex/接口示例文档.md`
- 根目录公共规则：`doc/codex/认证与接口公共规则.md`
- 启动 / 部署 / ready 入口：`backend/README.md`
- 测试矩阵与验收说明：`doc/codex/第一阶段测试与验收说明.md`

维护顺序仍然是：

1. 先改 backend 真实实现
2. 再改测试与 OpenAPI
3. 最后回写根目录文档

其中主次关系固定为：

1. backend 真实代码（`routes / ApiRequest / Resource / Feature Tests`）是第一真相
2. `backend/docs/api/phase-one-frontend.openapi.json` 是随真实代码同步维护的机器契约产物
3. `doc/codex/接口示例文档.md` 是只保留稳定正式接口的人读文档，不单独定义新规则

## 2. 最小联调前提

以下命令默认从仓库根目录执行：

```bash
cp ./backend/.env.example ./backend/.env
touch ./backend/database/database.sqlite
composer --working-dir=./backend install
php ./backend/artisan key:generate
php ./backend/artisan migrate --seed
php ./backend/artisan serve
```

如果不是 SQLite，请先把 `.env` 中 `DB_*` 改成真实数据库。

当前 `.env.example` 的最小推荐值已经按 phase-one 收口：

- `SESSION_DRIVER=file`
- `QUEUE_CONNECTION=sync`
- `MAIL_MAILER=log`
- `CACHE_STORE=file`
- `WORKFLOW_LOCK_STORE=file`

说明：

- 单机联调用 `file` lock 即可。
- 多实例部署请把 `WORKFLOW_LOCK_STORE` 改为共享 store，例如 `redis`。
- `CORS_ALLOWED_ORIGINS` 需要改成真实前端域名列表；本地默认已覆盖常见 `localhost:3000/5173`。

## 3. 联调 token 与后台账号

- Bearer Token：`test-token-2001`
- 对应用户：`users.id = 2001`
- 后台管理员：`admin / admin123456`

这些账号都由 `DatabaseSeeder` 初始化。

## 4. 存活 / ready / diagnose

### 服务存活

- `GET /up`

只判断应用是否已经启动，不检查 phase-one 配置、seed、lock。

### phase-one 可联调

- `GET /readyz`
- `php ./backend/artisan phase-one:diagnose --profile=interop`
- `php ./backend/artisan phase-one:diagnose --profile=interop --json`
- `php ./backend/artisan phase-one:contract-drift-check --json`

检查项包括：

- `APP_KEY`
- 数据库连通
- runtime 最小依赖摘要
- workflow lock
- `auth:api`
- API CORS
- phase-one 路由保护
- 最小 seed 数据
- OpenAPI 契约文件

其中 `phase-one:contract-drift-check` 额外用于发版守门，会同时检查：

- 真实前台路由与 OpenAPI 是否同步
- `ApiRequest` 字段与 OpenAPI path / query / body 是否同步
- 根目录正式接口文档是否仍只保留真实存在的 phase-one 接口
- Bearer Token 与 `code/message/data` 统一响应外壳是否漂移

### phase-one 可验收

- `GET /readyz?profile=acceptance`
- `php ./backend/artisan phase-one:diagnose --profile=acceptance`

会在“可联调”基础上增加：

- 后台管理员初始化
- 后台登录 session 前提

注意：

- `/readyz` 是运维与联调入口，不属于 phase-one 前台业务 OpenAPI 契约。
- `composer --working-dir=./backend phase-one:acceptance` 当前会先执行 `php ./backend/artisan phase-one:diagnose --profile=acceptance`，再跑定向验收测试。

## 5. 当前收口后的强相关口径

以下以真实 backend 代码为准：

- `POST /api/characters` 当前真实存在。
- `GET /api/characters` 当前真实返回当前认证用户名下全部角色，不引入分页。
- `POST /api/characters/{character_id}/activate` 当前真实会切换当前用户唯一启用角色。
- `GET /api/inventory` 当前真实实现返回全量摘要，不返回 `pagination`；`page/page_size` 仅保留接收。
- `GET /api/chapters` 当前 seed 下 `chapter_desc`、`chapter_group`、`unlock_condition` 为 `null`。
- `GET /api/chapters/{chapter_id}/stages` 当前真实返回章节下启用关卡列表，不引入额外筛选。
- `GET /api/stages/{stage_id}/difficulties` 当前 seed 下 `stage_nanshan_001_normal` 与 `stage_nanshan_001_hard` 都绑定 `reward_first_clear_001`。
- 当前角色创建真实行为为：首个角色默认激活，后续角色默认 `is_active=0`；battle 仍要求使用启用角色。
- 错误码必须以 `App\Support\ErrorCode` 与《错误码总表》为准。

## 6. 推荐联调顺序

1. `php ./backend/artisan phase-one:diagnose --profile=service --json`
2. `php ./backend/artisan phase-one:diagnose --profile=interop --json`
3. `php ./backend/artisan phase-one:contract-drift-check --json`
4. `php ./backend/artisan workflow-lock:check --json`
5. `GET /api/characters`
6. `POST /api/characters`
7. `POST /api/characters/{character_id}/activate`
8. `GET /api/chapters`
9. `GET /api/chapters/{chapter_id}/stages`
10. `GET /api/stages/{stage_id}/difficulties`
11. `POST /api/characters/{character_id}/equip`
12. `POST /api/battles/prepare`
13. `POST /api/battles/settle`

完整闭环基线可直接参考：

- `backend/tests/Feature/Api/PhaseOnePlayerJourneySmokeTest.php`
