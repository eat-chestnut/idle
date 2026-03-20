# AGENTS.md

## Scope of this file

This file applies to all client-side work under `client/`.
If the repository does not yet contain a `client/` runtime directory, these rules still define the expected standards for upcoming game-client work.

Unless a task explicitly requires cross-directory changes:
- only modify files under `client/`
- do not modify `backend/` business logic
- do not change root-level gameplay runtime code outside the approved client scope

If instructions conflict:
1. nearest `AGENTS.md`
2. repository root `AGENTS.md`
3. task-specific prompt
4. current committed code reality

---

## Client mission

The client exists to consume the already-defined phase-one backend and turn it into a playable, testable, vertically-sliced game flow.

The current priority is not feature expansion.
The priority is:

1. correct API integration
2. clear page flow
3. stable UI states
4. graceful failure handling
5. minimal but shippable phase-one player journey

Do not proactively expand future systems.

---

## Client source of truth

Use this priority when making client-side decisions:

1. `doc/项目总览.md`
2. `doc/codex/游戏端开发总纲.md`
3. `doc/codex/游戏端页面与入口清单.md`
4. `doc/codex/游戏端状态与交互清单.md`
5. `doc/codex/游戏端接口接入清单.md`
6. `doc/codex/接口示例文档.md`
7. `doc/codex/认证与接口公共规则.md`
8. `backend/docs/api/phase-one-frontend.openapi.json`
9. current committed backend code reality

If backend docs and backend code differ:
- do not guess
- prefer current committed backend behavior
- clearly report the mismatch
- update client expectations to match backend reality unless asked otherwise

---

## Phase-one client scope

You may implement only the phase-one playable client slice:

- login / token setup
- character creation entry
- character detail page
- inventory page
- equipment page
- chapter list page
- stage difficulty page
- battle prepare flow
- battle settlement result flow
- first-clear reward state display
- basic admin-free diagnostics useful for local integration

You must NOT proactively implement:

- enhance system
- reroll / wash system
- gem system
- set system
- scripture system
- world level
- shop system
- activity / operation system
- long-tail social systems
- speculative feature frameworks

---

## Client development rules

### API integration
- treat backend as the formal source of business truth
- never fake business success locally
- never trust client-generated user ownership
- follow bearer token flow exactly as documented
- keep request/response fields in `snake_case` where they map to backend fields

### Page flow
- build pages in the documented order
- prefer one working vertical slice over many half-complete pages
- keep navigation explicit and simple

### UI state
Every page must explicitly handle:
- loading
- success
- empty
- error
- unauthorized / expired token
- locked / not unlocked (if applicable)
- reward available / reward claimed (if applicable)

### Local state
- avoid duplicating backend business rules in client state
- keep derived display state lightweight
- do not invent hidden client-only workflow truth

### Error handling
- use backend error codes and messages as the base truth
- display friendly client copy if needed, but keep mapping explicit
- do not swallow backend failures

---

## Client output style

Before meaningful code changes, always provide:
1. task understanding
2. implementation plan
3. files to add / change
4. major risks

After implementation, always provide:
1. what changed
2. how to run / verify
3. integration steps
4. remaining gaps

---

## Validation rules

After client changes, run the smallest relevant verification you can:
- type/lint checks
- local build
- route/page smoke checks
- API integration verification against current backend
- screenshot/manual state verification if appropriate

If validation cannot run due to missing environment or client runtime, say so clearly.

---

## Review rules

Before finishing, explicitly check:
- contract drift from backend
- hidden client-side business rule duplication
- missing loading/error/empty states
- broken token/auth flow
- page transition confusion
- reward state display confusion
- integration assumptions not backed by backend reality
