-- 《山海巡厄录》数据库结构 SQL（MySQL 8.0 / utf8mb4）
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE `classes` (
  `class_id` varchar(64) NOT NULL,
  `class_name` varchar(64) NOT NULL,
  `class_desc` varchar(500) NOT NULL DEFAULT '',
  `sort_order` int NOT NULL DEFAULT 0,
  `icon` varchar(255) NOT NULL DEFAULT '',
  `avatar` varchar(255) NOT NULL DEFAULT '',
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `base_strength` int NOT NULL DEFAULT 0,
  `base_mana` int NOT NULL DEFAULT 0,
  `base_constitution` int NOT NULL DEFAULT 0,
  `base_dexterity` int NOT NULL DEFAULT 0,
  `atk_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `physical_def_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `magic_def_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `hp_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `mana_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `attack_speed_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `crit_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `spell_power_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `mana_recovery_scale` decimal(8,4) NOT NULL DEFAULT 1.0000,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`class_id`),
  KEY `idx_classes_enabled_sort` (`is_enabled`,`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `items` (
  `item_id` varchar(64) NOT NULL,
  `item_name` varchar(128) NOT NULL,
  `item_type` varchar(32) NOT NULL,
  `rarity` varchar(32) NOT NULL,
  `icon` varchar(255) NOT NULL DEFAULT '',
  `desc` varchar(1000) NOT NULL DEFAULT '',
  `max_stack` int NOT NULL DEFAULT 1,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`item_id`),
  KEY `idx_items_type_enabled_sort` (`item_type`,`is_enabled`,`sort_order`),
  KEY `idx_items_rarity` (`rarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `equipments` (
  `item_id` varchar(64) NOT NULL,
  `equipment_slot` varchar(32) NOT NULL,
  `level_required` int NOT NULL DEFAULT 1,
  `bonus_strength` int NOT NULL DEFAULT 0,
  `bonus_mana` int NOT NULL DEFAULT 0,
  `bonus_constitution` int NOT NULL DEFAULT 0,
  `bonus_dexterity` int NOT NULL DEFAULT 0,
  `bonus_attack` int NOT NULL DEFAULT 0,
  `bonus_physical_defense` int NOT NULL DEFAULT 0,
  `bonus_magic_defense` int NOT NULL DEFAULT 0,
  `bonus_hp` int NOT NULL DEFAULT 0,
  `bonus_attack_speed` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `bonus_crit_rate` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `bonus_spell_power` int NOT NULL DEFAULT 0,
  `weapon_category` varchar(32) NOT NULL DEFAULT '',
  `hand_type` varchar(16) NOT NULL DEFAULT '',
  `combat_type` varchar(16) NOT NULL DEFAULT '',
  `base_attack` int NOT NULL DEFAULT 0,
  `attack_interval` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `attack_range` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `attack_shape` varchar(32) NOT NULL DEFAULT '',
  `can_equip_sub_weapon` tinyint(1) NOT NULL DEFAULT 0,
  `knockback_power` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `sub_weapon_category` varchar(32) NOT NULL DEFAULT '',
  `main_effect_tag` varchar(64) NOT NULL DEFAULT '',
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`item_id`),
  KEY `idx_equipments_slot_enabled_sort` (`equipment_slot`,`is_enabled`,`sort_order`),
  KEY `idx_equipments_weapon_category` (`weapon_category`),
  KEY `idx_equipments_sub_weapon_category` (`sub_weapon_category`),
  CONSTRAINT `fk_equipments_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `chapters` (
  `chapter_id` varchar(64) NOT NULL,
  `chapter_name` varchar(128) NOT NULL,
  `chapter_desc` varchar(500) NOT NULL DEFAULT '',
  `chapter_group` varchar(64) NOT NULL DEFAULT '',
  `sort_order` int NOT NULL DEFAULT 0,
  `unlock_condition` varchar(255) NOT NULL DEFAULT '',
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`chapter_id`),
  KEY `idx_chapters_enabled_sort` (`is_enabled`,`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `chapter_stages` (
  `stage_id` varchar(64) NOT NULL,
  `chapter_id` varchar(64) NOT NULL,
  `stage_name` varchar(128) NOT NULL,
  `stage_desc` varchar(500) NOT NULL DEFAULT '',
  `stage_order` int NOT NULL DEFAULT 0,
  `recommended_power` int NOT NULL DEFAULT 0,
  `unlock_condition` varchar(255) NOT NULL DEFAULT '',
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`stage_id`),
  UNIQUE KEY `uk_stage_order_in_chapter` (`chapter_id`,`stage_order`),
  KEY `idx_stages_chapter_enabled_sort` (`chapter_id`,`is_enabled`,`stage_order`),
  CONSTRAINT `fk_stages_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapters` (`chapter_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `stage_difficulties` (
  `stage_difficulty_id` varchar(64) NOT NULL,
  `stage_id` varchar(64) NOT NULL,
  `difficulty_key` varchar(32) NOT NULL,
  `difficulty_name` varchar(64) NOT NULL,
  `difficulty_order` int NOT NULL DEFAULT 0,
  `recommended_power` int NOT NULL DEFAULT 0,
  `first_clear_reward_group_id` varchar(64) DEFAULT NULL,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`stage_difficulty_id`),
  UNIQUE KEY `uk_stage_difficulty` (`stage_id`,`difficulty_key`),
  KEY `idx_stage_difficulties_stage_enabled_sort` (`stage_id`,`is_enabled`,`difficulty_order`),
  KEY `idx_stage_difficulties_reward_group` (`first_clear_reward_group_id`),
  CONSTRAINT `fk_stage_difficulties_stage` FOREIGN KEY (`stage_id`) REFERENCES `chapter_stages` (`stage_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `monsters` (
  `monster_id` varchar(64) NOT NULL,
  `monster_name` varchar(128) NOT NULL,
  `monster_type` varchar(32) NOT NULL,
  `monster_desc` varchar(500) NOT NULL DEFAULT '',
  `rarity` varchar(32) NOT NULL DEFAULT 'common',
  `base_hp` int NOT NULL DEFAULT 0,
  `base_attack` int NOT NULL DEFAULT 0,
  `base_physical_defense` int NOT NULL DEFAULT 0,
  `base_magic_defense` int NOT NULL DEFAULT 0,
  `attack_interval` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `attack_range` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `move_speed` decimal(8,4) NOT NULL DEFAULT 0.0000,
  `skill_profile` varchar(64) NOT NULL DEFAULT '',
  `drop_role_hint` varchar(32) NOT NULL DEFAULT '',
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`monster_id`),
  KEY `idx_monsters_type_enabled_sort` (`monster_type`,`is_enabled`,`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `stage_monster_bindings` (
  `binding_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `stage_difficulty_id` varchar(64) NOT NULL,
  `monster_id` varchar(64) NOT NULL,
  `monster_role` varchar(32) NOT NULL,
  `wave_no` int NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`binding_id`),
  UNIQUE KEY `uk_stage_monster_role_order` (`stage_difficulty_id`,`monster_role`,`wave_no`,`sort_order`,`monster_id`),
  KEY `idx_stage_monster_stage` (`stage_difficulty_id`,`is_enabled`,`wave_no`,`sort_order`),
  KEY `idx_stage_monster_monster` (`monster_id`),
  CONSTRAINT `fk_stage_monster_stage_difficulty` FOREIGN KEY (`stage_difficulty_id`) REFERENCES `stage_difficulties` (`stage_difficulty_id`),
  CONSTRAINT `fk_stage_monster_monster` FOREIGN KEY (`monster_id`) REFERENCES `monsters` (`monster_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `characters` (
  `character_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `class_id` varchar(64) NOT NULL,
  `character_name` varchar(64) NOT NULL,
  `level` int NOT NULL DEFAULT 1,
  `exp` bigint unsigned NOT NULL DEFAULT 0,
  `unspent_stat_points` int NOT NULL DEFAULT 0,
  `added_strength` int NOT NULL DEFAULT 0,
  `added_mana` int NOT NULL DEFAULT 0,
  `added_constitution` int NOT NULL DEFAULT 0,
  `added_dexterity` int NOT NULL DEFAULT 0,
  `long_term_growth_stage` varchar(64) DEFAULT NULL,
  `extra_context` json DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`),
  KEY `idx_characters_user` (`user_id`),
  KEY `idx_characters_class` (`class_id`),
  CONSTRAINT `fk_characters_class` FOREIGN KEY (`class_id`) REFERENCES `classes` (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `inventory_stack_items` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `item_id` varchar(64) NOT NULL,
  `quantity` bigint unsigned NOT NULL DEFAULT 0,
  `is_locked` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_item_stack` (`user_id`,`item_id`),
  KEY `idx_stack_user` (`user_id`),
  KEY `idx_stack_item` (`item_id`),
  CONSTRAINT `fk_stack_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `inventory_equipment_instances` (
  `equipment_instance_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `item_id` varchar(64) NOT NULL,
  `bind_type` varchar(16) NOT NULL DEFAULT 'unbound',
  `enhance_level` int NOT NULL DEFAULT 0,
  `durability` int NOT NULL DEFAULT 0,
  `max_durability` int NOT NULL DEFAULT 0,
  `random_seed` bigint unsigned DEFAULT NULL,
  `is_locked` tinyint(1) NOT NULL DEFAULT 0,
  `extra_attributes` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`equipment_instance_id`),
  KEY `idx_equipment_instances_user` (`user_id`),
  KEY `idx_equipment_instances_item` (`item_id`),
  KEY `idx_equipment_instances_bind` (`bind_type`),
  KEY `idx_equipment_instances_enhance` (`enhance_level`),
  KEY `idx_equipment_instances_locked` (`is_locked`),
  CONSTRAINT `fk_equipment_instances_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `character_equipment_slots` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `character_id` bigint unsigned NOT NULL,
  `slot_key` varchar(32) NOT NULL,
  `equipped_instance_id` bigint unsigned DEFAULT NULL,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_character_slot` (`character_id`,`slot_key`),
  UNIQUE KEY `uk_equipped_instance` (`equipped_instance_id`),
  KEY `idx_slots_character_sort` (`character_id`,`sort_order`),
  CONSTRAINT `fk_slots_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`character_id`),
  CONSTRAINT `fk_slots_equipment_instance` FOREIGN KEY (`equipped_instance_id`) REFERENCES `inventory_equipment_instances` (`equipment_instance_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `drop_groups` (
  `drop_group_id` varchar(64) NOT NULL,
  `drop_group_name` varchar(128) NOT NULL,
  `roll_type` varchar(32) NOT NULL,
  `roll_times` int NOT NULL DEFAULT 1,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`drop_group_id`),
  KEY `idx_drop_groups_enabled_sort` (`is_enabled`,`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `drop_group_items` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `drop_group_id` varchar(64) NOT NULL,
  `item_id` varchar(64) NOT NULL,
  `weight` bigint unsigned NOT NULL DEFAULT 0,
  `min_quantity` int NOT NULL DEFAULT 1,
  `max_quantity` int NOT NULL DEFAULT 1,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_drop_items_group_sort` (`drop_group_id`,`is_enabled`,`sort_order`),
  KEY `idx_drop_items_item` (`item_id`),
  CONSTRAINT `fk_drop_items_group` FOREIGN KEY (`drop_group_id`) REFERENCES `drop_groups` (`drop_group_id`),
  CONSTRAINT `fk_drop_items_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `drop_group_bindings` (
  `binding_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `drop_group_id` varchar(64) NOT NULL,
  `source_type` varchar(32) NOT NULL,
  `source_id` varchar(64) NOT NULL,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`binding_id`),
  UNIQUE KEY `uk_drop_binding` (`drop_group_id`,`source_type`,`source_id`),
  KEY `idx_drop_binding_source` (`source_type`,`source_id`,`is_enabled`),
  KEY `idx_drop_binding_group` (`drop_group_id`),
  CONSTRAINT `fk_drop_binding_group` FOREIGN KEY (`drop_group_id`) REFERENCES `drop_groups` (`drop_group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `reward_groups` (
  `reward_group_id` varchar(64) NOT NULL,
  `reward_group_name` varchar(128) NOT NULL,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`reward_group_id`),
  KEY `idx_reward_groups_enabled_sort` (`is_enabled`,`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `reward_group_items` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `reward_group_id` varchar(64) NOT NULL,
  `item_id` varchar(64) NOT NULL,
  `quantity` int NOT NULL DEFAULT 1,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_reward_items_group_sort` (`reward_group_id`,`is_enabled`,`sort_order`),
  KEY `idx_reward_items_item` (`item_id`),
  CONSTRAINT `fk_reward_items_group` FOREIGN KEY (`reward_group_id`) REFERENCES `reward_groups` (`reward_group_id`),
  CONSTRAINT `fk_reward_items_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `reward_group_bindings` (
  `binding_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `reward_group_id` varchar(64) NOT NULL,
  `source_type` varchar(32) NOT NULL,
  `source_id` varchar(64) NOT NULL,
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `sort_order` int NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`binding_id`),
  UNIQUE KEY `uk_reward_binding` (`reward_group_id`,`source_type`,`source_id`),
  KEY `idx_reward_binding_source` (`source_type`,`source_id`,`is_enabled`),
  KEY `idx_reward_binding_group` (`reward_group_id`),
  CONSTRAINT `fk_reward_binding_group` FOREIGN KEY (`reward_group_id`) REFERENCES `reward_groups` (`reward_group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_reward_grants` (
  `reward_grant_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `reward_group_id` varchar(64) NOT NULL,
  `source_type` varchar(32) NOT NULL,
  `source_id` varchar(64) NOT NULL,
  `idempotency_key` varchar(128) NOT NULL,
  `grant_status` varchar(32) NOT NULL DEFAULT 'pending',
  `grant_payload_snapshot` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `granted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`reward_grant_id`),
  UNIQUE KEY `uk_reward_grant_idempotency` (`idempotency_key`),
  UNIQUE KEY `uk_reward_grant_once` (`user_id`,`source_type`,`source_id`,`reward_group_id`),
  KEY `idx_reward_grants_user` (`user_id`,`created_at`),
  KEY `idx_reward_grants_source` (`source_type`,`source_id`),
  KEY `idx_reward_grants_status` (`grant_status`),
  CONSTRAINT `fk_reward_grants_group` FOREIGN KEY (`reward_group_id`) REFERENCES `reward_groups` (`reward_group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
