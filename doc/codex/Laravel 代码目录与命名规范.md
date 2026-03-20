

# 《山海巡厄录》Laravel 代码目录与命名规范

## 1. 文档目的

本文档用于在《项目总览》《Codex 主开发协作清单》《Codex 任务下发 Prompt 模板》《后端服务分层设计》《接口开发清单》《接口字段级设计》以及各方法级设计文档基础上，进一步明确《山海巡厄录》项目在 Laravel 工程中的代码目录组织方式、命名规则、文件落位规则、类职责边界与当前阶段推荐的工程落地结构。

本文档的目标不是讨论业务规则，而是解决以下工程问题：

- 当前项目的 Laravel 代码到底应该怎么分目录
- 五层服务分层在工程目录中如何落地
- Controller、Request、Resource、Service、Model、Enum、DTO 应该放在哪里
- 类名、方法名、文件名、路由名应该如何统一命名
- 如何避免后续越做越乱、文件堆叠、职责混杂

本文档定位为：

- Laravel 工程结构规范文档
- Laravel 命名规范文档
- Codex 正式落代码时的目录与类落位基线
- 后续新模块、新链路、新接口的统一工程规范文档

---

## 2. 当前项目工程落地总原则

### 2.1 目录结构必须服务五层分层

本项目后端以五层服务分层为唯一正式口径：

1. Config
2. Query
3. Domain
4. Workflow
5. Admin

Laravel 工程目录必须围绕这五层落地，而不是所有 Service 混放在一个目录里。

### 2.2 目录应围绕“业务域”组织，而不是围绕“技术类型”无限平铺

不建议把所有类长期平铺在：

- `Services/`
- `Requests/`
- `Resources/`

一个大目录里。

更推荐按业务域拆分，例如：

- Character
- Equipment
- Battle
- Drop
- Reward
- Inventory
- Stage
- Monster
- Item

然后在业务域内部再分层。

### 2.3 Controller 必须轻量

Controller 只负责：

- 收参
- 调用服务
- 返回响应

不允许把正式业务逻辑长期写在 Controller 中。

### 2.4 模板层与实例层在目录上也要清晰分离

涉及模板与实例的目录、模型、Service、Resource 命名必须清晰，避免出现：

- `EquipmentService` 同时处理模板和实例
- `ItemResource` 同时混杂模板与玩家持有状态

### 2.5 一类职责一个类，不做“万能 Service”

不允许长期出现这类类名：

- `GameService`
- `CommonService`
- `BaseBusinessService`
- `HelperService`

除非其职责非常清晰且确有必要，否则这种命名极易演变为“什么都往里塞”。

---

## 3. 推荐顶层目录结构

当前项目建议在 Laravel 应用目录中优先形成如下结构。

```text
app/
├── Console/
├── DTOs/
├── Enums/
├── Exceptions/
├── Http/
│   ├── Controllers/
│   ├── Requests/
│   └── Resources/
├── Models/
├── Services/
├── Support/
└── Traits/
```

其中与当前项目最关键的是：

- `Http/Controllers`
- `Http/Requests`
- `Http/Resources`
- `Models`
- `Services`
- `Enums`
- `DTOs`
- `Exceptions`
- `Support`

如果项目后续规模继续扩大，也可以进一步拆出：

- `Actions`
- `Policies`
- `Repositories`

但当前阶段不建议为了预防未来复杂度而过度提前抽象。

---

## 4. 推荐的业务域目录结构

当前项目建议在 `app/Services` 下按业务域拆分目录，而不是把所有服务平铺。

推荐结构如下：

```text
app/Services/
├── Character/
├── Equipment/
├── Battle/
├── Drop/
├── Reward/
├── Inventory/
├── Stage/
├── Monster/
├── Item/
└── Admin/
```

然后每个业务域内部再继续按五层拆分。

例如：

```text
app/Services/Character/
├── Config/
├── Query/
├── Domain/
├── Workflow/
└── Admin/
```

并不是每个域都一定五层齐全，但目录规范建议统一保留。

---

## 5. 五层服务在 Laravel 中的目录落位

## 5.1 Config 层目录

推荐放在：

