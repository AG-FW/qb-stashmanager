local QBCore = exports['qb-core']:GetCoreObject()
function InitializeDatabase()
    if not Config.AutoCreateDatabase then
        print('^3[StashManager]^7 Auto database creation is disabled.')
        MySQL.query('SHOW TABLES LIKE "stashes"', {}, function(result)
            if result and #result > 0 then
                print('^2[StashManager]^7 Database table found.')
                EnsureAccessTable(function()
                    if Config.AutoUpdateSchema then
                        CheckAndUpdateColumns()
                    else
                        _G.DatabaseReady = true
                    end
                end)
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
            `show_blip` TINYINT(1) DEFAULT 1,
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
            EnsureAccessTable(function()
                if Config.AutoUpdateSchema then
                    CheckAndUpdateColumns()
                else
                    _G.DatabaseReady = true
                end
            end)
        else
            print('^1[StashManager]^7 Failed to create database table')
        end
    end)
end

function CheckAndUpdateColumns()
    EnsureSharedType(function()
        EnsurePedColumns(function()
            EnsureAccessTable(function()
                EnsureLogsTable(function()
                    EnsureBlipColumn(function()
                        EnsureBlipSettingsTable(function()
                            print('^2[StashManager]^7 Database schema up to date')
                            _G.DatabaseReady = true
                        end)
                    end)
                end)
            end)
        end)
    end)
end

function EnsurePedColumns(cb)
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
                if cb then cb() end
            end)
        else
            if cb then cb() end
        end
    end)
end

function EnsureSharedType(cb)
    MySQL.query('SHOW COLUMNS FROM stashes LIKE "type"', {}, function(result)
        if result and result[1] then
            local columnType = result[1].Type or ''
            if not string.find(columnType, 'shared') then
                print('^3[StashManager]^7 Updating stash type enum to include shared...')
                MySQL.query([[
                    ALTER TABLE stashes 
                    MODIFY `type` ENUM('private','public','job','shared') NOT NULL DEFAULT 'public';
                ]], {}, function(alterSuccess)
                    if alterSuccess then
                        print('^2[StashManager]^7 Stash type enum updated')
                    end
                    if cb then cb() end
                end)
                return
            end
        end
        if cb then cb() end
    end)
end

function EnsureAccessTable(cb)
    MySQL.query([[ 
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
    ]], {}, function(success)
        if not success then
            print('^1[StashManager]^7 Failed to verify stash_access table')
        end
        if cb then cb() end
    end)
end

