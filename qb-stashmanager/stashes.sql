CREATE TABLE IF NOT EXISTS `stashes` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `type` ENUM('private', 'public', 'job', 'shared') NOT NULL DEFAULT 'public',
  `owner` VARCHAR(50) DEFAULT NULL,
  `job` VARCHAR(50) DEFAULT NULL,
  `coords` TEXT NOT NULL,
  `slots` INT(11) NOT NULL DEFAULT 50,
  `weight` INT(11) NOT NULL DEFAULT 100000,
  `ped_model` VARCHAR(50) DEFAULT NULL,
  `ped_offset` TEXT DEFAULT NULL,
  `ped_heading` FLOAT DEFAULT 0.0,
  `object_model` VARCHAR(100) DEFAULT NULL,
  `object_offset` TEXT DEFAULT NULL,
  `object_heading` FLOAT DEFAULT 0.0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`),
  KEY `job` (`job`),
  KEY `type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `stash_access` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `stash_id` INT(11) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `is_manager` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `stash_citizen` (`stash_id`, `citizenid`),
  CONSTRAINT `fk_stash_access_stash` FOREIGN KEY (`stash_id`) REFERENCES `stashes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