```text
app/Services/<Domain>/Config/
```

示例：

```text
app/Services/Item/Config/ItemConfigService.php
app/Services/Equipment/Config/EquipmentTemplateConfigService.php
app/Services/Drop/Config/DropConfigService.php
app/Services/Reward/Config/RewardConfigService.php
```

### 职责

- 读取静态配置
- 不写状态
- 不做事务
- 不做流程编排

---

## 5.2 Query 层目录

推荐放在：

```text
app/Services/<Domain>/Query/
```

示例：

```text
app/Services/Character/Query/CharacterQueryService.php
app/Services/Equipment/Query/EquipmentInstanceQueryService.php
app/Services/Inventory/Query/InventoryStackQueryService.php
app/Services/Reward/Query/RewardGrantQueryService.php
```

### 职责

- 读取正式状态
- 不写状态
- 不承担完整流程

---

## 5.3 Domain 层目录

推荐放在：

```text
app/Services/<Domain>/Domain/
```

示例：

```text
app/Services/Character/Domain/CharacterCreateService.php
app/Services/Equipment/Domain/EquipmentWearService.php
app/Services/Equipment/Domain/EquipmentUnequipService.php
app/Services/Character/Domain/CharacterStatService.php
app/Services/Drop/Domain/DropResolverService.php
app/Services/Reward/Domain/RewardGrantRecordService.php
app/Services/Inventory/Domain/InventoryWriteService.php
```

### 职责

- 承担单点业务动作
- 承担领域规则判断
- 不承担大流程编排

---

## 5.4 Workflow 层目录

推荐放在：

```text
app/Services/<Domain>/Workflow/
```

示例：

```text
app/Services/Character/Workflow/CharacterCreateWorkflow.php
app/Services/Equipment/Workflow/EquipmentChangeWorkflow.php
app/Services/Battle/Workflow/BattlePrepareWorkflow.php
app/Services/Battle/Workflow/BattleSettlementWorkflow.php
app/Services/Reward/Workflow/RewardGrantWorkflow.php
```

### 职责

- 组织完整流程
- 控制事务边界
- 协调多个 Domain / Query / Config 服务

---

## 5.5 Admin 层目录

推荐放在：

```text
app/Services/<Domain>/Admin/
```

或统一落到：

```text
app/Services/Admin/
```

当前项目更推荐：

```text
app/Services/Admin/
```

示例：

```text
app/Services/Admin/AdminConfigValidationService.php
app/Services/Admin/AdminReferenceCheckService.php
app/Services/Admin/AdminRewardRetryService.php
app/Services/Admin/AdminDataRepairService.php
```

### 职责

- 后台校验
- 引用检查
- 补发
- 修复

### 当前阶段建议

Admin 层先统一集中，后续再按域拆分也可以。

---

## 6. Models 目录规范

推荐所有正式 Eloquent Model 放在：

```text
app/Models/
```

当前阶段建议按业务域子目录拆分：

```text
app/Models/
├── Character/
├── Equipment/
├── Inventory/
├── Drop/
├── Reward/
├── Stage/
├── Monster/
├── Item/
└── Class/
```

例如：

```text
app/Models/Character/Character.php
app/Models/Character/CharacterEquipmentSlot.php
app/Models/Equipment/Equipment.php
app/Models/Equipment/InventoryEquipmentInstance.php
app/Models/Inventory/InventoryStackItem.php
app/Models/Drop/DropGroup.php
app/Models/Drop/DropGroupItem.php
app/Models/Reward/RewardGroup.php
app/Models/Reward/UserRewardGrant.php
app/Models/Reward/UserRewardGrantItem.php
app/Models/Stage/Chapter.php
app/Models/Stage/ChapterStage.php
app/Models/Stage/StageDifficulty.php
```

### Model 命名原则

- 模型类名使用单数、PascalCase
- 表意必须准确
- 不要出现过于抽象的模型命名

例如：

- `Character`
- `CharacterEquipmentSlot`
- `InventoryStackItem`
- `InventoryEquipmentInstance`
- `UserRewardGrant`

不建议：

- `Grant`
- `ItemData`
- `CommonRecord`

---

## 7. Controllers 目录规范

