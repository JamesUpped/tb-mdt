-- ============================================================
-- tb-mdt — Database Setup
-- Run this once on your MySQL/MariaDB to create the MDT tables.
-- The resource's server/database.lua also auto-creates tables
-- on first startup via CREATE TABLE IF NOT EXISTS.
-- ============================================================

CREATE TABLE IF NOT EXISTS `mdt_officers` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    `callsign` VARCHAR(20) DEFAULT NULL,
    `department` VARCHAR(50) NOT NULL DEFAULT 'police',
    `rank` VARCHAR(50) NOT NULL DEFAULT 'Officer',
    `grade_level` INT NOT NULL DEFAULT 0,
    `status` ENUM('available','busy','en-route','on-scene','off-duty') NOT NULL DEFAULT 'available',
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_officer_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_calls` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `caller` VARCHAR(100) DEFAULT 'Anonymous',
    `location` VARCHAR(255) DEFAULT NULL,
    `description` TEXT,
    `priority` ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
    `status` ENUM('pending','assigned','en-route','on-scene','closed') NOT NULL DEFAULT 'pending',
    `assigned_officers` JSON DEFAULT NULL,
    `case_number` VARCHAR(30) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_call_status` (`status`),
    KEY `idx_call_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_incidents` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `case_number` VARCHAR(30) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `location` VARCHAR(255) DEFAULT NULL,
    `status` ENUM('open','closed','archived') NOT NULL DEFAULT 'open',
    `officers` JSON DEFAULT NULL,
    `suspects` JSON DEFAULT NULL,
    `charges` JSON DEFAULT NULL,
    `created_by` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_case_number` (`case_number`),
    KEY `idx_incident_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_warrants` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `suspect_name` VARCHAR(100) NOT NULL,
    `suspect_citizenid` VARCHAR(50) DEFAULT NULL,
    `charges` TEXT,
    `description` TEXT,
    `status` ENUM('active','executed','expired') NOT NULL DEFAULT 'active',
    `issued_by` VARCHAR(100) NOT NULL,
    `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `executed_by` VARCHAR(100) DEFAULT NULL,
    `executed_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_warrant_status` (`status`),
    KEY `idx_warrant_suspect` (`suspect_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_bolos` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `type` ENUM('person','vehicle') NOT NULL DEFAULT 'person',
    `description` TEXT,
    `plate` VARCHAR(20) DEFAULT NULL,
    `suspect_name` VARCHAR(100) DEFAULT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `status` ENUM('active','inactive') NOT NULL DEFAULT 'active',
    `created_by` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_bolo_status` (`status`),
    KEY `idx_bolo_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_evidence` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `incident_id` INT NOT NULL,
    `type` VARCHAR(50) NOT NULL DEFAULT 'other',
    `description` TEXT,
    `metadata` TEXT DEFAULT NULL,
    `added_by` VARCHAR(100) NOT NULL,
    `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_evidence_incident` (`incident_id`),
    CONSTRAINT `fk_evidence_incident` FOREIGN KEY (`incident_id`) REFERENCES `mdt_incidents` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- v1.1 — Premium record systems
-- ============================================================

CREATE TABLE IF NOT EXISTS `mdt_charges` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `citizen_name` VARCHAR(100) DEFAULT NULL,
    `charge_id` VARCHAR(10) DEFAULT NULL,
    `charge_title` VARCHAR(100) DEFAULT NULL,
    `category` VARCHAR(20) DEFAULT NULL,
    `fine` INT NOT NULL DEFAULT 0,
    `jail` INT NOT NULL DEFAULT 0,
    `points` INT NOT NULL DEFAULT 0,
    `incident_id` INT DEFAULT NULL,
    `officer` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_charges_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_fines` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `citizen_name` VARCHAR(100) DEFAULT NULL,
    `amount` INT NOT NULL,
    `charges` TEXT,
    `status` VARCHAR(10) NOT NULL DEFAULT 'unpaid',
    `officer` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_fines_citizen` (`citizenid`),
    KEY `idx_fines_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_weapons` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `serial` VARCHAR(50) NOT NULL,
    `model` VARCHAR(50) DEFAULT NULL,
    `owner_cid` VARCHAR(50) DEFAULT NULL,
    `owner_name` VARCHAR(100) DEFAULT NULL,
    `status` VARCHAR(15) NOT NULL DEFAULT 'registered',
    `notes` TEXT,
    `registered_by` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_weapon_serial` (`serial`),
    KEY `idx_weapons_owner` (`owner_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_profiles` (
    `citizenid` VARCHAR(50) NOT NULL,
    `image` TEXT,
    `notes` TEXT,
    `flags` TEXT,
    `updated_by` VARCHAR(100) DEFAULT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_announcements` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(120) NOT NULL,
    `body` TEXT,
    `priority` VARCHAR(10) NOT NULL DEFAULT 'normal',
    `created_by` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_vehicle_flags` (
    `plate` VARCHAR(20) NOT NULL,
    `stolen` TINYINT(1) NOT NULL DEFAULT 0,
    `notes` TEXT,
    `updated_by` VARCHAR(100) DEFAULT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
