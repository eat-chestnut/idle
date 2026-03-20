

# AGENTS.md

## Scope of this file

This file applies to all work under `backend/`.

This directory is the Laravel backend and admin workspace for **《山海巡厄录》**.
Unless a task explicitly requires cross-directory work, only modify files under `backend/`.
Do not change root-level gameplay code when implementing backend, admin, API, Seeder, migration, model, or service tasks.

If instructions conflict:
- follow the nearest `AGENTS.md`
- then follow the repository root `AGENTS.md`
- then follow task-specific prompt instructions

---

## Backend mission

The backend exists to support the phase-one formal game chains.
The current priority is not feature expansion. The priority is:

1. correct structure
2. correct data state
3. correct workflow boundaries
4. stable API contracts
5. minimal but usable debug data

Do not proactively expand future systems.

---

## Backend source of truth

When backend design decisions are needed, use this priority:

1. `项目总览.md`
2. `doc/codex/Codex 主开发协作清单.md`
3. `doc/codex/Laravel 代码目录与命名规范.md`
4. `doc/codex/认证与接口公共规则.md`
5. `doc/codex/错误码总表.md`
6. `doc/codex/枚举总表.md`
7. `doc/codex/最小联调种子数据.md`
8. method-level design docs under `开发思路/`
9. `开发思路/接口字段级设计.md`
10. `doc/codex/接口示例文档.md`

If schema, model, migration, and docs differ:
- do not silently invent a new business rule
- first identify the mismatch
- adapt to the real backend schema if needed
- keep business semantics aligned with docs
- report the mismatch clearly in your summary

---

## Phase-one backend scope

You may implement only the formal phase-one backend scope:

- config read chain
- player state write chain
- character create chain
- equipment wear / unequip chain
- battle prepare chain
- battle settlement chain
- drop resolve chain
- reward grant chain
- inventory write chain
- first-phase API endpoints
- first-phase admin resources and query pages
- minimal debug seeders
- tests and validation for the above

You must NOT proactively implement:

- enhance system
- wash / reroll system
- gem system
- set system
- scripture system
- world level
- shop system
- event / operation system
- large-scale live content
- unrelated frontend or gameplay runtime code
- speculative generic frameworks

---

## Laravel architecture rules

Use the formal **five-layer** backend structure only:

1. Config
2. Query
3. Domain
4. Workflow
5. Admin

### Config
- read static configuration
- no state mutation
- no transaction orchestration
- no full workflow logic

### Query
- read formal state
- no hidden writes
- no full workflow orchestration

### Domain
- execute single business actions or domain rules
- no controller-style request formatting
- no giant all-in-one workflow replacement

### Workflow
- orchestrate full flows
- own transaction boundaries
- coordinate Config / Query / Domain services
- do not re-implement every low-level rule inline

### Admin
- admin validation
- reference checks
- repair tools
- retry tools
- do not bypass formal player workflows without explicit task approval

---

## Backend directory rules

Follow `doc/codex/Laravel 代码目录与命名规范.md`.

General rules:
- organize by business domain first, then by layer
- prefer clear class names over generic names
- controllers stay thin
- requests do basic input validation only
- resources or response builders must keep API output stable
- enums, exceptions, DTOs, support classes must live in their defined locations

Do not create vague classes like:
- `GameService`
- `CommonService`
- `HelperService`
- `MainService`
- `AllInOneService`

---

## Backend data boundary rules

### Template vs instance
Always keep these separated:
- `items` are templates
- `equipments` are equipment templates
- `inventory_stack_items` are owned stackable states
- `inventory_equipment_instances` are owned equipment instances
- `reward_groups` are templates
- `user_reward_grants` and `user_reward_grant_items` are formal records

Never:
- write player-owned quantities back to templates
- wear equipment templates directly
- treat reward templates as grant records

### Drop vs reward
Keep these separated:
- drop chain = monster-based random drop resolution
- reward chain = fixed grant based on formal reward source

Never:
- merge monster drop into first-clear reward logic
- fake fixed reward as drop result
- bypass inventory write by directly mutating owned state tables from settlement code

### Inventory write
Inventory write is the only formal inbound ownership path.
- stackable items must go to stack inventory
- equipment objects must be instantiated first
- do not claim success if part of the ownership write failed

---

## API rules for backend

Follow:
- `开发思路/接口字段级设计.md`
- `doc/codex/接口示例文档.md`
- `doc/codex/认证与接口公共规则.md`
- `doc/codex/错误码总表.md`
- `doc/codex/枚举总表.md`