推荐放在：

```text
app/Http/Controllers/Api/
```

按业务域拆分：

```text
app/Http/Controllers/Api/
├── Character/
├── Inventory/
├── Equipment/
├── Battle/
├── Stage/
└── Reward/
```

例如：

```text
app/Http/Controllers/Api/Character/CharacterController.php
app/Http/Controllers/Api/Equipment/EquipmentController.php
app/Http/Controllers/Api/Battle/BattleController.php
app/Http/Controllers/Api/Stage/StageController.php
app/Http/Controllers/Api/Inventory/InventoryController.php
app/Http/Controllers/Api/Reward/RewardGrantController.php
```

### Controller 命名原则

- `CharacterController`
- `BattleController`
- `StageController`

### Controller 方法命名建议

第一阶段建议使用清晰动词：

- `show()`
- `index()`
- `equip()`
- `unequip()`
- `prepare()`
- `settle()`
- `showFirstClearRewardStatus()`

### Controller 禁止事项

- 不写事务业务
- 不直接操作多个 Model 完成正式流程
- 不直接实现掉落 / 发奖 / 入包算法

---

## 8. Requests 目录规范

推荐放在：

```text
app/Http/Requests/Api/
```

按业务域拆分：

```text
app/Http/Requests/Api/
├── Character/
├── Equipment/
├── Battle/
└── Stage/
```

例如：

```text
app/Http/Requests/Api/Character/CreateCharacterRequest.php
app/Http/Requests/Api/Equipment/EquipItemRequest.php
app/Http/Requests/Api/Equipment/UnequipItemRequest.php
app/Http/Requests/Api/Battle/PrepareBattleRequest.php
app/Http/Requests/Api/Battle/SettleBattleRequest.php
app/Http/Requests/Api/Stage/StageDifficultyListRequest.php
```

### Request 命名原则

- 动作 + 业务对象 + `Request`

例如：

- `CreateCharacterRequest`
- `EquipItemRequest`
- `PrepareBattleRequest`
- `SettleBattleRequest`

### Request 职责

- 参数基础校验
- 参数类型 / 必填 / 枚举基础校验

### Request 不负责

- 正式业务规则判断
- 掉落 / 发奖 / 入包逻辑
- 复杂跨表校验

---

## 9. Resources 目录规范

推荐放在：

```text
app/Http/Resources/Api/
```

按业务域拆分：

```text
app/Http/Resources/Api/
├── Character/
├── Equipment/
├── Inventory/
├── Battle/
├── Stage/
└── Reward/
```

例如：

```text
app/Http/Resources/Api/Character/CharacterResource.php
app/Http/Resources/Api/Equipment/EquipmentInstanceResource.php
app/Http/Resources/Api/Inventory/InventoryListResource.php
app/Http/Resources/Api/Battle/BattlePrepareResource.php
app/Http/Resources/Api/Battle/BattleSettlementResource.php
app/Http/Resources/Api/Reward/RewardGrantResource.php
```

### Resource 命名原则

- 业务对象 + `Resource`
- 列表结构如确有必要再拆 `Collection`

### 当前阶段建议

当前阶段若响应结构比较稳定，也可以先用 Service 返回标准数组，再由 Controller 直接统一包裹。

但如果接口数量增加，建议尽早收敛到 Resource 层。

---

## 10. DTOs 目录规范

如果当前项目需要更清晰的输入输出对象，建议放在：

```text
app/DTOs/
```

按业务域拆分：

```text
app/DTOs/
├── Character/
├── Equipment/
├── Battle/
├── Reward/
└── Inventory/
```

例如：

```text
app/DTOs/Character/CreateCharacterData.php
app/DTOs/Equipment/EquipItemData.php
app/DTOs/Battle/PrepareBattleData.php
app/DTOs/Battle/SettleBattleData.php
app/DTOs/Reward/RewardGrantContextData.php
app/DTOs/Inventory/InventoryWriteData.php
```

### 当前阶段建议

第一阶段如果项目复杂度还没到强依赖 DTO，也可以先：

- Request 做基础校验
- Workflow / Domain 使用标准数组

但若 Codex 大量落代码，DTO 能明显减少字段混乱，推荐逐步引入在：