function EnsureLogsTable(cb)
    MySQL.query([[ 
        CREATE TABLE IF NOT EXISTS `stash_logs` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `stash_id` INT(11) NOT NULL,
            `stash_name` VARCHAR(100) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `action` ENUM('open', 'item_added', 'item_removed', 'item_moved') NOT NULL,
            `item_name` VARCHAR(100) DEFAULT NULL,
            `item_amount` INT(11) DEFAULT NULL,
            `details` TEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `stash_id` (`stash_id`),
            KEY `citizenid` (`citizenid`),
            KEY `action` (`action`),
            KEY `created_at` (`created_at`),
            CONSTRAINT `fk_stash_logs_stash` FOREIGN KEY (`stash_id`) REFERENCES `stashes` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(success)
        if not success then
            print('^1[StashManager]^7 Failed to verify stash_logs table')
        else
            print('^2[StashManager]^7 Access logs table verified')
        end
        if cb then cb() end
    end)
end

function EnsureBlipColumn(cb)
    MySQL.query('SHOW COLUMNS FROM stashes LIKE "show_blip"', {}, function(result)
        if not result or #result == 0 then
            print('^3[StashManager]^7 Adding blip visibility column...')
            MySQL.query([[
                ALTER TABLE stashes 
                ADD COLUMN `show_blip` TINYINT(1) DEFAULT 1 AFTER `object_heading`;
            ]], {}, function(alterSuccess)
                if alterSuccess then
                    print('^2[StashManager]^7 Blip visibility column added')
                end
                -- Add custom blip columns
                EnsureCustomBlipColumns(function()
                    if cb then cb() end
                end)
            end)
        else
            -- Check for custom blip columns even if show_blip exists
            EnsureCustomBlipColumns(function()
                if cb then cb() end
            end)
        end
    end)
end

function EnsureCustomBlipColumns(cb)
    -- Check and add custom blip sprite column
    MySQL.query('SHOW COLUMNS FROM stashes LIKE "blip_sprite"', {}, function(result)
        if not result or #result == 0 then
            print('^3[StashManager]^7 Adding custom blip columns...')
            MySQL.query([[
                ALTER TABLE stashes 
                ADD COLUMN `blip_sprite` INT(11) DEFAULT NULL AFTER `show_blip`,
                ADD COLUMN `blip_color` INT(11) DEFAULT NULL AFTER `blip_sprite`,
                ADD COLUMN `blip_label` VARCHAR(100) DEFAULT NULL AFTER `blip_color`;
            ]], {}, function(alterSuccess)
                if alterSuccess then
                    print('^2[StashManager]^7 Custom blip columns added')
                end
                if cb then cb() end
            end)
        else
            -- Check for other columns
            MySQL.query('SHOW COLUMNS FROM stashes LIKE "blip_color"', {}, function(result)
                if not result or #result == 0 then
                    MySQL.query([[
                        ALTER TABLE stashes 
                        ADD COLUMN `blip_color` INT(11) DEFAULT NULL AFTER `blip_sprite`,
                        ADD COLUMN `blip_label` VARCHAR(100) DEFAULT NULL AFTER `blip_color`;
                    ]], {}, function(alterSuccess)
                        if alterSuccess then
                            print('^2[StashManager]^7 Custom blip color/label columns added')
                        end
                        if cb then cb() end
                    end)
                else
                    MySQL.query('SHOW COLUMNS FROM stashes LIKE "blip_label"', {}, function(result)
                        if not result or #result == 0 then
                            MySQL.query([[
                                ALTER TABLE stashes 
                                ADD COLUMN `blip_label` VARCHAR(100) DEFAULT NULL AFTER `blip_color`;
                            ]], {}, function(alterSuccess)
                                if alterSuccess then
                                    print('^2[StashManager]^7 Custom blip label column added')
                                end
                                if cb then cb() end
                            end)
                        else
                            if cb then cb() end
                        end
                    end)
                end
            end)
        end
    end)
end

function EnsureBlipSettingsTable(cb)
    MySQL.query([[ 
        CREATE TABLE IF NOT EXISTS `stash_blip_settings` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `stash_type` ENUM('private', 'public', 'job', 'shared') NOT NULL,
            `sprite` INT(11) NOT NULL DEFAULT 478,
            `color` INT(11) NOT NULL DEFAULT 3,
            `label` VARCHAR(100) DEFAULT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `stash_type` (`stash_type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(success)
        if not success then
            print('^1[StashManager]^7 Failed to verify stash_blip_settings table')
        else
            print('^2[StashManager]^7 Blip settings table verified')
            -- Initialize default settings if table is new
            InitializeBlipSettings(function()
                if cb then cb() end
            end)
        end
    end)
end

function InitializeBlipSettings(cb)
    MySQL.query('SELECT COUNT(*) as count FROM stash_blip_settings', {}, function(result)
        if result and result[1] and result[1].count == 0 then
            print('^3[StashManager]^7 Initializing default blip settings...')
            local defaultSettings = {
                {type = 'private', sprite = 478, color = 1, label = 'Private Stash'},
                {type = 'public', sprite = 478, color = 2, label = 'Public Stash'},
                {type = 'job', sprite = 478, color = 3, label = 'Job Stash'},
                {type = 'shared', sprite = 478, color = 5, label = 'Shared Stash'}
            }
            
            local inserted = 0
            for _, setting in ipairs(defaultSettings) do
                MySQL.insert('INSERT INTO stash_blip_settings (stash_type, sprite, color, label) VALUES (?, ?, ?, ?)', {
                    setting.type,
                    setting.sprite,
                    setting.color,
                    setting.label
                }, function(id)
                    inserted = inserted + 1
                    if inserted == #defaultSettings then
                        print('^2[StashManager]^7 Default blip settings initialized')
                        if cb then cb() end
                    end
                end)
            end
        else
            if cb then cb() end
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
    MySQL.insert('INSERT INTO stashes (name, type, owner, job, coords, slots, weight, ped_model, ped_offset, ped_heading, object_model, object_offset, object_heading, show_blip, blip_sprite, blip_color, blip_label, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
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
        data.show_blip ~= nil and (data.show_blip and 1 or 0) or (Config.ShowBlips and 1 or 0),
        data.blip_sprite or nil,
        data.blip_color or nil,
        data.blip_label or nil,
        data.created_by
    }, function(id)
        cb(id)
    end)
end

function UpdateStash(id, data, cb)
    MySQL.update('UPDATE stashes SET name = ?, type = ?, owner = ?, job = ?, coords = ?, slots = ?, weight = ?, ped_model = ?, ped_offset = ?, ped_heading = ?, object_model = ?, object_offset = ?, object_heading = ?, show_blip = ? WHERE id = ?', {
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
        data.show_blip ~= nil and (data.show_blip and 1 or 0) or nil,
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

function GetAllStashAccess(cb)
    MySQL.query('SELECT stash_id, citizenid, is_manager FROM stash_access', {}, function(result)
        cb(result or {})
    end)
end

function GetStashAccess(stashId, cb)
    MySQL.query('SELECT citizenid, is_manager FROM stash_access WHERE stash_id = ?', {stashId}, function(result)
        cb(result or {})
    end)
end

function AddOrUpdateStashAccess(stashId, citizenid, isManager, cb)
    MySQL.query('INSERT INTO stash_access (stash_id, citizenid, is_manager) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE is_manager = VALUES(is_manager)', {
        stashId,
        citizenid,
        isManager and 1 or 0
    }, function(result)
        if cb then cb(result ~= nil) end
    end)
end

function RemoveStashAccess(stashId, citizenid, cb)
    MySQL.query('DELETE FROM stash_access WHERE stash_id = ? AND citizenid = ?', {stashId, citizenid}, function(result)
        if cb then cb(result and result.affectedRows and result.affectedRows > 0) end
    end)
end

function GetSharedStashesForCitizen(citizenid, cb)
    MySQL.query([[ 
        SELECT s.*, sa.is_manager 
        FROM stashes s 
        INNER JOIN stash_access sa ON sa.stash_id = s.id 
        WHERE sa.citizenid = ?
    ]], {citizenid}, function(result)
        cb(result or {})
    end)
end

function RenameStash(id, name, cb)
    MySQL.update('UPDATE stashes SET name = ? WHERE id = ?', {name, id}, function(affectedRows)
        if cb then cb(affectedRows and affectedRows > 0) end
    end)
end

-- Access logging functions
function LogStashAccess(stashId, stashName, citizenid, action, itemName, itemAmount, details, cb)
    MySQL.insert('INSERT INTO stash_logs (stash_id, stash_name, citizenid, action, item_name, item_amount, details) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        stashId,
        stashName,
        citizenid,
        action,
        itemName,
        itemAmount,
        details and json.encode(details) or nil
    }, function(id)
        if cb then cb(id) end
    end)
end

function GetStashLogs(stashId, limit, offset, cb)
    local query = 'SELECT * FROM stash_logs'
    local params = {}
    
    if stashId then
        query = query .. ' WHERE stash_id = ?'
        table.insert(params, stashId)
    end
    
    query = query .. ' ORDER BY created_at DESC'
    
    if limit then
        query = query .. ' LIMIT ?'
        table.insert(params, limit)
        if offset then
            query = query .. ' OFFSET ?'
            table.insert(params, offset)
        end
    end
    
    MySQL.query(query, params, function(result)
        cb(result or {})
    end)
end

function GetStashLogsByCitizen(citizenid, limit, offset, cb)
    MySQL.query('SELECT * FROM stash_logs WHERE citizenid = ? ORDER BY created_at DESC LIMIT ? OFFSET ?', {
        citizenid,
        limit or 100,
        offset or 0
    }, function(result)
        cb(result or {})
    end)
end

function GetStashLogsByAction(action, limit, offset, cb)
    MySQL.query('SELECT * FROM stash_logs WHERE action = ? ORDER BY created_at DESC LIMIT ? OFFSET ?', {
        action,
        limit or 100,
        offset or 0
    }, function(result)
        cb(result or {})
    end)
end

function GetRecentStashLogs(limit, cb)
    MySQL.query('SELECT * FROM stash_logs ORDER BY created_at DESC LIMIT ?', {
        limit or 100
    }, function(result)
        cb(result or {})
    end)
end

function GetStashLogStats(stashId, cb)
    MySQL.query([[
        SELECT 
            COUNT(*) as total_access,
            COUNT(CASE WHEN action = 'open' THEN 1 END) as total_opens,
            COUNT(CASE WHEN action = 'item_added' THEN 1 END) as total_adds,
            COUNT(CASE WHEN action = 'item_removed' THEN 1 END) as total_removes,
            COUNT(DISTINCT citizenid) as unique_users
        FROM stash_logs
        WHERE stash_id = ?
    ]], {stashId}, function(result)
        cb(result[1] or {})
    end)
end

-- Blip settings functions
function GetBlipSettings(cb)
    MySQL.query('SELECT * FROM stash_blip_settings', {}, function(result)
        local settings = {}
        if result then
            for _, row in ipairs(result) do
                settings[row.stash_type] = {
                    sprite = row.sprite,
                    color = row.color,
                    label = row.label
                }
            end
        end
        cb(settings)
    end)
end

function GetBlipSettingByType(stashType, cb)
    MySQL.query('SELECT * FROM stash_blip_settings WHERE stash_type = ?', {stashType}, function(result)
        if result and result[1] then
            cb({
                sprite = result[1].sprite,
                color = result[1].color,
                label = result[1].label
            })
        else
            cb(nil)
        end
    end)
end

function UpdateBlipSetting(stashType, sprite, color, label, cb)
    MySQL.query('INSERT INTO stash_blip_settings (stash_type, sprite, color, label) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE sprite = VALUES(sprite), color = VALUES(color), label = VALUES(label)', {
        stashType,
        sprite,
        color,
        label
    }, function(result)
        if cb then cb(result ~= nil) end
    end)
end
