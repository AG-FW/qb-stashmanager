local QBCore = exports['qb-core']:GetCoreObject()local ActiveStashes = {}
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
    Framework.TriggerCallback('qb-stashmanager:server:GetAccessibleStashes', function(stashes)
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
        
        if Config.UseTarget then
            CreateTargetInteraction(stash, vector)
        else
            CreateZoneInteraction(stash, vector)
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
        --print('^1[StashManager]^7 Failed to load ped: ' .. stash.ped_model)
        return
    end
    
    -- Handle ped offset
    local offset = {x = 0.0, y = 0.0, z = 0.0}
    if stash.ped_offset then
        if type(stash.ped_offset) == 'table' then
            offset = stash.ped_offset
            --print('^2[StashManager]^7 Using ped offset (table): X=' .. offset.x .. ' Y=' .. offset.y .. ' Z=' .. offset.z)
        elseif type(stash.ped_offset) == 'string' then
            local success, result = pcall(function()
                return json.decode(stash.ped_offset)
            end)
            if success and result then
                offset = result
                --print('^2[StashManager]^7 Decoded ped offset: X=' .. offset.x .. ' Y=' .. offset.y .. ' Z=' .. offset.z)
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
    --print('^2[StashManager]^7 Spawned ped for: ' .. stash.name .. ' at heading: ' .. (stash.ped_heading or 0.0))
end


function SpawnStashObject(stash, coords)
    if not stash.object_model then return end
    
    --print('^3[StashManager]^7 Attempting to spawn object: ' .. stash.object_model)
    
    -- Check if object_offset is already a table or needs decoding
    local offsetType = type(stash.object_offset)
    --print('^3[StashManager]^7 Object offset type: ' .. offsetType)
    
    if offsetType == 'table' then
        --print('^3[StashManager]^7 Offset already decoded as table')
    elseif offsetType == 'string' then
        --print('^3[StashManager]^7 Offset is JSON string: ' .. stash.object_offset)
    else
        --print('^3[StashManager]^7 No offset found')
    end
    
    local objectModel = GetHashKey(stash.object_model)
    RequestModel(objectModel)
    
    local timeout = 0
    while not HasModelLoaded(objectModel) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(objectModel) then
        --print('^1[StashManager]^7 Failed to load object: ' .. stash.object_model)
        return
    end
    
    local offset = {x = 0.0, y = 0.0, z = 0.0}
    
    if stash.object_offset then
        if type(stash.object_offset) == 'table' then
            -- Already decoded
            offset = stash.object_offset
            --print('^2[StashManager]^7 Using pre-decoded offset: X=' .. offset.x .. ' Y=' .. offset.y .. ' Z=' .. offset.z)
        elseif type(stash.object_offset) == 'string' then
            -- Need to decode JSON
            local success, result = pcall(function()
                return json.decode(stash.object_offset)
            end)
            if success and result then
                offset = result
                --print('^2[StashManager]^7 Decoded offset: X=' .. offset.x .. ' Y=' .. offset.y .. ' Z=' .. offset.z)
            else
                --print('^1[StashManager]^7 Failed to decode offset!')
            end
        end
    else
        --print('^1[StashManager]^7 No offset found in database for: ' .. stash.name)
    end
    
    local finalCoords = vector3(
        coords.x + (offset.x or 0.0),
        coords.y + (offset.y or 0.0),
        coords.z + (offset.z or 0.0)
    )
    
    --print('^2[StashManager]^7 Final spawn coords: X=' .. finalCoords.x .. ' Y=' .. finalCoords.y .. ' Z=' .. finalCoords.z)
    --print('^2[StashManager]^7 Heading: ' .. (stash.object_heading or 0.0))
    
    local object = CreateObject(objectModel, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false)
    SetEntityHeading(object, stash.object_heading or 0.0)
    FreezeEntityPosition(object, true)
    SetEntityAsMissionEntity(object, true, true)
    
    SpawnedObjects[stash.id] = object
    --print('^2[StashManager]^7 Spawned object for: ' .. stash.name .. ' (Entity ID: ' .. object .. ')')
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

function CreateTargetInteraction(stash, coords)
    -- If there's a ped, add target to ped
    if stash.ped_model and SpawnedPeds[stash.id] then
        Target.AddEntity(SpawnedPeds[stash.id], {
            {
                name = 'stash_' .. stash.id,
                icon = 'fas fa-box',
                label = 'Open ' .. stash.name,
                onSelect = function()
                    TriggerServerEvent('qb-stashmanager:server:OpenStash', stash.id)
                end
            }
        })
        --print('^2[StashManager]^7 Added target to ped for: ' .. stash.name)
    end
    
    -- If there's an object, add target to object
    if stash.object_model and SpawnedObjects[stash.id] then
        Target.AddEntity(SpawnedObjects[stash.id], {
            {
                name = 'stash_object_' .. stash.id,
                icon = 'fas fa-box',
                label = 'Open ' .. stash.name,
                onSelect = function()
                    TriggerServerEvent('qb-stashmanager:server:OpenStash', stash.id)
                end
            }
        })
        --print('^2[StashManager]^7 Added target to object for: ' .. stash.name)
    end
    
    -- If no ped and no object, create a zone-based target
    if not stash.ped_model and not stash.object_model then
        local zone = lib.zones.box({
            coords = coords,
            size = vec3(1.5, 1.5, 2.0),
            rotation = 0.0,
            debug = false,
            onEnter = function()
                if Config.TargetResource == 'ox_target' then
                    exports.ox_target:addBoxZone({
                        coords = coords,
                        size = vec3(1.5, 1.5, 2.0),
                        rotation = 0.0,
                        debug = false,
                        options = {
                            {
                                name = 'stash_zone_' .. stash.id,
                                icon = 'fas fa-box',
                                label = 'Open ' .. stash.name,
                                onSelect = function()
                                    TriggerServerEvent('qb-stashmanager:server:OpenStash', stash.id)
                                end
                            }
                        }
                    })
                end
            end
        })
        
        table.insert(CreatedZones, zone)
        --print('^2[StashManager]^7 Added zone target for: ' .. stash.name)
    end
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
    Framework.TriggerCallback('qb-stashmanager:server:IsAdmin', function(isAdmin)
        if isAdmin then
            OpenStashManagerMenu()
        else
            Framework.Notify('No permission', 'error')
        end
    end)
end)

RegisterCommand('createprivatestash', function(source, args)
    if not args[1] then
        Framework.Notify('Usage: /createprivatestash [citizenid]', 'error')
        return
    end
    
    Framework.TriggerCallback('qb-stashmanager:server:IsAdmin', function(isAdmin)
        if not isAdmin then
            Framework.Notify('No permission', 'error')
            return
        end
        
        local citizenid = args[1]:upper()
        
        Framework.TriggerCallback('qb-stashmanager:server:GetPlayerName', function(playerName)
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
                Framework.Notify('Citizen ID not found', 'error')
            end
        end, citizenid)
    end)
end)
