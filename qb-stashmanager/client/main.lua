-- client/main.lua - ----AG---QBCore Stash Manager (FIXED)
local QBCore = exports['qb-core']:GetCoreObject()

local ActiveStashes = {}
local SpawnedPeds = {}
local SpawnedObjects = {}
local StashBlips = {}
local CreatedZones = {}
local BlipSettings = {} -- Store blip settings from server

local function Notify(message, notifType, duration)
    notifType = notifType or 'primary'
    duration = duration or 5000

    if Config.Notification == 'ox' and lib and lib.notify then
        lib.notify({
            title = 'Stash Manager',
            description = message,
            type = notifType,
            duration = duration
        })
    else
        QBCore.Functions.Notify(message, notifType, duration)
    end
end

RegisterNetEvent('qb-stashmanager:client:Notify', function(message, notifType, duration)
    Notify(message, notifType, duration)
end)

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
        LoadBlipSettings()
        ClearStashPoints()
        CreateStashPoints()
    end)
end

function LoadBlipSettings()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetBlipSettings', function(settings)
        BlipSettings = settings
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
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData then return end
    
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
        
        -- Check if player has access to this stash (blips only show for accessible stashes)
        local hasAccess = false
        if stash.type == 'public' then
            hasAccess = true
        elseif stash.type == 'private' then
            hasAccess = stash.owner == playerData.citizenid
        elseif stash.type == 'job' then
            hasAccess = playerData.job and playerData.job.name == stash.job
        elseif stash.type == 'shared' then
            -- Check if player is in access list
            if stash.access then
                hasAccess = stash.access[playerData.citizenid] ~= nil
            end
        end
        
        -- Only proceed if player has access
        if not hasAccess then
            goto continue
        end
        
        local vector = vector3(coords.x, coords.y, coords.z)
        
        local hasPedOrObject = false
        
        if stash.ped_model then
            SpawnStashPed(stash, vector)
            hasPedOrObject = true
        end
        
        if stash.object_model then
            SpawnStashObject(stash, vector)
            hasPedOrObject = true
        end
        
        -- Check if blip should be shown (per stash setting or global config)
        -- Note: Only accessible stashes will have blips created
        local showBlip = stash.show_blip
        if showBlip == nil then
            showBlip = Config.ShowBlips
        else
            showBlip = showBlip == 1 or showBlip == true
        end
        
        if showBlip then
            CreateStashBlip(stash, vector)
        end
        ----if faill
if not hasPedOrObject then
    exports[Config.TargetResource]:addBoxZone({
        coords = vector,
        size = vec3(2.0, 2.0, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'open_stash_' .. stash.id,
                icon = 'fas fa-box',
                label = 'Open ' .. stash.name,
                onSelect = function()
                    TriggerServerEvent('qb-stashmanager:server:OpenStash', stash.id)
                end
            }
        }
    })
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
    -- Priority 1: Use custom blip settings if set for this specific stash
    if stash.blip_sprite and stash.blip_color then
        local blipLabel = stash.blip_label or stash.name
        
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, stash.blip_sprite)
        SetBlipScale(blip, Config.BlipScale)
        SetBlipColour(blip, stash.blip_color)
        SetBlipAsShortRange(blip, Config.BlipShortRange)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(blipLabel)
        EndTextCommandSetBlipName(blip)
        
        StashBlips[stash.id] = blip
        return
    end
    
    -- Priority 2: Get blip settings for this stash type from database
    local blipSettings = nil
    if BlipSettings and BlipSettings[stash.type] then
        blipSettings = BlipSettings[stash.type]
    end
    
    -- Priority 3: Use Config settings
    if not blipSettings then
        blipSettings = Config.BlipSettings and Config.BlipSettings[stash.type]
    end
    
    -- Priority 4: Ultimate fallback to default settings
    if not blipSettings then
        blipSettings = {
            sprite = 478,
            color = 3,
            label = 'Stash'
        }
    end
    
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipSettings.sprite)
    SetBlipScale(blip, Config.BlipScale)
    SetBlipColour(blip, blipSettings.color)
    SetBlipAsShortRange(blip, Config.BlipShortRange)
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

