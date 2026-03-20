<?php

namespace App\Support;

final class ErrorCode
{
    public const OK = 0;

    public const INVALID_PARAMS = 10001;
    public const INVALID_ARGUMENT = self::INVALID_PARAMS;
    public const UNAUTHORIZED = 10002;
    public const FORBIDDEN = 10003;
    public const RESOURCE_NOT_FOUND = 10004;
    public const SYSTEM_ERROR = 10005;
    public const TOO_MANY_REQUESTS = 10006;
    public const DATA_CONFLICT = 10007;
    public const STATE_INVALID = 10008;
    public const FEATURE_NOT_AVAILABLE = 10009;
    public const PAGINATION_PARAMS_INVALID = 10010;

    public const CHARACTER_NOT_FOUND = 10101;
    public const CHARACTER_FORBIDDEN = 10102;
    public const CHARACTER_NAME_INVALID = 10103;
    public const CHARACTER_NAME_DUPLICATED = 10104;
    public const CHARACTER_CREATE_LIMIT_REACHED = 10105;
    public const CHARACTER_CLASS_INVALID = 10106;
    public const CHARACTER_CREATE_FAILED = 10107;
    public const CHARACTER_SLOT_INIT_FAILED = 10108;
    public const CHARACTER_STATE_INVALID = 10109;
    public const CHARACTER_NOT_ACTIVE = 10110;

    public const EQUIPMENT_INSTANCE_NOT_FOUND = 10201;
    public const EQUIPMENT_INSTANCE_FORBIDDEN = 10202;
    public const EQUIPMENT_TEMPLATE_INVALID = 10203;
    public const EQUIPMENT_SLOT_INVALID = 10204;
    public const EQUIPMENT_SLOT_NOT_COMPATIBLE = 10205;
    public const EQUIPMENT_LEVEL_REQUIREMENT_NOT_MET = 10206;
    public const EQUIPMENT_LEVEL_NOT_ENOUGH = self::EQUIPMENT_LEVEL_REQUIREMENT_NOT_MET;
    public const EQUIPMENT_SUB_WEAPON_NOT_COMPATIBLE = 10207;
    public const EQUIPMENT_INSTANCE_ALREADY_EQUIPPED = 10208;
    public const EQUIPMENT_SLOT_EMPTY = 10209;
    public const EQUIPMENT_CHANGE_FAILED = 10210;
    public const EQUIPMENT_MAIN_SUB_LINKAGE_FAILED = 10211;
    public const EQUIPMENT_INSTANCE_STATE_INVALID = 10212;
    public const EQUIPMENT_UNEQUIP_FAILED = self::EQUIPMENT_CHANGE_FAILED;
    public const EQUIPMENT_EQUIP_FAILED = self::EQUIPMENT_CHANGE_FAILED;

    public const CHAPTER_NOT_FOUND = 10301;
    public const STAGE_NOT_FOUND = 10302;
    public const STAGE_DIFFICULTY_NOT_FOUND = 10303;
    public const STAGE_NOT_UNLOCKED = 10304;
    public const STAGE_DIFFICULTY_NOT_UNLOCKED = 10305;
    public const STAGE_MONSTER_BINDING_EMPTY = 10306;
    public const FIRST_CLEAR_REWARD_STATUS_QUERY_FAILED = 10307;

    public const STAGE_DISABLED = self::STAGE_NOT_UNLOCKED;

    public const BATTLE_PREPARE_FAILED = 10401;
    public const BATTLE_CHARACTER_INVALID = 10402;
    public const BATTLE_STAGE_DIFFICULTY_INVALID = 10403;
    public const BATTLE_MONSTER_CONFIG_INVALID = 10404;
    public const BATTLE_CHARACTER_STATS_CALCULATE_FAILED = 10405;
    public const BATTLE_CONTEXT_BUILD_FAILED = 10406;

    public const BATTLE_CONTEXT_INVALID = 10501;
    public const BATTLE_RESULT_INVALID = 10502;
    public const BATTLE_SETTLEMENT_FAILED = 10503;
    public const BATTLE_SETTLEMENT_DROP_FAILED = 10504;
    public const BATTLE_SETTLEMENT_REWARD_FAILED = 10505;
    public const BATTLE_SETTLEMENT_INVENTORY_FAILED = 10506;
    public const BATTLE_SETTLEMENT_PAYLOAD_BUILD_FAILED = 10507;

    public const DROP_CONTEXT_INVALID = 10601;
    public const DROP_SOURCE_BINDING_NOT_FOUND = 10602;
    public const DROP_GROUP_INVALID = 10603;
    public const DROP_GROUP_ITEMS_EMPTY = 10604;
    public const DROP_ROLL_TYPE_INVALID = 10605;
    public const DROP_WEIGHT_INVALID = 10606;
    public const DROP_RESOLVE_FAILED = 10607;
    public const DROP_RESULT_BUILD_FAILED = 10608;

