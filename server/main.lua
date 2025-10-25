-- server/main.lua - QBCore with Multi-Inventory Support (ox_inventory, qb-inventory, qs-inventory)
local QBCore = exports['qb-core']:GetCoreObject()
local ActiveStashes = {}
local InventoryType = nil

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
        LoadAllStashes()
        Wait(500)
        CreateDefaultStashes()
    else
        print('^1[StashManager]^7 Database initialization timeout!')
    end
end)

function LoadAllStashes()
    GetAllStashes(function(stashes)
        for _, stash in pairs(stashes) do
            RegisterStashWithInventory(stash)
            ActiveStashes[stash.id] = stash
        end
        print('^2[StashManager]^7 Loaded ' .. #stashes .. ' stashes')
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

-- Events
RegisterNetEvent('qb-stashmanager:server:OpenStash', function(stashId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local stash = ActiveStashes[stashId]
    if not stash then
        TriggerClientEvent('QBCore:Notify', src, 'Stash not found', 'error')
        return
    end
    
    if not CanAccessStash(Player, stash) then
        TriggerClientEvent('QBCore:Notify', src, 'No access', 'error')
        return
    end
    
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

RegisterNetEvent('qb-stashmanager:server:CreateStash', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
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
            RegisterStashWithInventory(data)
            ActiveStashes[id] = data
            TriggerClientEvent('QBCore:Notify', src, 'Stash created', 'success')
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Failed to create', 'error')
        end
    end)
end)

RegisterNetEvent('qb-stashmanager:server:CreatePrivateStash', function(data, citizenid)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    MySQL.query('SELECT citizenid FROM players WHERE citizenid = ?', {citizenid}, function(result)
        if not result[1] then
            TriggerClientEvent('QBCore:Notify', src, 'Citizen ID not found', 'error')
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
                TriggerClientEvent('QBCore:Notify', src, 'Private stash created', 'success')
                TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
            else
                TriggerClientEvent('QBCore:Notify', src, 'Failed to create', 'error')
            end
        end)
    end)
end)

RegisterNetEvent('qb-stashmanager:server:UpdateStash', function(id, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    if type(data.coords) == 'vector3' then
        data.coords = {x = data.coords.x, y = data.coords.y, z = data.coords.z}
    end
    
    UpdateStash(id, data, function(success)
        if success then
            data.id = id
            data.coords = json.encode(data.coords)
            RegisterStashWithInventory(data)
            ActiveStashes[id] = data
            TriggerClientEvent('QBCore:Notify', src, 'Stash updated', 'success')
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Failed to update', 'error')
        end
    end)
end)

RegisterNetEvent('qb-stashmanager:server:DeleteStash', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not QBCore.Functions.HasPermission(src, Config.AdminGroup) then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    DeleteStash(id, function(success)
        if success then
            ActiveStashes[id] = nil
            TriggerClientEvent('QBCore:Notify', src, 'Stash deleted', 'success')
            TriggerClientEvent('qb-stashmanager:client:RefreshStashes', -1)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Failed to delete', 'error')
        end
    end)
end)
