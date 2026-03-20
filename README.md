# idle Codex Skills v3

这是一套面向 `eat-chestnut/idle` 仓库、并已按当前真实代码状态收口过的 Codex 规则包，包含：

- 5 个 Skills
- 1 个根级 `CODEX.md`
- 1 个 `.codex/PROJECT_RULES.md`

适用场景：
- backend 主链持续迭代
- battle prepare / settle / reward / inventory 收口
- 最小后台能力增强
- 修复 / 补发 / 文档最小对齐

## 建议放置方式

直接把压缩包内容解压到仓库根目录，形成：

```text
idle/
  CODEX.md
  .codex/
    PROJECT_RULES.md
    skills/
      architecture-guard/SKILL.md
      battle-flow/SKILL.md
      db-rules/SKILL.md
      dev-flow/SKILL.md
      scope-guard/SKILL.md
```

## 推荐默认启用
- architecture-guard
- dev-flow
- scope-guard

## 按需启用
- battle-flow：战斗准备 / 结算 / 掉落 / 奖励 / battle_context / failed grant 沉淀
- db-rules：migration / 表结构 / 幂等 / 数据修复 / 后台工具

## 和 v2 的主要区别
- 修正了文档路径优先级（使用根目录 `/AGENTS.md` 与 `/backend/AGENTS.md`）
- 不再默认把项目当成“空工程初始化阶段”
- 调整为更适合当前仓库的“增量迭代优先”开发顺序
- battle-flow 明确纳入当前仓库已收口的 failed reward grant 沉淀与补发承接语义