- 角色创建
- 战斗准备
- 战斗结算
- 奖励发放

这些复杂链路上。

---

## 11. Enums 目录规范

推荐放在：

```text
app/Enums/
```

按业务域拆分：

```text
app/Enums/
├── Common/
├── Drop/
├── Equipment/
└── Reward/
```

例如：

```text
app/Enums/Common/Rarity.php
app/Enums/Drop/DropRollType.php
app/Enums/Equipment/EquipmentSlot.php
app/Enums/Equipment/SubWeaponCategory.php
app/Enums/Reward/RewardSourceType.php
```

### Enum 命名原则

- 使用单数、PascalCase
- 名称要表达“这是枚举，不是服务”

不建议：

- `EquipmentSlotEnumType`
- `DropRollTypeService`

---

## 12. Exceptions 目录规范

推荐放在：

```text
app/Exceptions/
```

按业务域拆分：

```text
app/Exceptions/
├── Character/
├── Equipment/
├── Battle/
├── Reward/
└── Inventory/
```

例如：

```text
app/Exceptions/Character/CharacterNotFoundException.php
app/Exceptions/Equipment/EquipmentSlotNotCompatibleException.php
app/Exceptions/Battle/BattleContextInvalidException.php
app/Exceptions/Reward/RewardAlreadyGrantedException.php
app/Exceptions/Inventory/InventoryWriteFailedException.php
```

### Exception 命名原则

- 错误对象 + 错误原因 + `Exception`

例如：

- `CharacterNotFoundException`
- `RewardGrantFailedException`
- `DropResolveFailedException`

---

## 13. Support 目录规范

推荐放在：

```text
app/Support/
```

用于放当前项目确实存在跨域复用价值的基础支持类，例如：

- ID 生成器
- 幂等键生成器
- 通用响应封装
- 通用随机权重工具

例如：

```text
app/Support/Ids/BattleContextIdGenerator.php
app/Support/Ids/RewardGrantIdempotencyKeyBuilder.php
app/Support/Random/WeightedPicker.php
app/Support/Responses/ApiResponse.php
```

### 当前阶段约束

Support 目录只放“明确通用、明确基础”的支持类。

不允许把业务逻辑伪装成 Support 类塞进去。

---

## 14. 路由命名规范

推荐 API 路由统一放在：

```text
routes/api.php
```

当前阶段建议按业务域分组：

```php
Route::prefix('characters')->group(function () {
    Route::get('{character}', ...);
    Route::get('{character}/equipment-slots', ...);
    Route::post('{character}/equip', ...);
    Route::post('{character}/unequip', ...);
});

Route::prefix('battles')->group(function () {
    Route::post('prepare', ...);
    Route::post('settle', ...);
});
```

### 路由命名原则

- 使用资源化路径
- 使用清晰业务动作
- 不建议无语义缩写

例如：

- `/api/characters/{character_id}`
- `/api/characters/{character_id}/equipment-slots`
- `/api/battles/prepare`
- `/api/battles/settle`

不建议：

- `/api/getCharacterInfo`
- `/api/doEquip`
- `/api/fightSettlement`

---

## 15. 类命名规范

### 15.1 基本原则

- 文件名与类名完全一致
- 使用 PascalCase
- 类名必须表达职责

### 15.2 Service 类命名

格式建议：

- `<业务对象><职责>Service`
- `<业务对象><职责>Workflow`

例如：

- `CharacterCreateService`
- `CharacterCreateWorkflow`
- `EquipmentWearService`
- `BattleSettlementWorkflow`

### 15.3 Query / Config 类命名

例如：

- `CharacterQueryService`
- `EquipmentInstanceQueryService`
- `ItemConfigService`
- `RewardConfigService`

### 15.4 禁止的模糊命名

不建议：

- `HandleService`
- `MainService`
- `GameCommonService`
- `AllInOneService`

---

## 16. 方法命名规范

### 16.1 方法名使用动词开头

例如：

- `createCharacter()`
- `equip()`
- `unequip()`
- `prepareBattle()`
- `settleBattle()`
- `resolve()`
- `grant()`
- `write()`