### Authentication
- frontend business APIs use bearer token auth
- current user must come from auth context
- never trust frontend-provided `user_id`

### Request / response
- use `snake_case`
- success wrapper: `code = 0`, `message = "ok"`, `data = ...`
- failure wrapper: formal error code, short message, `data = null`
- use stable enum values only
- use formal error codes only

### Pagination
If an endpoint is paginated:
- request fields: `page`, `page_size`
- response fields: `list`, `pagination`

### Time fields
Use stable string fields such as:
- `created_at`
- `updated_at`
- `granted_at`

Preferred format:
- `YYYY-MM-DD HH:mm:ss`

---

## Seeder and debug data rules

When working under `backend/` on seeders or debug data:

- follow `doc/codex/最小联调种子数据.md`
- use fixed business IDs from the doc
- prefer Laravel seeders
- make seeders re-runnable
- avoid dirty duplicates
- keep data minimal but enough for full phase-one debug loop

If you seed player state, carefully respect unique constraints such as:
- character slot uniqueness
- stack inventory uniqueness
- source binding uniqueness
- reward anti-duplication uniqueness

Do not fill large live-operation data sets.

---

## Transactions and consistency rules

These chains require extra review attention.

### Character create
- character row and 12 equipment slots must be initialized in one transaction
- no partial character state

### Equipment change
- slot updates and linkage cleanup must be atomic
- no duplicated instance occupancy across slots

### Reward grant
- must enforce business anti-duplication
- must enforce idempotency
- grant record, grant items, inventory write, and status update must be consistent

### Inventory write
- stack writes and equipment instance creation must be consistent
- do not return success on partial writes

### Battle settlement
- do not fake success if drop, reward, or inventory write failed
- summary payload must reflect formal successful results only

---

## Admin resource rules

Admin pages exist to support formal chains, not replace them.

Admin responsibilities include:
- config input
- config validation
- state query
- retry / repair tools

Admin pages must NOT:
- duplicate full player workflow logic in page code
- bypass formal workflows without explicit approval
- introduce a separate admin-only business truth

If an admin action triggers formal business behavior, it should reuse the formal Workflow / Domain path whenever possible.

---

## Migrations, models, and schema changes

When a task touches schema:
- prefer Laravel migrations as the formal implementation path
- keep naming stable and explicit
- do not invent unrelated columns for convenience
- do not silently weaken documented uniqueness or anti-duplication rules

If a task requires schema change outside documented phase-one scope:
- stop and report it
- do not expand schema casually

---

## Working style inside backend

Before meaningful backend changes, always provide:

1. task understanding
2. implementation plan
3. files to add / modify
4. major risks

Then implement.

After implementation, always provide:

1. what changed
2. how to run / verify
3. self-test steps
4. mismatches or unresolved issues

Do not silently expand task scope.

---

## Validation rules

After backend changes, run the smallest relevant validations you can.

Examples:
- `php -l` or equivalent syntax checks
- targeted tests
- `php artisan route:list` if routes changed
- `php artisan db:seed --class=...` if seeders changed
- feature tests if API behavior changed
- model / migration checks if schema changed

If validation fails because of your change, fix it before finishing.
If validation cannot run because of environment limitations, say so clearly.

---

## Documentation update rules

Update backend-related docs in the same task when the task changes:
- API field contracts
- error codes
- enum values
- seeder business IDs
- workflow boundaries
- formal backend behavior

Do not churn docs for style-only edits.
Only update docs when contract, boundary, or formal behavior changed.

---

## Backend review checklist

Before finishing backend work, explicitly review:

- task scope creep
- controller bloat
- cross-layer leakage
- transaction boundary correctness
- unique constraint risk
- anti-duplication and idempotency correctness
- template vs instance confusion
- drop vs reward confusion
- enum drift
- error code drift
- seed repeatability
- API contract drift

Use the repository `code_review.md` as the primary review checklist.

---

## When to stop and ask

Stop and ask instead of guessing when:
- backend docs conflict on business semantics
- schema obviously conflicts with documented chain behavior
- task requires cross-directory gameplay changes
- implementing the request requires inventing missing rules
- multiple architecture paths exist and choice affects long-term backend structure

---

## Preferred output style

Use concise, structured output.
Be explicit about:
- assumptions
- files changed
- validations run
- remaining gaps

Do not claim full completion if any critical backend contract or validation remains uncertain.