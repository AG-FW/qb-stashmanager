-- server/main.lua - QBCore with Multi-Inventory Support (ox_inventory, qb-inventory, qs-inventory)
local QBCore = exports['qb-core']:GetCoreObject()
local ActiveStashes = {}
local SharedAccess = {}
local InventoryType = nil
local BlipSettings = {} -- Store blip settings loaded from database

local function NormalizeManagerFlag(value)
    if value == nil then return false end
    if value == true then return true end
    local valueType = type(value)
    if valueType == 'number' then
        return value == 1
    elseif valueType == 'string' then
        value = value:lower()
        return value == '1' or value == 'true' or value == 'yes'
    end
    return false
end

local function GetPlayerIdByCitizenId(citizenid)
    if not citizenid then return nil end
    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData and player.PlayerData.citizenid == citizenid then
            return playerId
        end
    end
    return nil
end

local function RefreshSharedMembers(stashId)
    local access = SharedAccess[stashId]
    if not access then return end
    for citizenid in pairs(access) do
        local playerId = GetPlayerIdByCitizenId(citizenid)
        if playerId then
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', playerId)
        end
    end
end

local function IsSharedManager(stash, citizenid)
    if not stash or stash.type ~= 'shared' or not citizenid then return false end

    if stash.created_by and stash.created_by == citizenid then
        return true
    end

    local access = SharedAccess[stash.id]
    if access and access[citizenid] and access[citizenid].is_manager then
        return true
    end

    return false
end

local function SetSharedManager(stashId, citizenid)
    SharedAccess[stashId] = SharedAccess[stashId] or {}

    SharedAccess[stashId][citizenid] = SharedAccess[stashId][citizenid] or {is_manager = false}

    for memberCitizen, data in pairs(SharedAccess[stashId]) do
        local isManager = (memberCitizen == citizenid)
        data.is_manager = isManager
        AddOrUpdateStashAccess(stashId, memberCitizen, isManager)
    end

    if ActiveStashes[stashId] then
        ActiveStashes[stashId].access = SharedAccess[stashId]
    end
end

local function SendNotify(target, message, notifType, duration)
    notifType = notifType or 'primary'
    TriggerClientEvent('qb-stashmanager:client:Notify', target, message, notifType, duration)
end

_G.DatabaseReady = false

-- Detect inventory system
CreateThread(function()
    if GetResourceState('ox_inventory') == 'started' then
        InventoryType = 'ox_inventory'
        print('^2[StashManager]^7 Detected inventory: ox_inventory')
    elseif GetResourceState('qb-inventory') == 'started' then
        InventoryType = 'qb-inventory'
        print('^2[StashManager]^7 Detected inventory: qb-inventory')
    elseif GetResourceState('qs-inventory') == 'started' then
        InventoryType = 'qs-inventory'
        print('^2[StashManager]^7 Detected inventory: qs-inventory')
    elseif GetResourceState('ps-inventory') == 'started' then
        InventoryType = 'ps-inventory'
        print('^2[StashManager]^7 Detected inventory: ps-inventory')
    else
        print('^1[StashManager]^7 No supported inventory detected!')
    end
end)

-- Initialize database on resource start
CreateThread(function()
    print('^3[StashManager]^7 Initializing...')
    InitializeDatabase()
    
    local attempts = 0
    while not _G.DatabaseReady and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
    end
    
    if _G.DatabaseReady then
        print('^2[StashManager]^7 Database ready, loading stashes...')
        LoadBlipSettings()
        LoadAllStashes()
        Wait(500)
        CreateDefaultStashes()
    else
        print('^1[StashManager]^7 Database initialization timeout!')
    end
end)

function LoadBlipSettings()
    GetBlipSettings(function(settings)
        BlipSettings = settings
        print('^2[StashManager]^7 Loaded blip settings for ' .. CountTableEntries(settings) .. ' stash types')
    end)
end