    public const REWARD_CONTEXT_INVALID = 10701;
    public const REWARD_SOURCE_INVALID = 10702;
    public const REWARD_SOURCE_BINDING_NOT_FOUND = 10703;
    public const REWARD_GROUP_INVALID = 10704;
    public const REWARD_GROUP_ITEMS_EMPTY = 10705;
    public const REWARD_ALREADY_GRANTED = 10706;
    public const REWARD_IDEMPOTENCY_CONFLICT = 10707;
    public const REWARD_GRANT_RECORD_CREATE_FAILED = 10708;
    public const REWARD_GRANT_ITEMS_CREATE_FAILED = 10709;
    public const REWARD_GRANT_FAILED = 10710;
    public const REWARD_GRANT_MARK_FAILED = 10711;

    public const INVENTORY_WRITE_CONTEXT_INVALID = 10801;
    public const INVENTORY_ITEM_INVALID = 10802;
    public const INVENTORY_STACK_WRITE_FAILED = 10803;
    public const INVENTORY_EQUIPMENT_TEMPLATE_INVALID = 10804;
    public const INVENTORY_EQUIPMENT_INSTANCE_CREATE_FAILED = 10805;
    public const INVENTORY_WRITE_FAILED = 10806;
    public const INVENTORY_RESULT_BUILD_FAILED = 10807;

    public const ADMIN_CONFIG_VALIDATE_FAILED = 10901;
    public const ADMIN_REFERENCE_CHECK_FAILED = 10902;
    public const ADMIN_REWARD_RETRY_FAILED = 10903;
    public const ADMIN_DATA_REPAIR_FAILED = 10904;
    public const ADMIN_OPERATION_FORBIDDEN = 10905;

    public const ADMIN_CONFIG_INVALID = self::ADMIN_CONFIG_VALIDATE_FAILED;
    public const ADMIN_REFERENCE_CONFLICT = self::ADMIN_REFERENCE_CHECK_FAILED;
    public const ADMIN_RETRY_FAILED = self::ADMIN_REWARD_RETRY_FAILED;
    public const ADMIN_REPAIR_FAILED = self::ADMIN_DATA_REPAIR_FAILED;

