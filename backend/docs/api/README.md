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

## 2. 最小联调前提

从 `backend/` 目录执行：

```bash
cp .env.example .env
touch database/database.sqlite
composer install
php artisan key:generate
php artisan migrate --seed
php artisan serve
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
- `php artisan phase-one:diagnose --profile=interop`
- `php artisan phase-one:diagnose --profile=interop --json`

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

### phase-one 可验收

- `GET /readyz?profile=acceptance`
- `php artisan phase-one:diagnose --profile=acceptance`

会在“可联调”基础上增加：

- 后台管理员初始化
- 后台登录 session 前提

注意：

- `/readyz` 是运维与联调入口，不属于 phase-one 前台业务 OpenAPI 契约。
- `composer phase-one:acceptance` 当前会先执行 `php artisan phase-one:diagnose --profile=acceptance`，再跑定向验收测试。

## 5. 当前收口后的强相关口径

以下以真实 backend 代码为准：

- `POST /api/characters` 当前真实存在。
- `GET /api/inventory` 当前真实实现返回全量摘要，不返回 `pagination`；`page/page_size` 仅保留接收。
- `GET /api/chapters` 当前 seed 下 `chapter_desc`、`chapter_group`、`unlock_condition` 为 `null`。
- `GET /api/stages/{stage_id}/difficulties` 当前 seed 下 `stage_nanshan_001_normal` 与 `stage_nanshan_001_hard` 都绑定 `reward_first_clear_001`。
- 错误码必须以 `App\Support\ErrorCode` 与《错误码总表》为准。

## 6. 推荐联调顺序

1. `php artisan phase-one:diagnose --profile=service --json`
2. `php artisan phase-one:diagnose --profile=interop --json`
3. `php artisan workflow-lock:check --json`
4. `POST /api/characters`
5. `POST /api/characters/{character_id}/equip`
6. `POST /api/battles/prepare`
7. `POST /api/battles/settle`

完整闭环基线可直接参考：

- `backend/tests/Feature/Api/PhaseOnePlayerJourneySmokeTest.php`