function CountTableEntries(tbl)
    local count = 0
    if not tbl then return 0 end
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function LoadAllStashes()
    GetAllStashes(function(stashes)
        GetAllStashAccess(function(accessRows)
            SharedAccess = {}
            for _, access in pairs(accessRows) do
                SharedAccess[access.stash_id] = SharedAccess[access.stash_id] or {}
                SharedAccess[access.stash_id][access.citizenid] = {
                    is_manager = NormalizeManagerFlag(access.is_manager)
                }
            end

            for _, stash in pairs(stashes) do
                stash.access = SharedAccess[stash.id] or {}
                RegisterStashWithInventory(stash)
                ActiveStashes[stash.id] = stash
            end

            print('^2[StashManager]^7 Loaded ' .. #stashes .. ' stashes')
        end)
    end)
end

function CreateDefaultStashes()
    for _, stash in pairs(Config.DefaultStashes) do
        if not stash.coords or type(stash.coords) ~= 'vector3' then
            goto continue
        end
        
        StashExists(stash.name, function(exists)
            if not exists then
                local data = {
                    name = stash.name,
                    type = stash.type,
                    owner = nil,
                    job = stash.job,
                    coords = {x = stash.coords.x, y = stash.coords.y, z = stash.coords.z},
                    slots = stash.slots,
                    weight = stash.weight,
                    ped_model = stash.ped,
                    ped_offset = nil,
                    ped_heading = 0.0,
                    object_model = stash.object,
                    object_offset = stash.objectOffset,
                    object_heading = stash.objectHeading or 0.0,
                    created_by = 'system'
                }
                
                CreateStash(data, function(id)
                    if id then
                        data.id = id
                        data.coords = json.encode(data.coords)
                        RegisterStashWithInventory(data)
                        ActiveStashes[id] = data
                        print('^2[StashManager]^7 Created: ' .. stash.name)
                        TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
                    end
                end)
            end
        end)
        
        ::continue::
    end
end

function RegisterStashWithInventory(stash)
    local stashId = GenerateStashId(stash)
    
    if InventoryType == 'ox_inventory' then
        -- ox_inventory pre-registration
        exports.ox_inventory:RegisterStash(stashId, stash.name, stash.slots, stash.weight, stash.owner)
        
    elseif InventoryType == 'qb-inventory' then
        -- qb-inventory pre-registration
        exports['qb-inventory']:RegisterStash(stashId, {
            label = stash.name,
            slots = stash.slots,
            weight = stash.weight,
            owner = stash.owner
        })
        
    elseif InventoryType == 'qs-inventory' then
        -- qs-inventory pre-registration
        exports['qs-inventory']:RegisterStash(stashId, stash.name, stash.slots, stash.weight)
        
    elseif InventoryType == 'ps-inventory' then
        -- ps-inventory pre-registration (same as qb-inventory)
        exports['ps-inventory']:RegisterStash(stashId, {
            label = stash.name,
            slots = stash.slots,
            weight = stash.weight,
            owner = stash.owner
        })
    end
    
    print('^2[StashManager]^7 Registered stash: ' .. stashId .. ' with ' .. InventoryType)
end


function GenerateStashId(stash)
    if stash.type == 'private' then
        return 'stash_private_' .. stash.owner .. '_' .. stash.id
    elseif stash.type == 'job' then
        return 'stash_job_' .. stash.job .. '_' .. stash.id
    elseif stash.type == 'shared' then
        return 'stash_shared_' .. stash.id
    else
        return 'stash_public_' .. stash.id
    end
end

function CanAccessStash(Player, stash)
    if stash.type == 'public' then
        return true
    elseif stash.type == 'private' then
        return stash.owner == Player.PlayerData.citizenid
    elseif stash.type == 'job' then
        return Player.PlayerData.job and Player.PlayerData.job.name == stash.job
    elseif stash.type == 'shared' then
        local access = SharedAccess[stash.id]
        if not access then return false end
        local record = access[Player.PlayerData.citizenid]
        return record ~= nil
    end
    return false
end


-- Callbacks
QBCore.Functions.CreateCallback('qb-stashmanager:server:GetAllStashes', function(source, cb)
    GetAllStashes(function(stashes)
        cb(stashes)
    end)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetAccessibleStashes', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    
    local accessibleStashes = {}
    for _, stash in pairs(ActiveStashes) do
        if CanAccessStash(Player, stash) then
            -- For shared stashes, include access information for client-side blip checking
            if stash.type == 'shared' then
                stash.access = SharedAccess[stash.id] or {}
            end
            table.insert(accessibleStashes, stash)
        end
    end
    cb(accessibleStashes)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:IsAdmin', function(source, cb)
    cb(QBCore.Functions.HasPermission(source, Config.AdminGroup))
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetCitizenId', function(source, cb, targetId)
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    cb(targetPlayer and targetPlayer.PlayerData.citizenid or nil)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetPlayerName', function(source, cb, citizenid)
    MySQL.query('SELECT JSON_EXTRACT(charinfo, "$.firstname") as firstname, JSON_EXTRACT(charinfo, "$.lastname") as lastname FROM players WHERE citizenid = ?', {citizenid}, function(result)
        if result[1] then
            local firstname = result[1].firstname:gsub('"', '')
            local lastname = result[1].lastname:gsub('"', '')
            cb(firstname .. ' ' .. lastname)
        else
            cb(nil)
        end
    end)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetManagedSharedStashes', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end

    GetSharedStashesForCitizen(Player.PlayerData.citizenid, function(stashes)
        local result = {}
        for _, stash in pairs(stashes) do
            if stash.type == 'shared' then
                local isManager = NormalizeManagerFlag(stash.is_manager)
                stash.access = SharedAccess[stash.id] or {}
                stash.is_manager = isManager
                stash.can_manage = isManager or (stash.created_by == Player.PlayerData.citizenid)
                table.insert(result, stash)
            end
        end
        cb(result)
    end)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetSharedStashMembers', function(source, cb, stashId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(nil, 'no_player') return end

    local stash = ActiveStashes[stashId]
    if not stash or stash.type ~= 'shared' then
        cb(nil, 'not_found')
        return
    end

    local access = SharedAccess[stashId]
    if not IsSharedManager(stash, Player.PlayerData.citizenid) then
        cb(nil, 'no_permission')
        return
    end

    local members = {}
    for citizenid, data in pairs(access or {}) do
        table.insert(members, {
            citizenid = citizenid,
            is_manager = data.is_manager and true or false
        })
    end

    cb(members)
end)

-- Access logs callbacks
QBCore.Functions.CreateCallback('qb-stashmanager:server:GetStashLogs', function(source, cb, stashId, limit, offset)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not QBCore.Functions.HasPermission(source, Config.AdminGroup) then
        cb({})
        return
    end
    
    GetStashLogs(stashId, limit or 50, offset or 0, function(logs)
        cb(logs)
    end)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetRecentLogs', function(source, cb, limit)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not QBCore.Functions.HasPermission(source, Config.AdminGroup) then
        cb({})
        return
    end
    
    GetRecentStashLogs(limit or 100, function(logs)
        cb(logs)
    end)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetLogsByCitizen', function(source, cb, citizenid, limit, offset)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not QBCore.Functions.HasPermission(source, Config.AdminGroup) then
        cb({})
        return
    end
    
    GetStashLogsByCitizen(citizenid, limit or 100, offset or 0, function(logs)
        cb(logs)
    end)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetStashLogStats', function(source, cb, stashId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not QBCore.Functions.HasPermission(source, Config.AdminGroup) then
        cb({})
        return
    end
    
    GetStashLogStats(stashId, function(stats)
        cb(stats)
    end)
end)

-- Blip settings callbacks
QBCore.Functions.CreateCallback('qb-stashmanager:server:GetBlipSettings', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not QBCore.Functions.HasPermission(source, Config.AdminGroup) then
        cb({})
        return
    end
    
    cb(BlipSettings)
end)

QBCore.Functions.CreateCallback('qb-stashmanager:server:GetBlipSetting', function(source, cb, stashType)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not QBCore.Functions.HasPermission(source, Config.AdminGroup) then
        cb(nil)
        return
    end
    
    GetBlipSettingByType(stashType, function(setting)
        cb(setting)
    end)
end)

-- Events
RegisterNetEvent('qb-stashmanager:server:OpenStash', function(stashId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local stash = ActiveStashes[stashId]
    if not stash then
        SendNotify(src, 'Stash not found', 'error')
        return
    end
    
    -- Allow admins to bypass access check
    local isAdmin = QBCore.Functions.HasPermission(src, Config.AdminGroup)
    if not isAdmin and not CanAccessStash(Player, stash) then
        SendNotify(src, 'No access', 'error')
        return
    end
    
    -- Log stash access (with admin flag if applicable)
    local logDetails = isAdmin and {admin_bypass = true} or nil
    LogStashAccess(stashId, stash.name, Player.PlayerData.citizenid, 'open', nil, nil, logDetails)
    
    local inventoryStashId = GenerateStashId(stash)
    
    if InventoryType == 'ox_inventory' then
        exports.ox_inventory:forceOpenInventory(src, 'stash', inventoryStashId)
    elseif InventoryType == 'qb-inventory' then
        TriggerClientEvent('inventory:client:SetCurrentStash', src, inventoryStashId)
        TriggerEvent('inventory:server:OpenInventory', 'stash', inventoryStashId, {
            maxweight = stash.weight,
            slots = stash.slots
        })
    elseif InventoryType == 'qs-inventory' then
        exports['qs-inventory']:OpenInventory(src, inventoryStashId, {
            maxweight = stash.weight,
            slots = stash.slots
        })
    elseif InventoryType == 'ps-inventory' then
        TriggerClientEvent('inventory:client:SetCurrentStash', src, inventoryStashId)
        TriggerEvent('inventory:server:OpenInventory', 'stash', inventoryStashId, {
            maxweight = stash.weight,
            slots = stash.slots
        })
    end
end)

RegisterNetEvent('qb-stashmanager:server:CreateStash', function(data, accessList)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        SendNotify(src, 'No permission', 'error')
        return
    end
    
    if type(data.coords) == 'vector3' then
        data.coords = {x = data.coords.x, y = data.coords.y, z = data.coords.z}
    end
    
    data.created_by = Player.PlayerData.citizenid
    
    CreateStash(data, function(id)
        if id then
            data.id = id
            data.coords = json.encode(data.coords)
            data.access = {}
            if data.type == 'shared' then
                SharedAccess[id] = {}
                if type(accessList) == 'table' then
                    for _, entry in pairs(accessList) do
                        if entry.citizenid then
                            local isManager = NormalizeManagerFlag(entry.is_manager)
                            if isManager then
                                SharedAccess[id] = SharedAccess[id] or {}
                                for citizen, dataEntry in pairs(SharedAccess[id]) do
                                    if dataEntry.is_manager then
                                        dataEntry.is_manager = false
                                        AddOrUpdateStashAccess(id, citizen, false)
                                    end
                                end
                            end
                            AddOrUpdateStashAccess(id, entry.citizenid, isManager)
                            SharedAccess[id][entry.citizenid] = {is_manager = isManager}
                            data.access[entry.citizenid] = {is_manager = isManager}
                            local targetPlayerId = GetPlayerIdByCitizenId(entry.citizenid)
                            if targetPlayerId then
                                TriggerClientEvent('qb-stashmanager:client:RefreshStashes', targetPlayerId)
                            end
                        end
                    end
                end
            end
            RegisterStashWithInventory(data)
            ActiveStashes[id] = data
            SendNotify(src, 'Stash created', 'success')
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
        else
            SendNotify(src, 'Failed to create', 'error')
        end
    end)
end)

RegisterNetEvent('qb-stashmanager:server:CreatePrivateStash', function(data, citizenid)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        SendNotify(src, 'No permission', 'error')
        return
    end
    
    MySQL.query('SELECT citizenid FROM players WHERE citizenid = ?', {citizenid}, function(result)
        if not result[1] then
            SendNotify(src, 'Citizen ID not found', 'error')
            return
        end
        
        if type(data.coords) == 'vector3' then
            data.coords = {x = data.coords.x, y = data.coords.y, z = data.coords.z}
        end
        
        data.owner = citizenid
        data.created_by = Player.PlayerData.citizenid
        
        CreateStash(data, function(id)
            if id then
                data.id = id
                data.coords = json.encode(data.coords)
                RegisterStashWithInventory(data)
                ActiveStashes[id] = data
                SendNotify(src, 'Private stash created', 'success')
                TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
            else
                SendNotify(src, 'Failed to create', 'error')
            end
        end)
    end)
end)

RegisterNetEvent('qb-stashmanager:server:UpdateStash', function(id, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        SendNotify(src, 'No permission', 'error')
        return
    end
    
    if type(data.coords) == 'vector3' then
        data.coords = {x = data.coords.x, y = data.coords.y, z = data.coords.z}
    end
    
    -- Preserve show_blip if not provided
    if data.show_blip == nil then
        local currentStash = ActiveStashes[id]
        if currentStash then
            data.show_blip = currentStash.show_blip
        end
    end
    
    UpdateStash(id, data, function(success)
        if success then
            data.id = id
            data.coords = json.encode(data.coords)
            if data.type == 'shared' then
                data.access = SharedAccess[id] or {}
            else
                if SharedAccess[id] then
                    SharedAccess[id] = nil
                    MySQL.query('DELETE FROM stash_access WHERE stash_id = ?', {id})
                end
                data.access = nil
            end
            RegisterStashWithInventory(data)
            ActiveStashes[id] = data
            SendNotify(src, 'Stash updated', 'success')
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
        else
            SendNotify(src, 'Failed to update', 'error')
        end
    end)
end)

RegisterNetEvent('qb-stashmanager:server:DeleteStash', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        SendNotify(src, 'No permission', 'error')
        return
    end
    
    DeleteStash(id, function(success)
        if success then
            ActiveStashes[id] = nil
            SharedAccess[id] = nil
            SendNotify(src, 'Stash deleted', 'success')
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
        else
            SendNotify(src, 'Failed to delete', 'error')
        end
    end)
end)

RegisterNetEvent('qb-stashmanager:server:AddSharedAccess', function(stashId, citizenid, makeManager)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    stashId = tonumber(stashId)
    if not Player or not stashId or not citizenid then return end

    local stash = ActiveStashes[stashId]
    if not stash or stash.type ~= 'shared' then return end

    local access = SharedAccess[stashId]
    if not IsSharedManager(stash, Player.PlayerData.citizenid) then
        SendNotify(src, 'No permission', 'error')
        return
    end

    if access and access[citizenid] then
        SendNotify(src, 'Player already has access', 'error')
        return
    end

    MySQL.query('SELECT citizenid FROM players WHERE citizenid = ?', {citizenid}, function(result)
        if not result or not result[1] then
            SendNotify(src, 'Citizen ID not found', 'error')
            return
        end

        local isManager = makeManager and true or false
        SharedAccess[stashId] = SharedAccess[stashId] or {}

        AddOrUpdateStashAccess(stashId, citizenid, isManager, function(success)
            if not success then
                SendNotify(src, 'Failed to update access', 'error')
                return
            end

            SharedAccess[stashId][citizenid] = {is_manager = isManager}
            if ActiveStashes[stashId] then
                ActiveStashes[stashId].access = SharedAccess[stashId]
            end

            SendNotify(src, 'Access granted', 'success')

            local targetPlayerId = GetPlayerIdByCitizenId(citizenid)
            if targetPlayerId then
                SendNotify(targetPlayerId, 'You were added to shared stash ' .. stash.name, 'success')
            end

            RefreshSharedMembers(stashId)
        end)
    end)
end)

RegisterNetEvent('qb-stashmanager:server:RemoveSharedAccess', function(stashId, citizenid)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    stashId = tonumber(stashId)
    if not Player or not stashId or not citizenid then return end

    local stash = ActiveStashes[stashId]
    if not stash or stash.type ~= 'shared' then return end

    local access = SharedAccess[stashId]
    if not IsSharedManager(stash, Player.PlayerData.citizenid) then
        SendNotify(src, 'No permission', 'error')
        return
    end

    if not access then
        SendNotify(src, 'Stash has no members', 'error')
        return
    end

    local targetAccess = access[citizenid]
    if not targetAccess then
        SendNotify(src, 'Player does not have access', 'error')
        return
    end

    if targetAccess.is_manager then
        local managerCount = 0
        for _, entry in pairs(access) do
            if entry.is_manager then managerCount = managerCount + 1 end
        end
        if managerCount <= 1 then
            SendNotify(src, 'Cannot remove the last manager', 'error')
            return
        end
    end

    RemoveStashAccess(stashId, citizenid, function(success)
        if not success then
            SendNotify(src, 'Failed to remove access', 'error')
            return
        end

        SharedAccess[stashId][citizenid] = nil
        if ActiveStashes[stashId] then
            ActiveStashes[stashId].access = SharedAccess[stashId]
        end

        SendNotify(src, 'Access removed', 'success')

        local targetPlayerId = GetPlayerIdByCitizenId(citizenid)
        if targetPlayerId then
            SendNotify(targetPlayerId, 'You were removed from shared stash ' .. stash.name, 'error')
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', targetPlayerId)
        end

        RefreshSharedMembers(stashId)
    end)
end)

RegisterNetEvent('qb-stashmanager:server:TransferSharedManager', function(stashId, citizenid)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    stashId = tonumber(stashId)
    if not Player or not stashId or not citizenid then return end

    local stash = ActiveStashes[stashId]
    if not stash or stash.type ~= 'shared' then return end

    if not SharedAccess[stashId] or not SharedAccess[stashId][citizenid] then
        SendNotify(src, 'Player does not have access', 'error')
        return
    end

    if not IsSharedManager(stash, Player.PlayerData.citizenid) then
        SendNotify(src, 'No permission', 'error')
        return
    end

    SetSharedManager(stashId, citizenid)

    SendNotify(src, 'Ownership transferred', 'success')

    local targetPlayerId = GetPlayerIdByCitizenId(citizenid)
    if targetPlayerId then
        SendNotify(targetPlayerId, 'You are now the manager of shared stash ' .. stash.name, 'success')
    end

    RefreshSharedMembers(stashId)
end)

RegisterNetEvent('qb-stashmanager:server:RenameSharedStash', function(stashId, newName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    stashId = tonumber(stashId)
    if not Player or not stashId or not newName then return end

    newName = tostring(newName)
    newName = newName:gsub('^%s+', ''):gsub('%s+$', '')
    if newName == '' then
        SendNotify(src, 'Invalid name', 'error')
        return
    end

    newName = string.sub(newName, 1, 50)

    local stash = ActiveStashes[stashId]
    if not stash or stash.type ~= 'shared' then return end

    if not IsSharedManager(stash, Player.PlayerData.citizenid) then
        SendNotify(src, 'No permission', 'error')
        return
    end

    RenameStash(stashId, newName, function(success)
        if not success then
            SendNotify(src, 'Failed to rename stash', 'error')
            return
        end

        ActiveStashes[stashId].name = newName
        RegisterStashWithInventory(ActiveStashes[stashId])

        SendNotify(src, 'Stash renamed', 'success')
        RefreshSharedMembers(stashId)
    end)
end)

RegisterNetEvent('qb-stashmanager:server:UpdateBlipSetting', function(stashType, sprite, color, label)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        SendNotify(src, 'No permission', 'error')
        return
    end
    
    if not stashType or not sprite or not color then
        SendNotify(src, 'Invalid parameters', 'error')
        return
    end
    
    UpdateBlipSetting(stashType, sprite, color, label, function(success)
        if success then
            -- Reload blip settings
            LoadBlipSettings()
            SendNotify(src, 'Blip setting updated!', 'success')
            -- Refresh all client blips
            TriggerClientEvent('qb-stashmanager:client:RefreshBlipSettings', -1)
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
        else
            SendNotify(src, 'Failed to update blip setting', 'error')
        end
    end)
end)

-- Item change logging (called from inventory hooks)
RegisterNetEvent('qb-stashmanager:server:LogItemChange', function(stashId, citizenid, action, itemName, itemAmount, details)
    local stash = ActiveStashes[stashId]
    if not stash then return end
    
    LogStashAccess(stashId, stash.name, citizenid, action, itemName, itemAmount, details)
end)

-- Inventory hooks for item tracking (ox_inventory)
if InventoryType == 'ox_inventory' then
    AddEventHandler('ox_inventory:itemTransfer', function(data)
        if not data or not data.toType or (data.toType ~= 'stash' and data.fromType ~= 'stash') then return end
        
        -- Extract stash ID from stash identifier (e.g., 'stash_private_CITIZENID_123')
        local stashIdentifier = data.toType == 'stash' and data.toId or data.fromId
        if not stashIdentifier or not stashIdentifier:match('stash_') then return end
        
        -- Find the stash by matching the generated ID
        local stashId = nil
        for id, stash in pairs(ActiveStashes) do
            if GenerateStashId(stash) == stashIdentifier then
                stashId = id
                break
            end
        end
        
        if stashId then
            local Player = nil
            local action = nil
            local itemName = nil
            local itemAmount = nil
            
            if data.toType == 'stash' and data.fromType == 'player' then
                -- Item added to stash
                Player = QBCore.Functions.GetPlayer(data.fromId)
                action = 'item_added'
                itemName = data.toItem and data.toItem.name
                itemAmount = data.toItem and data.toItem.count
            elseif data.fromType == 'stash' and data.toType == 'player' then
                -- Item removed from stash
                Player = QBCore.Functions.GetPlayer(data.toId)
                action = 'item_removed'
                itemName = data.fromItem and data.fromItem.name
                itemAmount = data.fromItem and data.fromItem.count
            end
            
            if Player and action then
                LogStashAccess(stashId, ActiveStashes[stashId].name, Player.PlayerData.citizenid, action, itemName, itemAmount, {
                    from = data.fromType,
                    to = data.toType,
                    slot = data.toSlot or data.fromSlot
                })
            end
        end
    end)
end