    public static function message(int $code): string
    {
        return match ($code) {
            self::OK => 'ok',
            self::INVALID_PARAMS => '请求参数不合法',
            self::UNAUTHORIZED => '未登录或登录失效',
            self::FORBIDDEN => '无权限执行该操作',
            self::RESOURCE_NOT_FOUND => '资源不存在',
            self::SYSTEM_ERROR => '系统错误',
            self::TOO_MANY_REQUESTS => '请求过于频繁',
            self::DATA_CONFLICT => '数据冲突',
            self::STATE_INVALID => '当前状态不允许执行该操作',
            self::FEATURE_NOT_AVAILABLE => '当前功能暂未开放',
            self::PAGINATION_PARAMS_INVALID => '分页参数不合法',
            self::CHARACTER_NOT_FOUND => '角色不存在',
            self::CHARACTER_FORBIDDEN => '无权访问该角色',
            self::CHARACTER_NAME_INVALID => '角色名称不合法',
            self::CHARACTER_NAME_DUPLICATED => '角色名称重复',
            self::CHARACTER_CREATE_LIMIT_REACHED => '可创建角色数量已达上限',
            self::CHARACTER_CLASS_INVALID => '职业不存在或未启用',
            self::CHARACTER_CREATE_FAILED => '角色创建失败',
            self::CHARACTER_SLOT_INIT_FAILED => '角色槽位初始化失败',
            self::CHARACTER_STATE_INVALID => '当前角色状态异常',
            self::CHARACTER_NOT_ACTIVE => '当前角色未启用',
            self::EQUIPMENT_INSTANCE_NOT_FOUND => '装备实例不存在',
            self::EQUIPMENT_INSTANCE_FORBIDDEN => '装备不归属当前用户',
            self::EQUIPMENT_TEMPLATE_INVALID => '装备模板不存在或未启用',
            self::EQUIPMENT_SLOT_INVALID => '目标槽位不合法',
            self::EQUIPMENT_SLOT_NOT_COMPATIBLE => '目标槽位与装备位不兼容',
            self::EQUIPMENT_LEVEL_REQUIREMENT_NOT_MET => '角色等级不足，无法穿戴该装备',
            self::EQUIPMENT_SUB_WEAPON_NOT_COMPATIBLE => '主副武器不兼容',
            self::EQUIPMENT_INSTANCE_ALREADY_EQUIPPED => '该装备已被穿戴',
            self::EQUIPMENT_SLOT_EMPTY => '目标槽位当前没有已穿戴装备',
            self::EQUIPMENT_CHANGE_FAILED => '换装失败',
            self::EQUIPMENT_MAIN_SUB_LINKAGE_FAILED => '主副武器联动处理失败',
            self::EQUIPMENT_INSTANCE_STATE_INVALID => '装备实例状态异常',
            self::CHAPTER_NOT_FOUND => '章节不存在',
            self::STAGE_NOT_FOUND => '关卡不存在',
            self::STAGE_DIFFICULTY_NOT_FOUND => '关卡难度不存在',
            self::STAGE_NOT_UNLOCKED => '关卡未解锁或未启用',
            self::STAGE_DIFFICULTY_NOT_UNLOCKED => '关卡难度未解锁或未启用',
            self::STAGE_MONSTER_BINDING_EMPTY => '关卡未绑定怪物',
            self::FIRST_CLEAR_REWARD_STATUS_QUERY_FAILED => '首通奖励状态查询失败',
            self::BATTLE_PREPARE_FAILED => '战斗准备失败',
            self::BATTLE_CHARACTER_INVALID => '战斗角色无效',
            self::BATTLE_STAGE_DIFFICULTY_INVALID => '战斗目标关卡难度无效',
            self::BATTLE_MONSTER_CONFIG_INVALID => '战斗怪物配置异常',
            self::BATTLE_CHARACTER_STATS_CALCULATE_FAILED => '角色战斗属性计算失败',
            self::BATTLE_CONTEXT_BUILD_FAILED => '战斗上下文生成失败',
            self::BATTLE_CONTEXT_INVALID => '战斗上下文无效',
            self::BATTLE_RESULT_INVALID => '战斗结果不合法',
            self::BATTLE_SETTLEMENT_FAILED => '战斗结算失败',
            self::BATTLE_SETTLEMENT_DROP_FAILED => '掉落结算失败',
            self::BATTLE_SETTLEMENT_REWARD_FAILED => '首通奖励发放失败',
            self::BATTLE_SETTLEMENT_INVENTORY_FAILED => '结算入包失败',
            self::BATTLE_SETTLEMENT_PAYLOAD_BUILD_FAILED => '结算结果组装失败',
            self::DROP_CONTEXT_INVALID => '掉落解析上下文不合法',
            self::DROP_SOURCE_BINDING_NOT_FOUND => '掉落来源未绑定掉落组',
            self::DROP_GROUP_INVALID => '掉落组不存在或未启用',
            self::DROP_GROUP_ITEMS_EMPTY => '掉落组明细为空',
            self::DROP_ROLL_TYPE_INVALID => '掉落抽取规则非法',
            self::DROP_WEIGHT_INVALID => '掉落权重配置非法',
            self::DROP_RESOLVE_FAILED => '掉落解析失败',
            self::DROP_RESULT_BUILD_FAILED => '掉落结果构造失败',
            self::REWARD_CONTEXT_INVALID => '奖励发放上下文不合法',
            self::REWARD_SOURCE_INVALID => '奖励来源不合法',
            self::REWARD_SOURCE_BINDING_NOT_FOUND => '当前来源未绑定奖励组',
            self::REWARD_GROUP_INVALID => '奖励组不存在或未启用',
            self::REWARD_GROUP_ITEMS_EMPTY => '奖励组明细为空',
            self::REWARD_ALREADY_GRANTED => '当前奖励已发放',
            self::REWARD_IDEMPOTENCY_CONFLICT => '请求重复，奖励已处理',
            self::REWARD_GRANT_RECORD_CREATE_FAILED => '发奖主记录创建失败',
            self::REWARD_GRANT_ITEMS_CREATE_FAILED => '发奖明细写入失败',
            self::REWARD_GRANT_FAILED => '奖励发放失败',
            self::REWARD_GRANT_MARK_FAILED => '发奖状态更新失败',
            self::INVENTORY_WRITE_CONTEXT_INVALID => '入包上下文不合法',
            self::INVENTORY_ITEM_INVALID => '物品不存在或无效',
            self::INVENTORY_STACK_WRITE_FAILED => '可堆叠物写入失败',
            self::INVENTORY_EQUIPMENT_TEMPLATE_INVALID => '装备模板不存在或无效',
            self::INVENTORY_EQUIPMENT_INSTANCE_CREATE_FAILED => '装备实例创建失败',
            self::INVENTORY_WRITE_FAILED => '入包失败',
            self::INVENTORY_RESULT_BUILD_FAILED => '入包结果组装失败',
            self::ADMIN_CONFIG_VALIDATE_FAILED => '后台配置校验失败',
            self::ADMIN_REFERENCE_CHECK_FAILED => '后台引用检查失败',
            self::ADMIN_REWARD_RETRY_FAILED => '后台奖励补发失败',
            self::ADMIN_DATA_REPAIR_FAILED => '后台数据修复失败',
            self::ADMIN_OPERATION_FORBIDDEN => '当前后台操作不被允许',
            default => '系统错误',
        };
    }
}
