# AGENTS.md

## Project identity

This repository contains the first-phase backend implementation and the current Godot client for **《山海巡厄录》**.

The goal is **not** to explore product direction.
The goal is to implement the already-defined phase-one main chains with stable structure, clear boundaries, and minimal overengineering.

You must follow repository documents before making design decisions.

---

## Source of truth

When instructions conflict, use this priority:

1. `项目总览.md`
2. `doc/codex/单机运行时与弱联网边界.md` for client runtime / startup / weak-network work
3. `doc/codex/Codex 主开发协作清单.md`
4. `doc/codex/Laravel 代码目录与命名规范.md` for backend work
5. Method-level design docs under `开发思路/`
6. `开发思路/接口字段级设计.md`
7. `doc/codex/接口示例文档.md`
8. `doc/codex/错误码总表.md`
9. `doc/codex/枚举总表.md`
10. `doc/codex/认证与接口公共规则.md`
11. `doc/codex/最小联调种子数据.md`

If code and docs differ:
- do not silently invent a new rule
- first identify the mismatch
- adapt to the real schema/code where necessary
- keep business semantics aligned with docs
- clearly report the mismatch in the final summary

---

## Phase-one scope

You are allowed to implement only the phase-one core scope.

Backend scope includes:

- configuration read chain
- character create chain
- equipment wear / unequip chain
- battle prepare chain
- battle settlement chain
- drop resolve chain
- reward grant chain
- inventory write chain
- first-phase APIs
- first-phase admin pages
- minimal debug seeders
- tests and validation around the above

Client scope currently includes:

- startup version / environment check compatibility layer
- local runtime / local game state skeleton
- character / stage / prepare / battle / settle / inventory / equipment / character-growth main loop
- save upload / download weak-network boundary
- documentation and tooling alignment needed for the above

You must NOT proactively implement:

- enhance system
- wash / reroll system
- gem system
- set system
- scripture system
- world level
- shop system
- activity / operation system
- large live-content expansion
- unrelated UI beautification
- speculative future abstractions
- leaderboard / exchange online systems
- strong-online multiplayer or real-time sync systems

---

## Architecture rules

These five-layer rules are mandatory for backend code.
Do not force them onto Godot page scripts or client coordinators.

Use the repository’s **five-layer** backend structure only:

1. Config
2. Query
3. Domain
4. Workflow
5. Admin

Rules:

- Controllers must stay thin.
- Controllers only accept input, call services, and return responses.
- Do not place business workflow logic in controllers.
- Do not bypass formal services by directly mutating state in controllers or ad-hoc scripts.
- Keep template-layer and instance-layer strictly separated.
- Keep drop chain and reward chain strictly separated.
- Do not create “god services” such as `GameService`, `CommonService`, `BaseBusinessService`, or similar vague classes.

---

## Laravel structure rules

Prefer repository conventions defined in `doc/codex/Laravel 代码目录与命名规范.md`.

General rules:

- organize code by business domain first, then by layer
- prefer clear names over generic names
- keep models, requests, resources, enums, exceptions, DTOs, and services in their defined folders
- use `snake_case` for API fields
- use stable enum values from `doc/codex/枚举总表.md`
- use stable error codes from `doc/codex/错误码总表.md`

---

## Data and state rules

### Character
- Character creation must initialize the character record and all 12 fixed equipment slots in one transaction.
- Never leave partial character initialization state.

### Equipment
- Wearing uses equipment instances, not templates.
- Slot compatibility must follow the formal slot rules.
- Main-hand / off-hand linkage must be handled correctly.
- A two-handed weapon must invalidate incompatible off-hand state.

### Battle
- Battle prepare must produce a formal battle preparation result.
- Character combat stats must come from the formal stat calculation path.
- Battle settlement must not fake success if drop / reward / inventory write failed.

### Drop
- Drop resolution only resolves formal drop results.
- It does not directly write inventory.
- Only supported roll semantics are the formally documented ones.

### Reward
- Reward grant must enforce both business anti-duplication and idempotency.
- Reward records and reward items must be traceable.

### Inventory
- Stackable items and equipment objects must be split before write.
- Equipment objects must be instantiated before becoming player-owned inventory state.
- Do not return success if stack write succeeded but equipment instance creation failed.

---

## API rules

Follow `开发思路/接口字段级设计.md`, `doc/codex/接口示例文档.md`, and `doc/codex/认证与接口公共规则.md`.

Rules:

- frontend business APIs use bearer-token-authenticated user context
- never trust frontend-provided `user_id`
- use unified response wrapper:
  - success: `code = 0`, `message = "ok"`, `data = ...`
  - failure: formal error code, short message, `data = null`
- pagination must use:
  - request: `page`, `page_size`
  - response: `list`, `pagination`
- use stable enum values only
- use formal error codes only

For current client runtime work:

- do not add backend APIs unless explicitly requested
- do not keep treating runtime pages as real-time API shells by default
- startup check may normalize missing backend fields as `unknown` or `not_declared`

---

## Seeder rules

When implementing minimal debug seeders:

- use the fixed business IDs from `doc/codex/最小联调种子数据.md`
- prefer Laravel seeders
- make seeders re-runnable
- avoid dirty duplicates
- keep seed data minimal but enough for the full phase-one debug loop

---

## Working style

Before making meaningful code changes, always:

1. summarize task understanding
2. provide implementation plan
3. list files to add / change
4. list major risks

Then implement.

After implementation, always provide:

1. what changed
2. how to run / verify
3. self-test steps
4. mismatches or unresolved items

Do not silently expand task scope.

If the task is client runtime / startup / weak-network related, also report:

1. docs / skills mismatch points
2. what was corrected before code
3. where local runtime truth starts
4. what online behavior was intentionally not expanded

---

## Validation rules

After changing code, run the smallest relevant verification you can.

Examples:
- targeted tests
- php syntax checks
- artisan command checks
- route:list if routes changed
- seed execution if seeders changed
- feature tests if API behavior changed

If a validation fails and the failure is caused by your change, fix it before finishing.

If validation cannot run because of environment limitations, state that clearly.

---

## Documentation update rules

If your task changes any of the following, update docs in the same task when appropriate:

- API field structure
- enum values
- error codes
- seed data IDs
- architectural conventions
- business chain behavior

Do not update docs just for style churn.
Only update docs when behavior, contract, or implementation boundary changed.

---

## Review rules

When reviewing your own diff, explicitly check:

- scope creep
- controller bloat
- cross-layer leakage
- partial transaction risk
- enum / error code drift
- template vs instance confusion
- reward/drop chain confusion
- duplicate write risk
- violation of unique constraints

---

## When to ask for clarification

Stop and ask instead of guessing when:

- docs conflict on business semantics
- current database schema obviously conflicts with documented chain behavior
- the task requests changes outside phase-one scope
- implementing the request requires inventing missing rules
- multiple valid paths exist and the choice affects long-term architecture

---

## Preferred output style

Use concise, structured output.
Be explicit about:
- assumptions
- changes
- validations
- remaining gaps

Do not claim a task is fully complete if any critical validation or contract remains uncertain.