### 16.2 Query 方法命名

建议使用：

- `get...`
- `find...`
- `exists...`
- `count...`

例如：

- `getCharacterById()`
- `getStageMonsterBindings()`
- `existsUserCharacterName()`

### 16.3 校验方法命名

建议使用：

- `validate...`
- `assert...`

例如：

- `validateRewardGrantContext()`
- `assertCharacterOwner()`
- `assertSlotCompatible()`

### 16.4 构造方法命名

建议使用：

- `build...`

例如：

- `buildRewardGrantRecordPayload()`
- `buildBattlePreparePayload()`
- `buildEquipmentInstancePayloads()`

---

## 17. 当前项目推荐目录示例

下面给出一个更贴近当前项目的推荐目录示例：

```text
app/
├── DTOs/
│   ├── Battle/
│   ├── Character/
│   ├── Equipment/
│   ├── Inventory/
│   └── Reward/
├── Enums/
│   ├── Common/
│   ├── Drop/
│   ├── Equipment/
│   └── Reward/
├── Exceptions/
│   ├── Battle/
│   ├── Character/
│   ├── Equipment/
│   ├── Inventory/
│   └── Reward/
├── Http/
│   ├── Controllers/
│   │   └── Api/
│   │       ├── Battle/
│   │       ├── Character/
│   │       ├── Equipment/
│   │       ├── Inventory/
│   │       ├── Reward/
│   │       └── Stage/
│   ├── Requests/
│   │   └── Api/
│   │       ├── Battle/
│   │       ├── Character/
│   │       └── Equipment/
│   └── Resources/
│       └── Api/
│           ├── Battle/
│           ├── Character/
│           ├── Equipment/
│           ├── Inventory/
│           ├── Reward/
│           └── Stage/
├── Models/
│   ├── Character/
│   ├── Class/
│   ├── Drop/
│   ├── Equipment/
│   ├── Inventory/
│   ├── Item/
│   ├── Monster/
│   ├── Reward/
│   └── Stage/
├── Services/
│   ├── Admin/
│   ├── Battle/
│   │   ├── Domain/
│   │   ├── Query/
│   │   └── Workflow/
│   ├── Character/
│   │   ├── Domain/
│   │   ├── Query/
│   │   └── Workflow/
│   ├── Drop/
│   │   ├── Config/
│   │   ├── Domain/
│   │   └── Query/
│   ├── Equipment/
│   │   ├── Config/
│   │   ├── Domain/
│   │   ├── Query/
│   │   └── Workflow/
│   ├── Inventory/
│   │   ├── Domain/
│   │   └── Query/
│   ├── Item/
│   │   └── Config/
│   ├── Reward/
│   │   ├── Config/
│   │   ├── Domain/
│   │   ├── Query/
│   │   └── Workflow/
│   └── Stage/
│       ├── Config/
│       └── Query/
└── Support/
    ├── Ids/
    ├── Random/
    └── Responses/
```

---

## 18. 当前阶段不建议过早引入的工程抽象

以下内容当前阶段不建议为了“看起来更完整”而提前引入：

- 复杂 Repository 全家桶
- Command Bus
- Event Sourcing
- 多层 Mapper 体系
- 大量抽象基类 Service
- 过多的 Traits 混用

原因：

- 当前阶段主链优先
- 过早抽象会增加 Codex 出错概率
- 容易把明确的业务边界又抽象回模糊结构

---

## 19. 当前阶段结论

1. Laravel 工程目录必须围绕五层服务分层与业务域拆分落地
2. Service 不应平铺在单一目录中，应尽量按业务域 + 分层组织
3. Controller、Request、Resource、Model、Enum、DTO、Exception 都应有明确目录落位规则
4. 类名、方法名、文件名、路由名必须统一、稳定、可读
5. 模板层 / 实例层、掉落链 / 奖励链等核心边界必须在目录与命名上体现出来
6. 当前阶段应避免过度工程化抽象，优先保持结构清晰、边界明确、便于 Codex 稳定落代码

本文档可直接作为项目正式《Laravel 代码目录与命名规范》文档使用，并作为后续 Codex 落代码、目录调整、类命名与工程收敛的统一规范基线。