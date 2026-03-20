<?php

namespace App\Support;

final class ErrorCode
{
    public const OK = 0;

    public const INVALID_ARGUMENT = 10001;
    public const UNAUTHORIZED = 10002;
    public const FORBIDDEN = 10003;
    public const RESOURCE_NOT_FOUND = 10004;
    public const SYSTEM_ERROR = 10005;

    public const CHARACTER_NOT_FOUND = 10101;
    public const CHARACTER_FORBIDDEN = 10102;
    public const CHARACTER_NAME_INVALID = 10103;
    public const CHARACTER_NAME_DUPLICATED = 10104;
    public const CHARACTER_CREATE_LIMIT_REACHED = 10105;
    public const CHARACTER_CLASS_INVALID = 10106;
    public const CHARACTER_CREATE_FAILED = 10107;
    public const CHARACTER_SLOT_INIT_FAILED = 10108;

    public const EQUIPMENT_INSTANCE_NOT_FOUND = 10201;
    public const EQUIPMENT_INSTANCE_FORBIDDEN = 10202;
    public const EQUIPMENT_TEMPLATE_INVALID = 10203;
    public const EQUIPMENT_SLOT_INVALID = 10204;
    public const EQUIPMENT_SLOT_NOT_COMPATIBLE = 10205;
    public const EQUIPMENT_LEVEL_NOT_ENOUGH = 10206;
    public const EQUIPMENT_SUB_WEAPON_NOT_COMPATIBLE = 10207;
    public const EQUIPMENT_UNEQUIP_FAILED = 10208;
    public const EQUIPMENT_EQUIP_FAILED = 10209;

    public const STAGE_NOT_FOUND = 10301;
    public const STAGE_DISABLED = 10302;
    public const STAGE_DIFFICULTY_NOT_FOUND = 10303;
    public const FIRST_CLEAR_REWARD_STATUS_QUERY_FAILED = 10304;

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

    public const ADMIN_CONFIG_INVALID = 10901;
    public const ADMIN_REFERENCE_CONFLICT = 10902;
    public const ADMIN_RETRY_FAILED = 10903;
    public const ADMIN_REPAIR_FAILED = 10904;

    public static function message(int $code): string
    {
        return match ($code) {
            self::OK => 'ok',
            self::INVALID_ARGUMENT => '参数非法',
            self::UNAUTHORIZED => '未登录或登录失效',
            self::FORBIDDEN => '无权限访问',
            self::RESOURCE_NOT_FOUND => '资源不存在',
            self::SYSTEM_ERROR => '系统错误',
            self::CHARACTER_NOT_FOUND => '角色不存在',
            self::CHARACTER_FORBIDDEN => '无权限访问他人角色',
            self::CHARACTER_NAME_INVALID => '角色名称不合法',
            self::CHARACTER_NAME_DUPLICATED => '角色名称重复',
            self::CHARACTER_CREATE_LIMIT_REACHED => '可创建角色数量已达上限',
            self::CHARACTER_CLASS_INVALID => '职业不存在或未启用',
            self::CHARACTER_CREATE_FAILED => '角色创建失败',
            self::CHARACTER_SLOT_INIT_FAILED => '角色槽位初始化失败',
            self::EQUIPMENT_INSTANCE_NOT_FOUND => '装备实例不存在',
            self::EQUIPMENT_INSTANCE_FORBIDDEN => '装备不属于当前用户',
            self::EQUIPMENT_TEMPLATE_INVALID => '装备模板不存在或未启用',
            self::EQUIPMENT_SLOT_INVALID => '目标槽位不合法',
            self::EQUIPMENT_SLOT_NOT_COMPATIBLE => '目标槽位与装备位不兼容',
            self::EQUIPMENT_LEVEL_NOT_ENOUGH => '角色等级不足',
            self::EQUIPMENT_SUB_WEAPON_NOT_COMPATIBLE => '主副武器不兼容',
            self::EQUIPMENT_UNEQUIP_FAILED => '装备卸下失败',
            self::EQUIPMENT_EQUIP_FAILED => '装备穿戴失败',
            self::STAGE_NOT_FOUND => '关卡不存在',
            self::STAGE_DISABLED => '关卡未启用',
            self::STAGE_DIFFICULTY_NOT_FOUND => '关卡难度不存在',
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
            self::ADMIN_CONFIG_INVALID => '后台配置不合法',
            self::ADMIN_REFERENCE_CONFLICT => '后台引用冲突',
            self::ADMIN_RETRY_FAILED => '后台重试失败',
            self::ADMIN_REPAIR_FAILED => '后台修复失败',
            default => '系统错误',
        };
    }
}
