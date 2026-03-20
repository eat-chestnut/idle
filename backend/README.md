# 《山海巡厄录》backend

当前 `backend/` 已包含第一阶段正式主链、battle context 持久化、failed reward_grant 沉淀与补发、最小后台、OpenAPI 契约产物、统一诊断入口与验收脚本。本 README 只收口当前真实代码可执行的联调与部署入口，不扩写未来系统。

## 快速入口

- 项目总览：`/doc/项目总览.md`
- phase-one 联调与契约入口：`/backend/docs/api/README.md`
- 第一阶段测试与验收说明：`/doc/codex/第一阶段测试与验收说明.md`
- 认证与公共规则：`/doc/codex/认证与接口公共规则.md`

## 最低运行环境

- PHP `^8.2`
- Composer
- 一个可用数据库
  - 本地最小启动推荐 SQLite
  - 部署可使用 MySQL / MariaDB / PostgreSQL 等 Laravel 已配置驱动
- phase-one 最小环境变量以 [`backend/.env.example`](/Users/mumu/game/idle/backend/.env.example) 为准，至少需要确认：
  - `APP_KEY`
  - `DB_*`
  - `CACHE_STORE`
  - `WORKFLOW_LOCK_STORE`
  - `SESSION_DRIVER`
  - `QUEUE_CONNECTION`
  - `MAIL_MAILER`
  - `CORS_ALLOWED_ORIGINS`

当前仓库不自带 `sessions` / `jobs` / `cache` 等 Laravel 通用表的 migration，所以如果你把 `SESSION_DRIVER`、`QUEUE_CONNECTION`、`CACHE_STORE` 或 `WORKFLOW_LOCK_STORE` 切到 `database`，需要自行补对应 Laravel 表；否则请保持当前最小推荐值：

```env
DB_CONNECTION=sqlite
DB_DATABASE=database/database.sqlite
SESSION_DRIVER=file
QUEUE_CONNECTION=sync
MAIL_MAILER=log
CACHE_STORE=file
WORKFLOW_LOCK_STORE=file
```

说明：

- `WORKFLOW_LOCK_STORE=file` 只适合单机联调或单机部署；多实例部署请改为 `redis` 等共享 store。
- phase-one 前台 API 当前使用 Bearer Token，不依赖 cookie 鉴权，所以 CORS 只需要覆盖前台 origin，不需要开启跨域凭证。

## 本地最小启动

```bash
cd backend
cp .env.example .env
touch database/database.sqlite
composer install
php artisan key:generate
php artisan migrate --seed
php artisan serve
```

如果不是 SQLite，请先把 `.env` 内 `DB_*` 改成真实数据库，再执行 `php artisan migrate --seed`。

## 联调账号与后台初始化

执行 `DatabaseSeeder` 后会自动得到：

- 前台联调用户：`users.id = 2001`
- 前台联调 token：`Authorization: Bearer test-token-2001`
- 后台管理员：`admin / admin123456`

后台登录入口：`/admin`

## 存活 / ready / 验收

### 1. 服务存活

- `GET /up`

这是 Laravel 内置 liveness probe，只表示应用进程已起来，不代表 phase-one 已可联调。

### 2. phase-one 可联调

- HTTP：`GET /readyz`
- CLI：`php artisan phase-one:diagnose --profile=interop --json`

这层会检查：

- `APP_KEY`
- 数据库连通
- `auth:api` Bearer Token guard
- CORS 最小配置
- workflow lock 能力
- phase-one 前台路由保护
- 最小 seed 数据
- OpenAPI 契约文件

### 3. phase-one 可验收

- HTTP：`GET /readyz?profile=acceptance`
- CLI：`php artisan phase-one:diagnose --profile=acceptance --json`
- 全量入口：`composer phase-one:acceptance`

验收级检查会在“可联调”基础上额外检查：

- 后台管理员是否已初始化
- 后台登录所需 session 驱动是否可用

## 推荐联调顺序

```bash
cd backend
php artisan phase-one:diagnose --profile=service --json
php artisan phase-one:diagnose --profile=interop --json
php artisan workflow-lock:check --json
php artisan test tests/Feature/Api/PhaseOnePlayerJourneySmokeTest.php
```

如需完整验收：

```bash
composer phase-one:acceptance
```

## 说明边界

- `/readyz` 是部署与联调诊断入口，不属于 phase-one 前台业务 OpenAPI 契约。
- phase-one 当前不依赖异步队列和邮件发送，`QUEUE_CONNECTION=sync`、`MAIL_MAILER=log` 即可满足最小联调与部署要求。
- 如果诊断、测试、文档三者出现冲突，应优先以 `backend/` 真实代码与定向测试结果为准，再回写根目录文档。
