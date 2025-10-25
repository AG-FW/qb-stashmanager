-- client/main.lua - QBCore Stash Manager (FIXED)
local QBCore = exports['qb-core']:GetCoreObject()

local ActiveStashes = {}
local SpawnedPeds = {}
local SpawnedObjects = {}
local StashBlips = {}
local CreatedZones = {}

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LoadStashes()
end)

CreateThread(function()
    Wait(1000)
    LoadStashes()
end)

function LoadStashes()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetAccessibleStashes', function(stashes)
        ActiveStashes = stashes
        ClearStashPoints()
        CreateStashPoints()
    end)
end

function ClearStashPoints()
    for _, ped in pairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    SpawnedPeds = {}
    
    for _, object in pairs(SpawnedObjects) do
        if DoesEntityExist(object) then
            DeleteEntity(object)
        end
    end
    SpawnedObjects = {}
    
    for _, blip in pairs(StashBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    StashBlips = {}
    
    for _, zone in pairs(CreatedZones) do
        if zone and zone.remove then
            zone:remove()
        end
    end
    CreatedZones = {}
end

function CreateStashPoints()
    for _, stash in pairs(ActiveStashes) do
        if not stash.coords then
            goto continue
        end
        
        local coords
        local success, result = pcall(function()
            return json.decode(stash.coords)
        end)
        
        if not success or not result then
            goto continue
        end
        
        coords = result
        
        if type(coords) ~= 'table' or not coords.x or not coords.y or not coords.z then
            goto continue
        end
        
        local vector = vector3(coords.x, coords.y, coords.z)
        
        if stash.ped_model then
            SpawnStashPed(stash, vector)
        end
        
        if stash.object_model then
            SpawnStashObject(stash, vector)
        end
        
        if Config.ShowBlips then
            CreateStashBlip(stash, vector)
        end
        
        ::continue::
    end
end

function SpawnStashPed(stash, coords)
    if not stash.ped_model then return end
    
    local pedModel = GetHashKey(stash.ped_model)
    RequestModel(pedModel)
    
    local timeout = 0
    while not HasModelLoaded(pedModel) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(pedModel) then
        return
    end
    
    -- Handle ped offset
    local offset = {x = 0.0, y = 0.0, z = 0.0}
    if stash.ped_offset then
        if type(stash.ped_offset) == 'table' then
            offset = stash.ped_offset
        elseif type(stash.ped_offset) == 'string' then
            local success, result = pcall(function()
                return json.decode(stash.ped_offset)
            end)
            if success and result then
                offset = result
            end
        end
    end
    
    local finalCoords = vector3(
        coords.x + (offset.x or 0.0),
        coords.y + (offset.y or 0.0),
        coords.z + (offset.z or 0.0)
    )
    
    local ped = CreatePed(4, pedModel, finalCoords.x, finalCoords.y, finalCoords.z, stash.ped_heading or 0.0, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    SpawnedPeds[stash.id] = ped
    
    -- Add target to ped
    AddStashTarget(ped, stash)
end

function SpawnStashObject(stash, coords)
    if not stash.object_model then return end
    
    local objectModel = GetHashKey(stash.object_model)
    RequestModel(objectModel)
    
    local timeout = 0
    while not HasModelLoaded(objectModel) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(objectModel) then
        return
    end
    
    local offset = {x = 0.0, y = 0.0, z = 0.0}
    
    if stash.object_offset then
        if type(stash.object_offset) == 'table' then
            offset = stash.object_offset
        elseif type(stash.object_offset) == 'string' then
            local success, result = pcall(function()
                return json.decode(stash.object_offset)
            end)
            if success and result then
                offset = result
            end
        end
    end
    
    local finalCoords = vector3(
        coords.x + (offset.x or 0.0),
        coords.y + (offset.y or 0.0),
        coords.z + (offset.z or 0.0)
    )
    
    local object = CreateObject(objectModel, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false)
    SetEntityHeading(object, stash.object_heading or 0.0)
    FreezeEntityPosition(object, true)
    SetEntityAsMissionEntity(object, true, true)
    
    SpawnedObjects[stash.id] = object
    
    -- Add target to object
    AddStashTarget(object, stash)
end

function CreateStashBlip(stash, coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.BlipSprite)
    SetBlipScale(blip, Config.BlipScale)
    SetBlipColour(blip, Config.BlipColor)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(stash.name)
    EndTextCommandSetBlipName(blip)
    
    StashBlips[stash.id] = blip
end

function AddStashTarget(entity, stash)
    if not DoesEntityExist(entity) then return end
    
    exports[Config.TargetResource]:addLocalEntity(entity, {
        {
            name = 'open_stash_' .. stash.id,
            label = 'Open ' .. stash.name,
            icon = 'fas fa-box',
            onSelect = function()
                TriggerServerEvent('qb-stashmanager:server:OpenStash', stash.id)
            end
        }
    })
end

function CreateZoneInteraction(stash, coords)
    local zone = lib.zones.box({
        coords = coords,
        size = vec3(2.0, 2.0, 2.0),
        rotation = 0.0,
        debug = false,
        inside = function()
            DrawText3D(coords.x, coords.y, coords.z, '[E] ' .. stash.name)
            if IsControlJustPressed(0, 38) then
                TriggerServerEvent('qb-stashmanager:server:OpenStash', stash.id)
            end
        end
    })
    
    table.insert(CreatedZones, zone)
end

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

RegisterNetEvent('qb-stashmanager:client:RefreshStashes', function()
    LoadStashes()
end)

RegisterCommand('stashmanager', function()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:IsAdmin', function(isAdmin)
        if isAdmin then
            OpenStashManagerMenu()
        else
            QBCore.Functions.Notify('No permission', 'error')
        end
    end)
end)

RegisterCommand('createprivatestash', function(source, args)
    if not args[1] then
        QBCore.Functions.Notify('Usage: /createprivatestash [citizenid]', 'error')
        return
    end
    
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:IsAdmin', function(isAdmin)
        if not isAdmin then
            QBCore.Functions.Notify('No permission', 'error')
            return
        end
        
        local citizenid = args[1]:upper()
        
        QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetPlayerName', function(playerName)
            if playerName then
                local input = lib.inputDialog('Create Private Stash for ' .. playerName, {
                    {type = 'input', label = 'Stash Name', required = true, max = 50, default = playerName .. '\'s Stash'},
                    {type = 'number', label = 'Slots', default = Config.DefaultSlots, min = 1, max = 500},
                    {type = 'number', label = 'Weight (grams)', default = Config.DefaultWeight, min = 1000, max = 10000000},
                    {type = 'input', label = 'Ped Model (optional)', required = false},
                    {type = 'input', label = 'Object Model (optional)', required = false}
                })
                
                if input then
                    CreatePrivateStashWithCitizenId(input, citizenid, nil, nil)
                end
            else
                QBCore.Functions.Notify('Citizen ID not found', 'error')
            end
        end, citizenid)
    end)
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ClearStashPoints()
    end
end)