RegisterNetEvent('qb-stashmanager:client:RefreshBlipSettings', function()
    LoadBlipSettings()
end)

RegisterCommand('stashmanager', function()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:IsAdmin', function(isAdmin)
        if isAdmin then
            OpenStashManagerMenu()
        else
            Notify('No permission', 'error')
        end
    end)
end)

RegisterCommand('sharedstash', function()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetManagedSharedStashes', function(stashes)
        if not stashes or (type(stashes) == 'table' and next(stashes) == nil) then
            Notify('No shared stashes found', 'error')
            return
        end

        OpenSharedStashesMenu(stashes)
    end)
end)

RegisterCommand('createprivatestash', function(source, args)
    if not args[1] then
        Notify('Usage: /createprivatestash [citizenid]', 'error')
        return
    end
    
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:IsAdmin', function(isAdmin)
        if not isAdmin then
            Notify('No permission', 'error')
            return
        end
        
        local citizenid = args[1]:upper()
        
        QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetPlayerName', function(playerName)
            if playerName then
                local input = lib.inputDialog('Create Private Stash for ' .. playerName, {
                    {type = 'input', label = 'Stash Name', required = true, max = 50, default = playerName .. '\'s Stash'},
                    {type = 'number', label = 'Slots', default = Config.DefaultSlots, min = 1, max = 500},
                    {type = 'number', label = 'Weight (grams)', default = Config.DefaultWeight, min = 1000, max = 10000000},
                    {type = 'checkbox', label = 'Show Blip on Map', description = 'Enable map blip for this stash', checked = Config.ShowBlips},
                    {type = 'input', label = 'Ped Model (optional)', required = false},
                    {type = 'input', label = 'Object Model (optional)', required = false}
                })
                
                if input then
                    -- input indices: [1]=name, [2]=slots, [3]=weight, [4]=show_blip, [5]=ped_model, [6]=object_model
                    local showBlip = input[4] ~= nil and input[4] or Config.ShowBlips
                    input.show_blip = showBlip
                    
                    -- If blip is enabled, show blip configuration
                    if showBlip then
                        QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetBlipSetting', function(blipSetting)
                            local defaultSprite = 478
                            local defaultColor = 3
                            local defaultLabel = input[1]
                            
                            if blipSetting then
                                defaultSprite = blipSetting.sprite or 478
                                defaultColor = blipSetting.color or 3
                                defaultLabel = blipSetting.label or input[1]
                            end
                            
                            local blipInput = lib.inputDialog('Configure Blip Settings', {
                                {type = 'number', label = 'Blip Sprite ID', description = 'Enter blip sprite ID (e.g., 478 for box)', default = defaultSprite, required = true, min = 1, max = 826},
                                {type = 'number', label = 'Blip Color ID', description = 'Enter blip color ID (0-85)', default = defaultColor, required = true, min = 0, max = 85},
                                {type = 'input', label = 'Blip Label', description = 'Text displayed on blip (optional, uses stash name if empty)', default = defaultLabel, required = false, max = 100}
                            })
                            
                            if blipInput then
                                input.blip_sprite = blipInput[1]
                                input.blip_color = blipInput[2]
                                input.blip_label = blipInput[3] ~= '' and blipInput[3] or nil
                                CreatePrivateStashWithCitizenId(input, citizenid, nil, nil)
                            end
                        end, 'private')
                    else
                        CreatePrivateStashWithCitizenId(input, citizenid, nil, nil)
                    end
                end
            else
                Notify('Citizen ID not found', 'error')
            end
        end, citizenid)
    end)
end)


AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ClearStashPoints()
    end
end)
