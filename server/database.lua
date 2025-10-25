local QBCore = exports['qb-core']:GetCoreObject()
function InitializeDatabase()
    if not Config.AutoCreateDatabase then
        print('^3[StashManager]^7 Auto database creation is disabled.')
        MySQL.query('SHOW TABLES LIKE "stashes"', {}, function(result)
            if result and #result > 0 then
                print('^2[StashManager]^7 Database table found.')
                if Config.AutoUpdateSchema then
                    CheckAndUpdateColumns()
                else
                    _G.DatabaseReady = true
                end
            else
                print('^1[StashManager]^7 Database table not found! Please run sql/stashes.sql')
            end
        end)
        return
    end
    
    print('^3[StashManager]^7 Auto-creating database table...')
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `stashes` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NOT NULL,
            `type` ENUM('private', 'public', 'job') NOT NULL DEFAULT 'public',
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
    ]], {}, function(success)
        if success then
            print('^2[StashManager]^7 Database table created/verified')
            if Config.AutoUpdateSchema then
                CheckAndUpdateColumns()
            else
                _G.DatabaseReady = true
            end
        else
            print('^1[StashManager]^7 Failed to create database table')
        end
    end)
end

function CheckAndUpdateColumns()
    MySQL.query('SHOW COLUMNS FROM stashes LIKE "ped_offset"', {}, function(result)
        if not result or #result == 0 then
            print('^3[StashManager]^7 Adding ped positioning columns...')
            MySQL.query([[
                ALTER TABLE stashes 
                ADD COLUMN `ped_offset` TEXT DEFAULT NULL AFTER `ped_model`,
                ADD COLUMN `ped_heading` FLOAT DEFAULT 0.0 AFTER `ped_offset`;
            ]], {}, function(alterSuccess)
                if alterSuccess then
                    print('^2[StashManager]^7 Ped positioning columns added')
                end
                _G.DatabaseReady = true
            end)
        else
            print('^2[StashManager]^7 Database schema up to date')
            _G.DatabaseReady = true
        end
    end)
end

function GetAllStashes(cb)
    MySQL.query('SELECT * FROM stashes', {}, function(result)
        cb(result)
    end)
end

function GetStashById(id, cb)
    MySQL.query('SELECT * FROM stashes WHERE id = ?', {id}, function(result)
        cb(result[1])
    end)
end

function CreateStash(data, cb)
    MySQL.insert('INSERT INTO stashes (name, type, owner, job, coords, slots, weight, ped_model, ped_offset, ped_heading, object_model, object_offset, object_heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.name,
        data.type,
        data.owner,
        data.job,
        json.encode(data.coords),
        data.slots,
        data.weight,
        data.ped_model,
        data.ped_offset and json.encode(data.ped_offset) or nil,
        data.ped_heading or 0.0,
        data.object_model,
        data.object_offset and json.encode(data.object_offset) or nil,
        data.object_heading or 0.0,
        data.created_by
    }, function(id)
        cb(id)
    end)
end

function UpdateStash(id, data, cb)
    MySQL.update('UPDATE stashes SET name = ?, type = ?, owner = ?, job = ?, coords = ?, slots = ?, weight = ?, ped_model = ?, ped_offset = ?, ped_heading = ?, object_model = ?, object_offset = ?, object_heading = ? WHERE id = ?', {
        data.name,
        data.type,
        data.owner,
        data.job,
        json.encode(data.coords),
        data.slots,
        data.weight,
        data.ped_model,
        data.ped_offset and json.encode(data.ped_offset) or nil,
        data.ped_heading or 0.0,
        data.object_model,
        data.object_offset and json.encode(data.object_offset) or nil,
        data.object_heading or 0.0,
        id
    }, function(affectedRows)
        cb(affectedRows > 0)
    end)
end

function DeleteStash(id, cb)
    MySQL.query('DELETE FROM stashes WHERE id = ?', {id}, function(result)
        cb(result.affectedRows > 0)
    end)
end

function GetPlayerStashes(citizenid, cb)
    MySQL.query('SELECT * FROM stashes WHERE owner = ?', {citizenid}, function(result)
        cb(result)
    end)
end

function GetJobStashes(job, cb)
    MySQL.query('SELECT * FROM stashes WHERE type = "job" AND job = ?', {job}, function(result)
        cb(result)
    end)
end

function GetPublicStashes(cb)
    MySQL.query('SELECT * FROM stashes WHERE type = "public"', {}, function(result)
        cb(result)
    end)
end

function StashExists(name, cb)
    MySQL.query('SELECT id FROM stashes WHERE name = ?', {name}, function(result)
        cb(result[1] ~= nil)
    end)
end
