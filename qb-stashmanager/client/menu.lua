local QBCore = exports['qb-core']:GetCoreObject()

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

local function CountTableEntries(tbl)
    local count = 0
    if not tbl then return 0 end
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function OpenStashManagerMenu()
    lib.registerContext({
        id = 'stash_manager_main',
        title = 'Stash Manager',
        options = {
            {title = 'Create New Stash', description = 'Create a new stash at your location', icon = 'plus', onSelect = function() OpenCreateStashMenu() end},
            {title = 'Manage Stashes', description = 'View and edit existing stashes', icon = 'list', onSelect = function() OpenManageStashesMenu() end},
            {title = 'Access Logs', description = 'View stash access and activity logs', icon = 'clipboard-list', onSelect = function() OpenAccessLogsMenu() end},
            {title = 'Blip Settings', description = 'Configure blip colors and sprites per stash type', icon = 'map-marked-alt', onSelect = function() OpenBlipConfigurationMenu() end}
        }
    })
    lib.showContext('stash_manager_main')
end

function OpenCreateStashMenu()
    lib.registerContext({
        id = 'stash_create_type',
        title = 'Select Stash Type',
        menu = 'stash_manager_main',
        options = {
            {title = 'Private Stash', description = 'Only the owner can access', icon = 'user', onSelect = function() OpenStashCreationForm('private') end},
            {title = 'Public Stash', description = 'Everyone can access', icon = 'users', onSelect = function() OpenStashCreationForm('public') end},
            {title = 'Job Stash', description = 'Only specific job can access', icon = 'briefcase', onSelect = function() OpenStashCreationForm('job') end},
            {title = 'Shared Stash', description = 'Multiple players with access list', icon = 'share-nodes', onSelect = function() OpenStashCreationForm('shared') end}
        }
    })
    lib.showContext('stash_create_type')
end

function OpenStashCreationForm(stashType)
    local input = lib.inputDialog('Create ' .. Config.StashTypes[stashType], {
        {type = 'input', label = 'Stash Name', description = 'Enter stash name', required = true, max = 50},
        {type = 'number', label = 'Slots', description = 'Inventory slots', default = Config.DefaultSlots, min = 1, max = 500},
        {type = 'number', label = 'Weight (grams)', description = 'Max weight', default = Config.DefaultWeight, min = 1000, max = 10000000},
        {type = 'checkbox', label = 'Show Blip on Map', description = 'Enable map blip for this stash', checked = Config.ShowBlips},
        {type = 'input', label = 'Ped Model (optional)', description = 'e.g., s_m_m_ups_01', required = false},
        {type = 'input', label = 'Object Model (optional)', description = 'e.g., prop_box_wood05a', required = false}
    })
    
    if not input then return end
    
    -- input indices: [1]=name, [2]=slots, [3]=weight, [4]=show_blip, [5]=ped_model, [6]=object_model
    local showBlip = input[4] ~= nil and input[4] or Config.ShowBlips
    
    print('^3[StashManager Debug]^7 Form submitted')
    print('^3[StashManager Debug]^7 Show blip: ' .. tostring(showBlip))
    print('^3[StashManager Debug]^7 Ped model: ' .. (input[5] or 'none'))
    print('^3[StashManager Debug]^7 Object model: ' .. (input[6] or 'none'))
    
    -- Store show_blip in the input array for passing through
    input.show_blip = showBlip
    
    -- If blip is enabled, show blip configuration dialog
    if showBlip then
        OpenBlipConfigurationDialog(input, stashType)
    else
        -- Blip disabled, proceed with stash creation
        ProceedWithStashCreationAfterBlip(input, stashType)
    end
end

function OpenBlipConfigurationDialog(stashData, stashType)
    -- Get default blip settings for this stash type
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetBlipSetting', function(blipSetting)
        local defaultSprite = 478
        local defaultColor = 3
        local defaultLabel = stashData[1] -- Use stash name as default
        
        if blipSetting then
            defaultSprite = blipSetting.sprite or 478
            defaultColor = blipSetting.color or 3
            defaultLabel = blipSetting.label or stashData[1]
        end
        
        local input = lib.inputDialog('Configure Blip Settings', {
            {type = 'number', label = 'Blip Sprite ID', description = 'Enter blip sprite ID (e.g., 478 for box)', default = defaultSprite, required = true, min = 1, max = 826},
            {type = 'number', label = 'Blip Color ID', description = 'Enter blip color ID (0-85)', default = defaultColor, required = true, min = 0, max = 85},
            {type = 'input', label = 'Blip Label', description = 'Text displayed on blip (optional, uses stash name if empty)', default = defaultLabel, required = false, max = 100}
        })
        
        if not input then 
            -- User cancelled, don't create stash
            return 
        end
        
        -- Store blip configuration
        stashData.blip_sprite = input[1]
        stashData.blip_color = input[2]
        stashData.blip_label = input[3] ~= '' and input[3] or nil
        
        -- Proceed with stash creation
        ProceedWithStashCreationAfterBlip(stashData, stashType)
    end, stashType)
end

function ProceedWithStashCreationAfterBlip(stashData, stashType)
    -- Proceed with ped/object positioning or stash creation
    if stashData[5] and stashData[5] ~= '' then
        print('^3[StashManager Debug]^7 Ped specified, opening ped positioning')
        OpenLivePedPositioning(stashData, stashType)
    elseif stashData[6] and stashData[6] ~= '' then
        print('^3[StashManager Debug]^7 Object specified, opening object positioning')
        OpenObjectPositioningMenu(stashData, stashType)
    else
        print('^3[StashManager Debug]^7 No ped/object, proceeding directly')
        if stashType == 'job' then
            OpenJobSelectionMenu(stashData, nil, nil)
        elseif stashType == 'private' then
            OpenPrivateStashOptionsMenu(stashData, nil, nil)
        elseif stashType == 'shared' then
            OpenSharedStashOptionsMenu(stashData, nil, nil)
        elseif stashType == 'public' then
            CreateStashAtLocation(stashData, 'public', nil, nil, nil, nil)
        end
    end
end

function OpenLivePedPositioning(stashData, stashType)
    print('^2[StashManager Debug]^7 Starting ped positioning')
    print('^2[StashManager Debug]^7 Ped model: ' .. stashData[5])
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local pedModel = GetHashKey(stashData[5])
    
    RequestModel(pedModel)
    
    local loadAttempts = 0
    while not HasModelLoaded(pedModel) and loadAttempts < 200 do
        Wait(100)
        loadAttempts = loadAttempts + 1
    end
    
    if not HasModelLoaded(pedModel) then
        Notify('Failed to load ped model!', 'error')
        SetModelAsNoLongerNeeded(pedModel)
        return
    end
    
    local previewPed = CreatePed(4, pedModel, playerCoords.x, playerCoords.y, playerCoords.z, 0.0, false, true)
    SetEntityAlpha(previewPed, 200, false)
    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    
    local offset = {x = 0.0, y = 1.0, z = 0.0}
    local heading = 0.0
    local baseCoords = playerCoords
    
    Notify('Arrows=Move | Q/E/Scroll=Rotate | G=Snap | Enter=Save | Backspace=Cancel', 'primary', 10000)
    
    CreateThread(function()
        local adjusting = true
        local moveSpeed = 0.05
        local rotSpeed = 5.0
        
        while adjusting do
            Wait(0)
            
            local finalX = baseCoords.x + offset.x
            local finalY = baseCoords.y + offset.y
            local finalZ = baseCoords.z + offset.z
            
            SetEntityCoords(previewPed, finalX, finalY, finalZ, false, false, false, false)
            SetEntityHeading(previewPed, heading)
            
            DrawText3DAtCoords(finalX, finalY, finalZ + 2.0, 
                string.format('~y~PED~w~ X:~g~%.2f~w~ Y:~g~%.2f~w~ Z:~g~%.2f~w~ H:~g~%.1f°', 
                offset.x, offset.y, offset.z, heading))
            
            if IsControlPressed(0, 172) then offset.y = offset.y + moveSpeed end
            if IsControlPressed(0, 173) then offset.y = offset.y - moveSpeed end
            if IsControlPressed(0, 174) then offset.x = offset.x - moveSpeed end
            if IsControlPressed(0, 175) then offset.x = offset.x + moveSpeed end
            if IsControlPressed(0, 10) then offset.z = offset.z + moveSpeed end
            if IsControlPressed(0, 11) then offset.z = offset.z - moveSpeed end
            
            if IsControlPressed(0, 44) then
                heading = heading - rotSpeed
                if heading < 0 then heading = heading + 360 end
            end
            if IsControlPressed(0, 38) then
                heading = heading + rotSpeed
                if heading >= 360 then heading = heading - 360 end
            end
            
            if IsControlJustPressed(0, 241) then
                heading = heading + (rotSpeed * 2)
                if heading >= 360 then heading = heading - 360 end
                Notify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            if IsControlJustPressed(0, 242) then
                heading = heading - (rotSpeed * 2)
                if heading < 0 then heading = heading + 360 end
                Notify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            
            if IsControlJustPressed(0, 47) then
                local success, groundZ = GetGroundZFor_3dCoord(finalX, finalY, finalZ + 5.0, false)
                if success then
                    offset.z = (groundZ - baseCoords.z)
                    Notify('Ped snapped to ground!', 'success', 2000)
                end
            end
            
            if IsControlPressed(0, 21) then
                moveSpeed = 0.01
                rotSpeed = 1.0
            else
                moveSpeed = 0.05
                rotSpeed = 5.0
            end
            
            if IsControlJustPressed(0, 191) then
                adjusting = false
                DeleteEntity(previewPed)
                SetModelAsNoLongerNeeded(pedModel)
                
                offset.x = math.floor(offset.x * 100 + 0.5) / 100
                offset.y = math.floor(offset.y * 100 + 0.5) / 100
                offset.z = math.floor(offset.z * 100 + 0.5) / 100
                heading = math.floor(heading * 10 + 0.5) / 10
                
                print('^2[StashManager]^7 Ped offset saved: X=' .. offset.x .. ' Y=' .. offset.y .. ' Z=' .. offset.z .. ' H=' .. heading)
                Notify('Ped position saved!', 'success')
                
                stashData.ped_offset = offset
                stashData.ped_heading = heading
                
                if stashData[6] and stashData[6] ~= '' then
                    OpenObjectPositioningMenu(stashData, stashType)
                else
                    ProceedWithStashCreation(stashData, stashType, nil, nil)
                end
            end
            
            if IsControlJustPressed(0, 194) then
                adjusting = false
                DeleteEntity(previewPed)
                SetModelAsNoLongerNeeded(pedModel)
                Notify('Cancelled', 'error')
            end
        end
    end)
end

function OpenObjectPositioningMenu(stashData, stashType)
    print('^2[StashManager Debug]^7 Object positioning menu opened')
    lib.registerContext({
        id = 'stash_object_positioning',
        title = 'Position Object',
        menu = 'stash_create_type',
        options = {
            {
                title = '🎮 Live Preview Mode',
                description = 'Place object interactively (Press G to snap to ground)',
                icon = 'gamepad',
                onSelect = function()
                    print('^2[StashManager Debug]^7 Live preview selected')
                    OpenLiveObjectPositioning(stashData, stashType)
                end
            },
            {
                title = 'No Offset (Center)',
                description = 'Place at stash center',
                icon = 'crosshairs',
                onSelect = function()
                    ProceedWithStashCreation(stashData, stashType, {x = 0.0, y = 0.0, z = 0.0}, 0.0)
                end
            }
        }
    })
    lib.showContext('stash_object_positioning')
end

function OpenLiveObjectPositioning(stashData, stashType)
    print('^2[StashManager Debug]^7 Starting live positioning')
    print('^2[StashManager Debug]^7 Object model: ' .. stashData[6])
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local objectModel = GetHashKey(stashData[6])
    
    RequestModel(objectModel)
    
    local loadAttempts = 0
    while not HasModelLoaded(objectModel) and loadAttempts < 200 do
        Wait(100)
        loadAttempts = loadAttempts + 1
    end
    
    if not HasModelLoaded(objectModel) then
        Notify('Failed to load object model!', 'error')
        SetModelAsNoLongerNeeded(objectModel)
        return
    end
    
    local previewObject = CreateObject(objectModel, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
    SetEntityAlpha(previewObject, 200, false)
    SetEntityCollision(previewObject, false, false)
    
    local offset = {x = 0.0, y = 1.0, z = 0.0}
    local heading = 0.0
    local baseCoords = playerCoords
    
    Notify('Arrows=Move | Q/E/Scroll=Rotate | PgUp/Dn=Height | G=Snap | Enter=Save | Backspace=Cancel', 'primary', 10000)
    
    CreateThread(function()
        local adjusting = true
        local moveSpeed = 0.05
        local rotSpeed = 5.0
        
        while adjusting do
            Wait(0)
            
            local finalX = baseCoords.x + offset.x
            local finalY = baseCoords.y + offset.y
            local finalZ = baseCoords.z + offset.z
            
            SetEntityCoords(previewObject, finalX, finalY, finalZ, false, false, false, false)
            SetEntityHeading(previewObject, heading)
            
            DrawText3DAtCoords(finalX, finalY, finalZ + 1.0, 
                string.format('~b~OBJ~w~ X:~g~%.2f~w~ Y:~g~%.2f~w~ Z:~g~%.2f~w~ H:~g~%.1f°', 
                offset.x, offset.y, offset.z, heading))
            
            if IsControlPressed(0, 172) then offset.y = offset.y + moveSpeed end
            if IsControlPressed(0, 173) then offset.y = offset.y - moveSpeed end
            if IsControlPressed(0, 174) then offset.x = offset.x - moveSpeed end
            if IsControlPressed(0, 175) then offset.x = offset.x + moveSpeed end
            if IsControlPressed(0, 10) then offset.z = offset.z + moveSpeed end
            if IsControlPressed(0, 11) then offset.z = offset.z - moveSpeed end
            
            if IsControlPressed(0, 44) then
                heading = heading - rotSpeed
                if heading < 0 then heading = heading + 360 end
            end
            if IsControlPressed(0, 38) then
                heading = heading + rotSpeed
                if heading >= 360 then heading = heading - 360 end
            end
            
            if IsControlJustPressed(0, 241) then
                heading = heading + (rotSpeed * 2)
                if heading >= 360 then heading = heading - 360 end
                Notify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            if IsControlJustPressed(0, 242) then
                heading = heading - (rotSpeed * 2)
                if heading < 0 then heading = heading + 360 end
                Notify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            
            if IsControlJustPressed(0, 47) then
                local success, groundZ = GetGroundZFor_3dCoord(finalX, finalY, finalZ + 5.0, false)
                if success then
                    offset.z = (groundZ - baseCoords.z) + 0.5
                    Notify('Snapped to ground! Z: ' .. string.format('%.2f', offset.z), 'success', 2000)
                end
            end
            
            if IsControlPressed(0, 21) then
                moveSpeed = 0.01
                rotSpeed = 1.0
            else
                moveSpeed = 0.05
                rotSpeed = 5.0
            end
            
            if IsControlJustPressed(0, 191) then
                adjusting = false
                DeleteEntity(previewObject)
                SetModelAsNoLongerNeeded(objectModel)
                
                offset.x = math.floor(offset.x * 100 + 0.5) / 100
                offset.y = math.floor(offset.y * 100 + 0.5) / 100
                offset.z = math.floor(offset.z * 100 + 0.5) / 100
                heading = math.floor(heading * 10 + 0.5) / 10
                
                print('^2[StashManager]^7 Object offset saved: X=' .. offset.x .. ' Y=' .. offset.y .. ' Z=' .. offset.z .. ' H=' .. heading)
                Notify('Position saved!', 'success')
                
                ProceedWithStashCreation(stashData, stashType, offset, heading)
            end
            
            if IsControlJustPressed(0, 194) then
                adjusting = false
                DeleteEntity(previewObject)
                SetModelAsNoLongerNeeded(objectModel)
                Notify('Cancelled', 'error')
            end
        end
    end)
end

function DrawText3DAtCoords(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, true)
    
    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    
    SetTextScale(0.0 * scale, 0.35 * scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end

function ProceedWithStashCreation(stashData, stashType, objectOffset, objectHeading)
    print('^2[StashManager Debug]^7 Proceeding with creation. Type: ' .. stashType)
    if stashType == 'job' then
        OpenJobSelectionMenu(stashData, objectOffset, objectHeading)
    elseif stashType == 'private' then
        OpenPrivateStashOptionsMenu(stashData, objectOffset, objectHeading)
    elseif stashType == 'shared' then
        OpenSharedStashOptionsMenu(stashData, objectOffset, objectHeading)
    elseif stashType == 'public' then
        CreateStashAtLocation(stashData, 'public', nil, nil, objectOffset, objectHeading)
    end
end

function OpenPrivateStashOptionsMenu(stashData, objectOffset, objectHeading)
    lib.registerContext({
        id = 'stash_private_options',
        title = 'Select Owner Method',
        menu = 'stash_create_type',
        options = {
            {title = 'Online Player (Server ID)', description = 'Select online player', icon = 'user-check', onSelect = function() OpenOnlinePlayerSelection(stashData, objectOffset, objectHeading) end},
            {title = 'By Citizen ID', description = 'Enter citizen ID', icon = 'id-card', onSelect = function() OpenCitizenIdInput(stashData, objectOffset, objectHeading) end}
        }
    })
    lib.showContext('stash_private_options')
end

function OpenOnlinePlayerSelection(stashData, objectOffset, objectHeading)
    local input = lib.inputDialog('Select Online Player', {
        {type = 'number', label = 'Player Server ID', required = true, min = 1}
    })
    
    if not input then return end
    
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetCitizenId', function(citizenid)
        if citizenid then
            CreatePrivateStashWithCitizenId(stashData, citizenid, objectOffset, objectHeading)
        else
            Notify('Player not found', 'error')
        end
    end, tonumber(input[1]))
end

function OpenCitizenIdInput(stashData, objectOffset, objectHeading)
    local input = lib.inputDialog('Enter Citizen ID', {
        {type = 'input', label = 'Citizen ID', required = true, min = 8, max = 12}
    })
    
    if not input then return end
    
    local citizenid = input[1]:upper()
    
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetPlayerName', function(playerName)
        if playerName then
            local confirm = lib.alertDialog({
                header = 'Confirm Owner',
                content = 'Create for: **' .. playerName .. '**\nID: ' .. citizenid,
                centered = true,
                cancel = true
            })
            
            if confirm == 'confirm' then
                CreatePrivateStashWithCitizenId(stashData, citizenid, objectOffset, objectHeading)
            end
        else
            Notify('Citizen ID not found', 'error')
        end
    end, citizenid)
end

function CreatePrivateStashWithCitizenId(data, citizenid, objectOffset, objectHeading)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    local stashData = {
        name = data[1],
        type = 'private',
        coords = {x = coords.x, y = coords.y, z = coords.z},
        slots = data[2],
        weight = data[3],
        show_blip = data.show_blip ~= nil and data.show_blip or Config.ShowBlips,
        blip_sprite = data.blip_sprite,
        blip_color = data.blip_color,
        blip_label = data.blip_label,
        ped_model = data[5] ~= '' and data[5] or nil,
        ped_offset = data.ped_offset,
        ped_heading = data.ped_heading or 0.0,
        object_model = data[6] ~= '' and data[6] or nil,
        object_offset = objectOffset,
        object_heading = objectHeading or 0.0
    }
    
    print('^2[StashManager Debug]^7 Creating private stash with ped/object data')
    TriggerServerEvent('qb-stashmanager:server:CreatePrivateStash', stashData, citizenid)
end

function OpenSharedStashOptionsMenu(stashData, objectOffset, objectHeading)
    lib.registerContext({
        id = 'stash_shared_options',
        title = 'Assign First Manager',
        menu = 'stash_create_type',
        options = {
            {title = 'Online Player (Server ID)', description = 'Select online player', icon = 'user-friends', onSelect = function() OpenSharedOnlineSelection(stashData, objectOffset, objectHeading) end},
            {title = 'By Citizen ID', description = 'Enter citizen ID', icon = 'id-card', onSelect = function() OpenSharedCitizenIdInput(stashData, objectOffset, objectHeading) end}
        }
    })
    lib.showContext('stash_shared_options')
end

function OpenSharedOnlineSelection(stashData, objectOffset, objectHeading)
    local input = lib.inputDialog('Select Online Player', {
        {type = 'number', label = 'Player Server ID', required = true, min = 1}
    })

    if not input then return end

    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetCitizenId', function(citizenid)
        if citizenid then
            CreateSharedStashWithCitizenId(stashData, citizenid, objectOffset, objectHeading)
        else
            Notify('Player not found', 'error')
        end
    end, tonumber(input[1]))
end

function OpenSharedCitizenIdInput(stashData, objectOffset, objectHeading)
    local input = lib.inputDialog('Enter Citizen ID', {
        {type = 'input', label = 'Citizen ID', required = true, min = 8, max = 12}
    })

    if not input then return end

    local citizenid = input[1]:upper()

    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetPlayerName', function(playerName)
        if playerName then
            local confirm = lib.alertDialog({
                header = 'Assign Manager',
                content = 'Assign to: **' .. playerName .. '**\nID: ' .. citizenid,
                centered = true,
                cancel = true
            })

            if confirm == 'confirm' then
                CreateSharedStashWithCitizenId(stashData, citizenid, objectOffset, objectHeading)
            end
        else
            Notify('Citizen ID not found', 'error')
        end
    end, citizenid)
end

function CreateSharedStashWithCitizenId(data, citizenid, objectOffset, objectHeading)
    local accessList = {
        {citizenid = citizenid, is_manager = true}
    }

    CreateStashAtLocation(data, 'shared', nil, nil, objectOffset, objectHeading, accessList)
end

function OpenJobSelectionMenu(stashData, objectOffset, objectHeading)
    local options = {}
    
    for _, job in pairs(Config.Jobs) do
        table.insert(options, {
            title = job:gsub("^%l", string.upper),
            description = 'Create for ' .. job,
            icon = 'briefcase',
            onSelect = function()
                CreateStashAtLocation(stashData, 'job', job, nil, objectOffset, objectHeading)
            end
        })
    end
    
    lib.registerContext({
        id = 'stash_job_select',
        title = 'Select Job',
        menu = 'stash_create_type',
        options = options
    })
    
    lib.showContext('stash_job_select')
end

function CreateStashAtLocation(data, stashType, job, owner, objectOffset, objectHeading, accessList)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    local stashData = {
        name = data[1],
        type = stashType,
        owner = owner,
        job = job,
        coords = {x = coords.x, y = coords.y, z = coords.z},
        slots = data[2],
        weight = data[3],
        show_blip = data.show_blip ~= nil and data.show_blip or Config.ShowBlips,
        blip_sprite = data.blip_sprite,
        blip_color = data.blip_color,
        blip_label = data.blip_label,
        ped_model = data[5] ~= '' and data[5] or nil,
        ped_offset = data.ped_offset,
        ped_heading = data.ped_heading or 0.0,
        object_model = data[6] ~= '' and data[6] or nil,
        object_offset = objectOffset,
        object_heading = objectHeading or 0.0
    }
    
    print('^2[StashManager Debug]^7 Creating stash with all data')
    TriggerServerEvent('qb-stashmanager:server:CreateStash', stashData, accessList)
end

-- Store filter state
local StashFilterState = {
    searchQuery = '',
    filterType = nil, -- nil = all types
    sortBy = 'name', -- 'name', 'type', 'date'
    sortOrder = 'asc' -- 'asc', 'desc'
}

function OpenManageStashesMenu()
    lib.registerContext({
        id = 'stash_manage_options',
        title = 'Manage Stashes',
        menu = 'stash_manager_main',
        options = {
            {
                title = 'View All Stashes',
                description = 'View all stashes',
                icon = 'list',
                onSelect = function()
                    OpenStashListMenu(nil, nil, nil)
                end
            },
            {
                title = 'Search & Filter',
                description = 'Search, filter, and sort stashes',
                icon = 'filter',
                arrow = true,
                onSelect = function()
                    OpenStashFilterMenu()
                end
            }
        }
    })
    lib.showContext('stash_manage_options')
end

function OpenStashFilterMenu()
    local currentFilterText = StashFilterState.filterType and StashFilterState.filterType:upper() or 'All Types'
    local currentSortText = StashFilterState.sortBy:upper() .. ' (' .. StashFilterState.sortOrder:upper() .. ')'
    
    lib.registerContext({
        id = 'stash_filter_menu',
        title = 'Search & Filter',
        menu = 'stash_manage_options',
        options = {
            {
                title = 'Search',
                description = StashFilterState.searchQuery ~= '' and ('Current: "' .. StashFilterState.searchQuery .. '"') or 'Search by stash name',
                icon = 'search',
                onSelect = function()
                    local input = lib.inputDialog('Search Stashes', {
                        {type = 'input', label = 'Search Query', description = 'Enter stash name to search', default = StashFilterState.searchQuery, required = false}
                    })
                    
                    if input then
                        StashFilterState.searchQuery = input[1] or ''
                        OpenStashListMenu(StashFilterState.searchQuery, StashFilterState.filterType, StashFilterState.sortBy, StashFilterState.sortOrder)
                    end
                end
            },
            {
                title = 'Filter by Type',
                description = 'Current: ' .. currentFilterText,
                icon = 'filter',
                onSelect = function()
                    lib.registerContext({
                        id = 'stash_type_filter',
                        title = 'Filter by Type',
                        menu = 'stash_filter_menu',
                        options = {
                            {
                                title = 'All Types',
                                description = 'Show all stash types',
                                icon = 'list',
                                onSelect = function()
                                    StashFilterState.filterType = nil
                                    OpenStashListMenu(StashFilterState.searchQuery, nil, StashFilterState.sortBy, StashFilterState.sortOrder)
                                end
                            },
                            {
                                title = 'Private',
                                description = 'Show only private stashes',
                                icon = 'user',
                                onSelect = function()
                                    StashFilterState.filterType = 'private'
                                    OpenStashListMenu(StashFilterState.searchQuery, 'private', StashFilterState.sortBy, StashFilterState.sortOrder)
                                end
                            },
                            {
                                title = 'Public',
                                description = 'Show only public stashes',
                                icon = 'users',
                                onSelect = function()
                                    StashFilterState.filterType = 'public'
                                    OpenStashListMenu(StashFilterState.searchQuery, 'public', StashFilterState.sortBy, StashFilterState.sortOrder)
                                end
                            },
                            {
                                title = 'Job',
                                description = 'Show only job stashes',
                                icon = 'briefcase',
                                onSelect = function()
                                    StashFilterState.filterType = 'job'
                                    OpenStashListMenu(StashFilterState.searchQuery, 'job', StashFilterState.sortBy, StashFilterState.sortOrder)
                                end
                            },
                            {
                                title = 'Shared',
                                description = 'Show only shared stashes',
                                icon = 'share-nodes',
                                onSelect = function()
                                    StashFilterState.filterType = 'shared'
                                    OpenStashListMenu(StashFilterState.searchQuery, 'shared', StashFilterState.sortBy, StashFilterState.sortOrder)
                                end
                            }
                        }
                    })
                    lib.showContext('stash_type_filter')
                end
            },
            {
                title = 'Sort By',
                description = 'Current: ' .. currentSortText,
                icon = 'sort',
                onSelect = function()
                    lib.registerContext({
                        id = 'stash_sort_menu',
                        title = 'Sort By',
                        menu = 'stash_filter_menu',
                        options = {
                            {
                                title = 'Name (A-Z)',
                                description = 'Sort alphabetically by name',
                                icon = 'sort-alpha-down',
                                onSelect = function()
                                    StashFilterState.sortBy = 'name'
                                    StashFilterState.sortOrder = 'asc'
                                    OpenStashListMenu(StashFilterState.searchQuery, StashFilterState.filterType, 'name', 'asc')
                                end
                            },
                            {
                                title = 'Name (Z-A)',
                                description = 'Sort reverse alphabetically',
                                icon = 'sort-alpha-up',
                                onSelect = function()
                                    StashFilterState.sortBy = 'name'
                                    StashFilterState.sortOrder = 'desc'
                                    OpenStashListMenu(StashFilterState.searchQuery, StashFilterState.filterType, 'name', 'desc')
                                end
                            },
                            {
                                title = 'Type (A-Z)',
                                description = 'Sort by stash type',
                                icon = 'layer-group',
                                onSelect = function()
                                    StashFilterState.sortBy = 'type'
                                    StashFilterState.sortOrder = 'asc'
                                    OpenStashListMenu(StashFilterState.searchQuery, StashFilterState.filterType, 'type', 'asc')
                                end
                            },
                            {
                                title = 'Type (Z-A)',
                                description = 'Sort by stash type (reverse)',
                                icon = 'layer-group',
                                onSelect = function()
                                    StashFilterState.sortBy = 'type'
                                    StashFilterState.sortOrder = 'desc'
                                    OpenStashListMenu(StashFilterState.searchQuery, StashFilterState.filterType, 'type', 'desc')
                                end
                            },
                            {
                                title = 'Date (Newest First)',
                                description = 'Sort by creation date (newest)',
                                icon = 'calendar-alt',
                                onSelect = function()
                                    StashFilterState.sortBy = 'date'
                                    StashFilterState.sortOrder = 'desc'
                                    OpenStashListMenu(StashFilterState.searchQuery, StashFilterState.filterType, 'date', 'desc')
                                end
                            },
                            {
                                title = 'Date (Oldest First)',
                                description = 'Sort by creation date (oldest)',
                                icon = 'calendar',
                                onSelect = function()
                                    StashFilterState.sortBy = 'date'
                                    StashFilterState.sortOrder = 'asc'
                                    OpenStashListMenu(StashFilterState.searchQuery, StashFilterState.filterType, 'date', 'asc')
                                end
                            }
                        }
                    })
                    lib.showContext('stash_sort_menu')
                end
            },
            {
                title = 'Clear Filters',
                description = 'Reset all filters and sorting',
                icon = 'times-circle',
                onSelect = function()
                    StashFilterState.searchQuery = ''
                    StashFilterState.filterType = nil
                    StashFilterState.sortBy = 'name'
                    StashFilterState.sortOrder = 'asc'
                    Notify('Filters cleared', 'success')
                    OpenStashListMenu(nil, nil, 'name', 'asc')
                end
            }
        }
    })
    lib.showContext('stash_filter_menu')
end

function OpenStashListMenu(searchQuery, filterType, sortBy, sortOrder)
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetAllStashes', function(stashes)
        if #stashes == 0 then
            Notify('No stashes found', 'error')
            return
        end
        
        -- Apply filters
        local filteredStashes = {}
        
        for _, stash in pairs(stashes) do
            local matches = true
            
            -- Search filter
            if searchQuery and searchQuery ~= '' then
                local stashName = stash.name:lower()
                local query = searchQuery:lower()
                if not stashName:find(query, 1, true) then
                    matches = false
                end
            end
            
            -- Type filter
            if filterType and stash.type ~= filterType then
                matches = false
            end
            
            if matches then
                table.insert(filteredStashes, stash)
            end
        end
        
        if #filteredStashes == 0 then
            Notify('No stashes match your filters', 'error')
            return
        end
        
        -- Apply sorting
        sortBy = sortBy or 'name'
        sortOrder = sortOrder or 'asc'
        
        table.sort(filteredStashes, function(a, b)
            local aValue, bValue
            
            if sortBy == 'name' then
                aValue = a.name:lower()
                bValue = b.name:lower()
            elseif sortBy == 'type' then
                aValue = a.type:lower()
                bValue = b.type:lower()
            elseif sortBy == 'date' then
                -- Parse created_at timestamp
                aValue = ParseTimestamp(a.created_at)
                bValue = ParseTimestamp(b.created_at)
            else
                aValue = a.name:lower()
                bValue = b.name:lower()
            end
            
            if sortOrder == 'asc' then
                return aValue < bValue
            else
                return aValue > bValue
            end
        end)
        
        -- Build options list
        local options = {}
        
        -- Show filter info
        local filterInfo = {}
        if searchQuery and searchQuery ~= '' then
            table.insert(filterInfo, 'Search: "' .. searchQuery .. '"')
        end
        if filterType then
            table.insert(filterInfo, 'Type: ' .. filterType:upper())
        end
        if #filterInfo > 0 then
            table.insert(options, {
                title = 'Filters Active',
                description = table.concat(filterInfo, ' | '),
                icon = 'info',
                disabled = true
            })
        end
        
        -- Add stashes
        for _, stash in ipairs(filteredStashes) do
            local description = 'Type: ' .. stash.type:upper()
            if stash.type == 'private' and stash.owner then
                description = description .. '\nOwner: ' .. stash.owner
            elseif stash.type == 'job' and stash.job then
                description = description .. '\nJob: ' .. stash.job:upper()
            end
            
            -- Add creation date if available
            if stash.created_at then
                local dateStr = FormatTimestamp(stash.created_at)
                description = description .. '\nCreated: ' .. dateStr
            end
            
            table.insert(options, {
                title = stash.name,
                description = description,
                icon = stash.type == 'private' and 'user' or (stash.type == 'job' and 'briefcase' or (stash.type == 'shared' and 'share-nodes' or 'users')),
                onSelect = function()
                    OpenStashEditMenu(stash)
                end
            })
        end
        
        local menuTitle = 'Stashes (' .. #filteredStashes .. '/' .. #stashes .. ')'
        if searchQuery and searchQuery ~= '' then
            menuTitle = menuTitle .. ' - "' .. searchQuery .. '"'
        end
        
        lib.registerContext({
            id = 'stash_manage_list',
            title = menuTitle,
            menu = 'stash_manage_options',
            options = options
        })
        
        lib.showContext('stash_manage_list')
    end)
end

function ParseTimestamp(timestamp)
    if not timestamp then return 0 end
    
    if type(timestamp) == 'string' then
        -- Parse MySQL timestamp format (YYYY-MM-DD HH:MM:SS)
        local year, month, day, hour, minute, second = timestamp:match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
        if year then
            -- Create a sortable number (YYYYMMDDHHMMSS)
            return tonumber(year .. month .. day .. hour .. minute .. second) or 0
        end
    end
    
    return 0
end

function OpenStashEditMenu(stash)
    local options = {
        {
            title = '📦 Open Stash',
            description = 'Open stash inventory',
            icon = 'box-open',
            onSelect = function()
                TriggerServerEvent('qb-stashmanager:server:OpenStash', stash.id)
            end
        },
        {
            title = 'Edit Basic Details', 
            description = 'Name, slots, weight', 
            icon = 'edit', 
            onSelect = function() OpenStashEditForm(stash) end
        },
        {
            title = 'Teleport to Stash', 
            description = 'Go to stash location', 
            icon = 'map-marker', 
            onSelect = function()
                local success, coords = pcall(function() return json.decode(stash.coords) end)
                if success and coords then
                    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
                    Notify('Teleported', 'success')
                end
            end
        }
    }
    
    table.insert(options, {
        title = '👤 Ped Settings',
        description = 'Manage ped model and position',
        icon = 'user-cog',
        arrow = true,
        onSelect = function()
            OpenPedSettingsMenu(stash)
        end
    })
    
    table.insert(options, {
        title = '📦 Object Settings',
        description = 'Manage object model and position',
        icon = 'box',
        arrow = true,
        onSelect = function()
            OpenObjectSettingsMenu(stash)
        end
    })
    
    table.insert(options, {
        title = '📍 Blip Settings',
        description = 'Toggle map blip visibility',
        icon = 'map-marked-alt',
        arrow = true,
        onSelect = function()
            OpenBlipSettingsMenu(stash)
        end
    })
    
    table.insert(options, {
        title = 'Delete Stash',
        description = 'Permanently delete',
        icon = 'trash',
        onSelect = function()
            local confirm = lib.alertDialog({
                header = 'Delete Stash',
                content = 'Delete "' .. stash.name .. '"?',
                centered = true,
                cancel = true
            })
            
            if confirm == 'confirm' then
                TriggerServerEvent('qb-stashmanager:server:DeleteStash', stash.id)
            end
        end
    })
    
    lib.registerContext({
        id = 'stash_edit_' .. stash.id,
        title = 'Edit: ' .. stash.name,
        menu = 'stash_manage_list',
        options = options
    })
    
    lib.showContext('stash_edit_' .. stash.id)
end

function OpenPedSettingsMenu(stash)
    local options = {}
    
    if stash.ped_model then
        table.insert(options, {
            title = 'Current: ' .. stash.ped_model,
            description = 'Current ped model',
            icon = 'info',
            disabled = true
        })
        table.insert(options, {
            title = '🔄 Change Ped Model',
            description = 'Replace with different ped',
            icon = 'exchange-alt',
            onSelect = function()
                local input = lib.inputDialog('Change Ped Model', {
                    {type = 'input', label = 'New Ped Model', description = 'e.g., s_m_m_ups_01', default = stash.ped_model, required = true}
                })
                
                if input and input[1] then
                    local success, coords = pcall(function() return json.decode(stash.coords) end)
                    if not success then return end
                    
                    local updatedData = {
                        name = stash.name,
                        type = stash.type,
                        owner = stash.owner,
                        job = stash.job,
                        coords = coords,
                        slots = stash.slots,
                        weight = stash.weight,
                        ped_model = input[1],
                        ped_offset = stash.ped_offset,
                        ped_heading = stash.ped_heading,
                        object_model = stash.object_model,
                        object_offset = stash.object_offset,
                        object_heading = stash.object_heading
                    }
                    
                    TriggerServerEvent('qb-stashmanager:server:UpdateStash', stash.id, updatedData)
                    Notify('Ped model updated!', 'success')
                end
            end
        })
        table.insert(options, {
            title = '📍 Reposition Ped',
            description = 'Adjust position and rotation',
            icon = 'arrows-alt',
            onSelect = function()
                OpenRepositionPed(stash)
            end
        })
        table.insert(options, {
            title = '🗑️ Remove Ped',
            description = 'Delete ped from stash',
            icon = 'user-times',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Remove Ped',
                    content = 'Remove ped from this stash?',
                    centered = true,
                    cancel = true
                })
                
                if confirm == 'confirm' then
                    local success, coords = pcall(function() return json.decode(stash.coords) end)
                    if not success then return end
                    
                    local updatedData = {
                        name = stash.name,
                        type = stash.type,
                        owner = stash.owner,
                        job = stash.job,
                        coords = coords,
                        slots = stash.slots,
                        weight = stash.weight,
                        ped_model = nil,
                        ped_offset = nil,
                        ped_heading = nil,
                        object_model = stash.object_model,
                        object_offset = stash.object_offset,
                        object_heading = stash.object_heading
                    }
                    
                    TriggerServerEvent('qb-stashmanager:server:UpdateStash', stash.id, updatedData)
                    Notify('Ped removed!', 'success')
                end
            end
        })
    else
        table.insert(options, {
            title = 'No Ped Set',
            description = 'Add a ped to this stash',
            icon = 'info',
            disabled = true
        })
    end
    
    lib.registerContext({
        id = 'ped_settings_' .. stash.id,
        title = '👤 Ped Settings',
        menu = 'stash_edit_' .. stash.id,
        options = options
    })
    
    lib.showContext('ped_settings_' .. stash.id)
end

function OpenBlipSettingsMenu(stash)
    local showBlip = stash.show_blip
    if showBlip == nil then
        showBlip = Config.ShowBlips
    else
        showBlip = showBlip == 1 or showBlip == true
    end
    
    local blipSettings = Config.BlipSettings[stash.type] or {sprite = 478, color = 3, label = 'Stash'}
    local statusText = showBlip and 'Visible' or 'Hidden'
    local typeInfo = 'Type: ' .. stash.type:upper() .. ' | Color: ' .. blipSettings.color .. ' | Sprite: ' .. blipSettings.sprite
    
    lib.registerContext({
        id = 'blip_settings_' .. stash.id,
        title = '📍 Blip Settings',
        menu = 'stash_edit_' .. stash.id,
        options = {
            {
                title = 'Status: ' .. statusText,
                description = typeInfo,
                icon = showBlip and 'eye' or 'eye-slash',
                disabled = true
            },
            {
                title = showBlip and 'Hide Blip' or 'Show Blip',
                description = showBlip and 'Hide this stash on the map' or 'Show this stash on the map',
                icon = showBlip and 'eye-slash' or 'eye',
                onSelect = function()
                    local success, coords = pcall(function() return json.decode(stash.coords) end)
                    if not success then return end
                    
                    local newBlipState = not showBlip
                    
                    local updatedData = {
                        name = stash.name,
                        type = stash.type,
                        owner = stash.owner,
                        job = stash.job,
                        coords = coords,
                        slots = stash.slots,
                        weight = stash.weight,
                        ped_model = stash.ped_model,
                        ped_offset = stash.ped_offset,
                        ped_heading = stash.ped_heading,
                        object_model = stash.object_model,
                        object_offset = stash.object_offset,
                        object_heading = stash.object_heading,
                        show_blip = newBlipState
                    }
                    
                    TriggerServerEvent('qb-stashmanager:server:UpdateStash', stash.id, updatedData)
                    Notify(newBlipState and 'Blip enabled!' or 'Blip disabled!', 'success')
                end
            },
            {
                title = 'Blip Info',
                description = 'Type: ' .. stash.type:upper() .. '\nColor: ' .. blipSettings.color .. '\nSprite: ' .. blipSettings.sprite,
                icon = 'info',
                disabled = true
            }
        }
    })
    
    lib.showContext('blip_settings_' .. stash.id)
end

function OpenObjectSettingsMenu(stash)
    local options = {}
    
    if stash.object_model then
        table.insert(options, {
            title = 'Current: ' .. stash.object_model,
            description = 'Current object model',
            icon = 'info',
            disabled = true
        })
        table.insert(options, {
            title = '🔄 Change Object Model',
            description = 'Replace with different object',
            icon = 'exchange-alt',
            onSelect = function()
                local input = lib.inputDialog('Change Object Model', {
                    {type = 'input', label = 'New Object Model', description = 'e.g., prop_box_wood05a', default = stash.object_model, required = true}
                })
                
                if input and input[1] then
                    local success, coords = pcall(function() return json.decode(stash.coords) end)
                    if not success then return end
                    
                    local updatedData = {
                        name = stash.name,
                        type = stash.type,
                        owner = stash.owner,
                        job = stash.job,
                        coords = coords,
                        slots = stash.slots,
                        weight = stash.weight,
                        ped_model = stash.ped_model,
                        ped_offset = stash.ped_offset,
                        ped_heading = stash.ped_heading,
                        object_model = input[1],
                        object_offset = stash.object_offset,
                        object_heading = stash.object_heading
                    }
                    
                    TriggerServerEvent('qb-stashmanager:server:UpdateStash', stash.id, updatedData)
                    Notify('Object model updated!', 'success')
                end
            end
        })
        table.insert(options, {
            title = '📍 Reposition Object',
            description = 'Adjust position and rotation',
            icon = 'arrows-alt',
            onSelect = function()
                OpenRepositionObject(stash)
            end
        })
        table.insert(options, {
            title = '🗑️ Remove Object',
            description = 'Delete object from stash',
            icon = 'times',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Remove Object',
                    content = 'Remove object from this stash?',
                    centered = true,
                    cancel = true
                })
                
                if confirm == 'confirm' then
                    local success, coords = pcall(function() return json.decode(stash.coords) end)
                    if not success then return end
                    
                    local updatedData = {
                        name = stash.name,
                        type = stash.type,
                        owner = stash.owner,
                        job = stash.job,
                        coords = coords,
                        slots = stash.slots,
                        weight = stash.weight,
                        ped_model = stash.ped_model,
                        ped_offset = stash.ped_offset,
                        ped_heading = stash.ped_heading,
                        object_model = nil,
                        object_offset = nil,
                        object_heading = nil
                    }
                    
                    TriggerServerEvent('qb-stashmanager:server:UpdateStash', stash.id, updatedData)
                    Notify('Object removed!', 'success')
                end
            end
        })
    else
        table.insert(options, {
            title = 'No Object Set',
            description = 'Add an object to this stash',
            icon = 'info',
            disabled = true
        })
    end
    
    lib.registerContext({
        id = 'object_settings_' .. stash.id,
        title = '📦 Object Settings',
        menu = 'stash_edit_' .. stash.id,
        options = options
    })
    
    lib.showContext('object_settings_' .. stash.id)
end

function OpenRepositionPed(stash)
    local success, coords = pcall(function() return json.decode(stash.coords) end)
    if not success or not coords then
        Notify('Failed to load stash coordinates', 'error')
        return
    end
    
    local stashCoords = vector3(coords.x, coords.y, coords.z)
    local pedModel = GetHashKey(stash.ped_model)
    
    RequestModel(pedModel)
    local loadAttempts = 0
    while not HasModelLoaded(pedModel) and loadAttempts < 200 do
        Wait(100)
        loadAttempts = loadAttempts + 1
    end
    
    if not HasModelLoaded(pedModel) then
        Notify('Failed to load ped model!', 'error')
        return
    end
    
    local currentOffset = {x = 0.0, y = 0.0, z = 0.0}
    if stash.ped_offset then
        if type(stash.ped_offset) == 'table' then
            currentOffset = stash.ped_offset
        elseif type(stash.ped_offset) == 'string' then
            local offsetSuccess, result = pcall(function() return json.decode(stash.ped_offset) end)
            if offsetSuccess and result then
                currentOffset = result
            end
        end
    end
    
    local previewPed = CreatePed(4, pedModel, stashCoords.x, stashCoords.y, stashCoords.z, 0.0, false, true)
    SetEntityAlpha(previewPed, 200, false)
    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    
    local offset = {x = currentOffset.x, y = currentOffset.y, z = currentOffset.z}
    local heading = stash.ped_heading or 0.0
    local baseCoords = stashCoords
    
    Notify('Arrows=Move | Q/E/Scroll=Rotate | G=Snap | Enter=Save | Backspace=Cancel', 'primary', 10000)
    
    CreateThread(function()
        local adjusting = true
        local moveSpeed = 0.05
        local rotSpeed = 5.0
        
        while adjusting do
            Wait(0)
            
            local finalX = baseCoords.x + offset.x
            local finalY = baseCoords.y + offset.y
            local finalZ = baseCoords.z + offset.z
            
            SetEntityCoords(previewPed, finalX, finalY, finalZ, false, false, false, false)
            SetEntityHeading(previewPed, heading)
            
            DrawText3DAtCoords(finalX, finalY, finalZ + 2.0, 
                string.format('~y~PED~w~ X:~g~%.2f~w~ Y:~g~%.2f~w~ Z:~g~%.2f~w~ H:~g~%.1f°', 
                offset.x, offset.y, offset.z, heading))
            
            if IsControlPressed(0, 172) then offset.y = offset.y + moveSpeed end
            if IsControlPressed(0, 173) then offset.y = offset.y - moveSpeed end
            if IsControlPressed(0, 174) then offset.x = offset.x - moveSpeed end
            if IsControlPressed(0, 175) then offset.x = offset.x + moveSpeed end
            if IsControlPressed(0, 10) then offset.z = offset.z + moveSpeed end
            if IsControlPressed(0, 11) then offset.z = offset.z - moveSpeed end
            
            if IsControlPressed(0, 44) then
                heading = heading - rotSpeed
                if heading < 0 then heading = heading + 360 end
            end
            if IsControlPressed(0, 38) then
                heading = heading + rotSpeed
                if heading >= 360 then heading = heading - 360 end
            end
            
            if IsControlJustPressed(0, 241) then
                heading = heading + (rotSpeed * 2)
                if heading >= 360 then heading = heading - 360 end
                Notify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            if IsControlJustPressed(0, 242) then
                heading = heading - (rotSpeed * 2)
                if heading < 0 then heading = heading + 360 end
                Notify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            
            if IsControlJustPressed(0, 47) then
                local success, groundZ = GetGroundZFor_3dCoord(finalX, finalY, finalZ + 5.0, false)
                if success then
                    offset.z = (groundZ - baseCoords.z)
                    Notify('Ped snapped to ground!', 'success', 2000)
                end
            end
            
            if IsControlPressed(0, 21) then
                moveSpeed = 0.01
                rotSpeed = 1.0
            else
                moveSpeed = 0.05
                rotSpeed = 5.0
            end
            
            if IsControlJustPressed(0, 191) then
                adjusting = false
                DeleteEntity(previewPed)
                SetModelAsNoLongerNeeded(pedModel)
                
                offset.x = math.floor(offset.x * 100 + 0.5) / 100
                offset.y = math.floor(offset.y * 100 + 0.5) / 100
                offset.z = math.floor(offset.z * 100 + 0.5) / 100
                heading = math.floor(heading * 10 + 0.5) / 10
                
                Notify('Ped repositioned!', 'success')
                
                local updatedData = {
                    name = stash.name,
                    type = stash.type,
                    owner = stash.owner,
                    job = stash.job,
                    coords = coords,
                    slots = stash.slots,
                    weight = stash.weight,
                    ped_model = stash.ped_model,
                    ped_offset = offset,
                    ped_heading = heading,
                    object_model = stash.object_model,
                    object_offset = stash.object_offset,
                    object_heading = stash.object_heading
                }
                
                TriggerServerEvent('qb-stashmanager:server:UpdateStash', stash.id, updatedData)
            end
            
            if IsControlJustPressed(0, 194) then
                adjusting = false
                DeleteEntity(previewPed)
                SetModelAsNoLongerNeeded(pedModel)
                Notify('Cancelled', 'error')
            end
        end
    end)
end

function OpenRepositionObject(stash)
    local success, coords = pcall(function() return json.decode(stash.coords) end)
    if not success or not coords then
        Notify('Failed to load stash coordinates', 'error')
        return
    end
    
    local stashCoords = vector3(coords.x, coords.y, coords.z)
    local objectModel = GetHashKey(stash.object_model)
    
    RequestModel(objectModel)
    local loadAttempts = 0
    while not HasModelLoaded(objectModel) and loadAttempts < 200 do
        Wait(100)
        loadAttempts = loadAttempts + 1
    end
    
    if not HasModelLoaded(objectModel) then
        Notify('Failed to load object model!', 'error')
        return
    end
    
    local currentOffset = {x = 0.0, y = 0.0, z = 0.0}
    if stash.object_offset then
        if type(stash.object_offset) == 'table' then
            currentOffset = stash.object_offset
        elseif type(stash.object_offset) == 'string' then
            local offsetSuccess, result = pcall(function() return json.decode(stash.object_offset) end)
            if offsetSuccess and result then
                currentOffset = result
            end
        end
    end
    
    local previewObject = CreateObject(objectModel, stashCoords.x, stashCoords.y, stashCoords.z, false, false, false)
    SetEntityAlpha(previewObject, 200, false)
    SetEntityCollision(previewObject, false, false)
    
    local offset = {x = currentOffset.x, y = currentOffset.y, z = currentOffset.z}
    local heading = stash.object_heading or 0.0
    local baseCoords = stashCoords
    
    Notify('Arrows=Move | Q/E/Scroll=Rotate | PgUp/Dn=Height | G=Snap | Enter=Save | Backspace=Cancel', 'primary', 10000)
    
    CreateThread(function()
        local adjusting = true
        local moveSpeed = 0.05
        local rotSpeed = 5.0
        
        while adjusting do
            Wait(0)
            
            local finalX = baseCoords.x + offset.x
            local finalY = baseCoords.y + offset.y
            local finalZ = baseCoords.z + offset.z
            
            SetEntityCoords(previewObject, finalX, finalY, finalZ, false, false, false, false)
            SetEntityHeading(previewObject, heading)
            
            DrawText3DAtCoords(finalX, finalY, finalZ + 1.0, 
                string.format('~b~OBJ~w~ X:~g~%.2f~w~ Y:~g~%.2f~w~ Z:~g~%.2f~w~ H:~g~%.1f°', 
                offset.x, offset.y, offset.z, heading))
            
            if IsControlPressed(0, 172) then offset.y = offset.y + moveSpeed end
            if IsControlPressed(0, 173) then offset.y = offset.y - moveSpeed end
            if IsControlPressed(0, 174) then offset.x = offset.x - moveSpeed end
            if IsControlPressed(0, 175) then offset.x = offset.x + moveSpeed end
            if IsControlPressed(0, 10) then offset.z = offset.z + moveSpeed end
            if IsControlPressed(0, 11) then offset.z = offset.z - moveSpeed end
            
            if IsControlPressed(0, 44) then
                heading = heading - rotSpeed
                if heading < 0 then heading = heading + 360 end
            end
            if IsControlPressed(0, 38) then
                heading = heading + rotSpeed
                if heading >= 360 then heading = heading - 360 end
            end
            
            if IsControlJustPressed(0, 241) then
                heading = heading + (rotSpeed * 2)
                if heading >= 360 then heading = heading - 360 end
                --Notify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            if IsControlJustPressed(0, 242) then
                heading = heading - (rotSpeed * 2)
                if heading < 0 then heading = heading + 360 end
                --Notify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            
            if IsControlJustPressed(0, 47) then
                local success, groundZ = GetGroundZFor_3dCoord(finalX, finalY, finalZ + 5.0, false)
                if success then
                    offset.z = (groundZ - baseCoords.z) + 0.5
                    --Notify('Object snapped to ground!', 'success', 2000)
                end
            end
            
            if IsControlPressed(0, 21) then
                moveSpeed = 0.01
                rotSpeed = 1.0
            else
                moveSpeed = 0.05
                rotSpeed = 5.0
            end
            
            if IsControlJustPressed(0, 191) then
                adjusting = false
                DeleteEntity(previewObject)
                SetModelAsNoLongerNeeded(objectModel)
                
                offset.x = math.floor(offset.x * 100 + 0.5) / 100
                offset.y = math.floor(offset.y * 100 + 0.5) / 100
                offset.z = math.floor(offset.z * 100 + 0.5) / 100
                heading = math.floor(heading * 10 + 0.5) / 10
                
                Notify('Object repositioned!', 'success')
                
                local updatedData = {
                    name = stash.name,
                    type = stash.type,
                    owner = stash.owner,
                    job = stash.job,
                    coords = coords,
                    slots = stash.slots,
                    weight = stash.weight,
                    ped_model = stash.ped_model,
                    ped_offset = stash.ped_offset,
                    ped_heading = stash.ped_heading,
                    object_model = stash.object_model,
                    object_offset = offset,
                    object_heading = heading
                }
                
                TriggerServerEvent('qb-stashmanager:server:UpdateStash', stash.id, updatedData)
            end
            
            if IsControlJustPressed(0, 194) then
                adjusting = false
                DeleteEntity(previewObject)
                SetModelAsNoLongerNeeded(objectModel)
                Notify('Cancelled', 'error')
            end
        end
    end)
end

function OpenStashEditForm(stash)
    local input = lib.inputDialog('Edit: ' .. stash.name, {
        {type = 'input', label = 'Stash Name', default = stash.name, required = true, max = 50},
        {type = 'number', label = 'Slots', default = stash.slots, min = 1, max = 500},
        {type = 'number', label = 'Weight (grams)', default = stash.weight, min = 1000, max = 10000000}
    })
    
    if not input then return end
    
    local success, coords = pcall(function() return json.decode(stash.coords) end)
    if not success then return end
    
    local updatedData = {
        name = input[1],
        type = stash.type,
        owner = stash.owner,
        job = stash.job,
        coords = coords,
        slots = input[2],
        weight = input[3],
        ped_model = stash.ped_model,
        ped_offset = stash.ped_offset,
        ped_heading = stash.ped_heading,
        object_model = stash.object_model,
        object_offset = stash.object_offset,
        object_heading = stash.object_heading
    }
    
    TriggerServerEvent('qb-stashmanager:server:UpdateStash', stash.id, updatedData)
end

local function ResolveMemberNames(stash, members, cb)
    if not members or #members == 0 then
        cb({})
        return
    end

    local resolved = {}
    local index = 1

    local function fetchNext()
        local member = members[index]
        if not member then
            cb(resolved)
            return
        end

        QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetPlayerName', function(name)
            resolved[index] = {
                citizenid = member.citizenid,
                is_manager = member.is_manager,
                name = name
            }
            index = index + 1
            if index > #members then
                cb(resolved)
            else
                fetchNext()
            end
        end, member.citizenid)
    end

    fetchNext()
end

function OpenSharedStashesMenu(stashes)
    local list = {}
    for _, stash in pairs(stashes or {}) do
        table.insert(list, stash)
    end

    if #list == 0 then
        Notify('No shared stashes found', 'error')
        return
    end

    local options = {}
    for _, stash in ipairs(list) do
        local memberCount = CountTableEntries(stash.access)
        local descriptor = 'Members: ' .. memberCount
        if stash.can_manage then
            descriptor = descriptor .. ' • Manager'
        end
        table.insert(options, {
            title = stash.name,
            description = descriptor,
            icon = 'people-group',
            onSelect = function()
                OpenSharedStashActionMenu(stash)
            end
        })
    end

    lib.registerContext({
        id = 'shared_stash_manage_list',
        title = 'Shared Stashes (' .. #list .. ')',
        options = options
    })

    lib.showContext('shared_stash_manage_list')
end

function OpenSharedStashActionMenu(stash)
    local options = {
        {
            title = 'Open Stash',
            description = 'Open inventory',
            icon = 'box-open',
            onSelect = function()
                TriggerServerEvent('qb-stashmanager:server:OpenStash', stash.id)
            end
        }
    }

    if stash.can_manage then
        table.insert(options, {
            title = 'Rename Stash',
            description = 'Change stash label',
            icon = 'pen',
            onSelect = function()
                PromptRenameSharedStash(stash)
            end
        })

        table.insert(options, {
            title = 'Add Member',
            description = 'Give access to another player',
            icon = 'user-plus',
            arrow = true,
            onSelect = function()
                OpenSharedAddMemberMenu(stash)
            end
        })

        table.insert(options, {
            title = 'Manage Members',
            description = 'View and remove members',
            icon = 'users-gear',
            onSelect = function()
                ViewSharedStashMembers(stash)
            end
        })
    end

    lib.registerContext({
        id = 'shared_stash_actions_' .. stash.id,
        title = stash.name,
        menu = 'shared_stash_manage_list',
        options = options
    })

    lib.showContext('shared_stash_actions_' .. stash.id)
end

function PromptRenameSharedStash(stash)
    if not stash.can_manage then return end

    local input = lib.inputDialog('Rename ' .. stash.name, {
        {type = 'input', label = 'New Name', required = true, max = 50, default = stash.name}
    })

    if not input or not input[1] or input[1] == '' then return end

    stash.name = input[1]
    TriggerServerEvent('qb-stashmanager:server:RenameSharedStash', stash.id, input[1])
    OpenSharedStashActionMenu(stash)
end

function OpenSharedAddMemberMenu(stash)
    if not stash.can_manage then return end

    lib.registerContext({
        id = 'shared_stash_add_' .. stash.id,
        title = 'Add Member',
        menu = 'shared_stash_actions_' .. stash.id,
        options = {
            {
                title = 'By Server ID',
                description = 'Online player by server ID',
                icon = 'user-clock',
                onSelect = function()
                    AddSharedMemberByServerId(stash)
                end
            },
            {
                title = 'By Citizen ID',
                description = 'Offline/online player by citizen ID',
                icon = 'id-card',
                onSelect = function()
                    AddSharedMemberByCitizenId(stash)
                end
            }
        }
    })

    lib.showContext('shared_stash_add_' .. stash.id)
end

function AddSharedMemberByServerId(stash)
    if not stash.can_manage then return end

    local input = lib.inputDialog('Add Member (Server ID)', {
        {type = 'number', label = 'Player Server ID', required = true, min = 1}
    })

    if not input then return end

    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetCitizenId', function(citizenid)
        if not citizenid then
            Notify('Player not found', 'error')
            return
        end

        stash.access = stash.access or {}
        stash.access[citizenid] = {is_manager = false}
        TriggerServerEvent('qb-stashmanager:server:AddSharedAccess', stash.id, citizenid, false)
    end, tonumber(input[1]))
end

function AddSharedMemberByCitizenId(stash)
    if not stash.can_manage then return end

    local input = lib.inputDialog('Add Member (Citizen ID)', {
        {type = 'input', label = 'Citizen ID', required = true, min = 8, max = 12}
    })

    if not input then return end

    local citizenid = input[1]:upper()

    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetPlayerName', function(playerName)
        if playerName then
            local confirm = lib.alertDialog({
                header = 'Confirm Access',
                content = 'Add **' .. playerName .. '** to this stash?',
                centered = true,
                cancel = true
            })

            if confirm == 'confirm' then
                stash.access = stash.access or {}
                stash.access[citizenid] = {is_manager = false}
                TriggerServerEvent('qb-stashmanager:server:AddSharedAccess', stash.id, citizenid, false)
            end
        else
            stash.access = stash.access or {}
            stash.access[citizenid] = {is_manager = false}
            TriggerServerEvent('qb-stashmanager:server:AddSharedAccess', stash.id, citizenid, false)
        end
    end, citizenid)
end

local function TransferSharedStashOwnership(stash, member)
    local confirm = lib.alertDialog({
        header = 'Transfer Ownership',
        content = 'Transfer shared stash to **' .. (member.name or member.citizenid) .. '**?',
        centered = true,
        cancel = true
    })

    if confirm ~= 'confirm' then return end

    stash.access = stash.access or {}
    stash.access[member.citizenid] = stash.access[member.citizenid] or {}
    for citizen, data in pairs(stash.access) do
        data.is_manager = (citizen == member.citizenid)
    end

    member.is_manager = true

    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.citizenid then
        local myEntry = stash.access[playerData.citizenid]
        stash.can_manage = (myEntry and myEntry.is_manager) or (stash.created_by == playerData.citizenid)
    end

    TriggerServerEvent('qb-stashmanager:server:TransferSharedManager', stash.id, member.citizenid)
    Notify('Ownership transfer requested', 'success')
end

local function RemoveSharedMember(stash, member)
    local confirm = lib.alertDialog({
        header = 'Remove Access',
        content = 'Remove access for **' .. (member.name or member.citizenid) .. '**?',
        centered = true,
        cancel = true
    })

    if confirm ~= 'confirm' then return end

    if stash.access then
        stash.access[member.citizenid] = nil
    end

    TriggerServerEvent('qb-stashmanager:server:RemoveSharedAccess', stash.id, member.citizenid)
end

function OpenSharedMemberActionsMenu(stash, member)
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData or not playerData.citizenid then return end

    local options = {}

    if member.citizenid ~= playerData.citizenid then
        table.insert(options, {
            title = 'Transfer Ownership',
            description = 'Make this member the new manager',
            icon = 'person-arrow-up-from-line',
            onSelect = function()
                TransferSharedStashOwnership(stash, member)
            end
        })
    end

    table.insert(options, {
        title = 'Remove Access',
        description = 'Revoke access for this member',
        icon = 'user-minus',
        onSelect = function()
            RemoveSharedMember(stash, member)
        end
    })

    lib.registerContext({
        id = 'shared_member_actions_' .. stash.id .. '_' .. member.citizenid,
        title = member.name or member.citizenid,
        menu = 'shared_stash_members_' .. stash.id,
        options = options
    })

    lib.showContext('shared_member_actions_' .. stash.id .. '_' .. member.citizenid)
end

function ViewSharedStashMembers(stash)
    if not stash.can_manage then
        Notify('No permission', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetSharedStashMembers', function(members, errorCode)
        if not members then
            if errorCode == 'no_permission' then
                Notify('No permission', 'error')
            elseif errorCode == 'not_found' then
                Notify('Stash not found', 'error')
            end
            return
        end

        ResolveMemberNames(stash, members, function(resolved)
            if not resolved or #resolved == 0 then
                Notify('No members found', 'error')
                return
            end

            local accessMap = {}
            for _, entry in ipairs(resolved) do
                accessMap[entry.citizenid] = {is_manager = entry.is_manager and true or false}
            end
            stash.access = accessMap

            local options = {}
            for _, member in ipairs(resolved) do
                local label = member.name or member.citizenid
                if member.is_manager then
                    label = label .. ' [Manager]'
                end

                table.insert(options, {
                    title = label,
                    description = 'Citizen ID: ' .. member.citizenid,
                    icon = member.is_manager and 'user-shield' or 'user',
                    arrow = true,
                    onSelect = function()
                        OpenSharedMemberActionsMenu(stash, member)
                    end
                })
            end

            lib.registerContext({
                id = 'shared_stash_members_' .. stash.id,
                title = 'Members: ' .. stash.name,
                menu = 'shared_stash_actions_' .. stash.id,
                options = options
            })

            lib.showContext('shared_stash_members_' .. stash.id)
        end)
    end, stash.id)
end

-- Access Logs Menu Functions
function OpenAccessLogsMenu()
    lib.registerContext({
        id = 'access_logs_main',
        title = 'Access Logs',
        menu = 'stash_manager_main',
        options = {
            {
                title = 'Recent Activity',
                description = 'View all recent stash activity',
                icon = 'clock',
                onSelect = function()
                    OpenRecentLogsMenu()
                end
            },
            {
                title = 'By Stash',
                description = 'View logs for a specific stash',
                icon = 'box',
                onSelect = function()
                    OpenStashLogSelectionMenu()
                end
            },
            {
                title = 'By Player',
                description = 'View logs for a specific player',
                icon = 'user',
                onSelect = function()
                    OpenPlayerLogSelectionMenu()
                end
            }
        }
    })
    lib.showContext('access_logs_main')
end

function OpenRecentLogsMenu()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetRecentLogs', function(logs)
        if not logs or #logs == 0 then
            Notify('No logs found', 'error')
            return
        end
        
        local options = {}
        for _, log in ipairs(logs) do
            local actionIcon = 'info'
            local actionText = 'Opened'
            
            if log.action == 'item_added' then
                actionIcon = 'plus'
                actionText = 'Added ' .. (log.item_amount or 0) .. 'x ' .. (log.item_name or 'item')
            elseif log.action == 'item_removed' then
                actionIcon = 'minus'
                actionText = 'Removed ' .. (log.item_amount or 0) .. 'x ' .. (log.item_name or 'item')
            elseif log.action == 'open' then
                actionIcon = 'box-open'
                actionText = 'Opened stash'
            end
            
            local timeText = FormatTimestamp(log.created_at)
            
            table.insert(options, {
                title = log.stash_name,
                description = actionText .. '\nPlayer: ' .. log.citizenid .. '\n' .. timeText,
                icon = actionIcon,
                disabled = true
            })
        end
        
        lib.registerContext({
            id = 'recent_logs_view',
            title = 'Recent Activity (' .. #logs .. ')',
            menu = 'access_logs_main',
            options = options
        })
        
        lib.showContext('recent_logs_view')
    end, 100)
end

function OpenStashLogSelectionMenu()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetAllStashes', function(stashes)
        if not stashes or #stashes == 0 then
            Notify('No stashes found', 'error')
            return
        end
        
        local options = {}
        for _, stash in ipairs(stashes) do
            table.insert(options, {
                title = stash.name,
                description = 'Type: ' .. stash.type:upper(),
                icon = stash.type == 'private' and 'user' or (stash.type == 'job' and 'briefcase' or 'users'),
                onSelect = function()
                    OpenStashLogsView(stash.id, stash.name)
                end
            })
        end
        
        lib.registerContext({
            id = 'stash_log_selection',
            title = 'Select Stash',
            menu = 'access_logs_main',
            options = options
        })
        
        lib.showContext('stash_log_selection')
    end)
end

function OpenStashLogsView(stashId, stashName)
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetStashLogStats', function(stats)
        QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetStashLogs', function(logs)
            local options = {}
            
            if stats and stats.total_access then
                table.insert(options, {
                    title = 'Statistics',
                    description = string.format('Total Access: %d | Opens: %d | Adds: %d | Removes: %d | Unique Users: %d',
                        stats.total_access or 0,
                        stats.total_opens or 0,
                        stats.total_adds or 0,
                        stats.total_removes or 0,
                        stats.unique_users or 0),
                    icon = 'chart-bar',
                    disabled = true
                })
            end
            
            if not logs or #logs == 0 then
                table.insert(options, {
                    title = 'No logs found',
                    description = 'This stash has no activity yet',
                    icon = 'info',
                    disabled = true
                })
            else
                for _, log in ipairs(logs) do
                    local actionIcon = 'info'
                    local actionText = 'Opened'
                    
                    if log.action == 'item_added' then
                        actionIcon = 'plus'
                        actionText = 'Added ' .. (log.item_amount or 0) .. 'x ' .. (log.item_name or 'item')
                    elseif log.action == 'item_removed' then
                        actionIcon = 'minus'
                        actionText = 'Removed ' .. (log.item_amount or 0) .. 'x ' .. (log.item_name or 'item')
                    elseif log.action == 'open' then
                        actionIcon = 'box-open'
                        actionText = 'Opened stash'
                    end
                    
                    local timeText = FormatTimestamp(log.created_at)
                    
                    table.insert(options, {
                        title = actionText,
                        description = 'Player: ' .. log.citizenid .. '\n' .. timeText,
                        icon = actionIcon,
                        disabled = true
                    })
                end
            end
            
            lib.registerContext({
                id = 'stash_logs_view_' .. stashId,
                title = 'Logs: ' .. stashName .. ' (' .. #logs .. ')',
                menu = 'stash_log_selection',
                options = options
            })
            
            lib.showContext('stash_logs_view_' .. stashId)
        end, stashId, 50, 0)
    end, stashId)
end

function OpenPlayerLogSelectionMenu()
    local input = lib.inputDialog('View Player Logs', {
        {type = 'input', label = 'Citizen ID', description = 'Enter player citizen ID', required = true, min = 8, max = 12}
    })
    
    if not input or not input[1] then return end
    
    local citizenid = input[1]:upper()
    
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetPlayerName', function(playerName)
        QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetLogsByCitizen', function(logs)
            if not logs or #logs == 0 then
                Notify('No logs found for this player', 'error')
                return
            end
            
            local options = {}
            for _, log in ipairs(logs) do
                local actionIcon = 'info'
                local actionText = 'Opened'
                
                if log.action == 'item_added' then
                    actionIcon = 'plus'
                    actionText = 'Added ' .. (log.item_amount or 0) .. 'x ' .. (log.item_name or 'item')
                elseif log.action == 'item_removed' then
                    actionIcon = 'minus'
                    actionText = 'Removed ' .. (log.item_amount or 0) .. 'x ' .. (log.item_name or 'item')
                elseif log.action == 'open' then
                    actionIcon = 'box-open'
                    actionText = 'Opened stash'
                end
                
                local timeText = FormatTimestamp(log.created_at)
                
                table.insert(options, {
                    title = log.stash_name .. ' - ' .. actionText,
                    description = timeText,
                    icon = actionIcon,
                    disabled = true
                })
            end
            
            lib.registerContext({
                id = 'player_logs_view_' .. citizenid,
                title = (playerName or citizenid) .. '\'s Logs (' .. #logs .. ')',
                menu = 'access_logs_main',
                options = options
            })
            
            lib.showContext('player_logs_view_' .. citizenid)
        end, citizenid, 100, 0)
    end, citizenid)
end

function FormatTimestamp(timestamp)
    if not timestamp then return 'Unknown' end
    
    -- Handle both string and number timestamps
    local time = timestamp
    if type(timestamp) == 'string' then
        -- Parse MySQL timestamp format (YYYY-MM-DD HH:MM:SS)
        local year, month, day, hour, minute, second = timestamp:match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
        if year then
            return string.format('%s/%s/%s %s:%s', month, day, year, hour, minute)
        end
        return timestamp
    end
    
    return timestamp
end

-- Blip Configuration Menu
function OpenBlipConfigurationMenu()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetBlipSettings', function(settings)
        local options = {}
        
        local stashTypes = {'private', 'public', 'job', 'shared'}
        local typeLabels = {
            ['private'] = 'Private Stash',
            ['public'] = 'Public Stash',
            ['job'] = 'Job Stash',
            ['shared'] = 'Shared Stash'
        }
        
        for _, stashType in ipairs(stashTypes) do
            local setting = settings[stashType] or {sprite = 478, color = 3, label = typeLabels[stashType]}
            local description = 'Sprite: ' .. setting.sprite .. ' | Color: ' .. setting.color
            if setting.label then
                description = description .. '\nLabel: ' .. setting.label
            end
            
            table.insert(options, {
                title = typeLabels[stashType],
                description = description,
                icon = stashType == 'private' and 'user' or (stashType == 'job' and 'briefcase' or (stashType == 'shared' and 'share-nodes' or 'users')),
                arrow = true,
                onSelect = function()
                    OpenBlipTypeConfigMenu(stashType, setting)
                end
            })
        end
        
        lib.registerContext({
            id = 'blip_config_main',
            title = 'Blip Configuration',
            menu = 'stash_manager_main',
            options = options
        })
        
        lib.showContext('blip_config_main')
    end)
end

function OpenBlipTypeConfigMenu(stashType, currentSetting)
    local typeLabels = {
        ['private'] = 'Private Stash',
        ['public'] = 'Public Stash',
        ['job'] = 'Job Stash',
        ['shared'] = 'Shared Stash'
    }
    
    local typeLabel = typeLabels[stashType] or stashType
    
    lib.registerContext({
        id = 'blip_config_' .. stashType,
        title = 'Configure: ' .. typeLabel,
        menu = 'blip_config_main',
        options = {
            {
                title = 'Current Settings',
                description = 'Sprite: ' .. (currentSetting.sprite or 478) .. ' | Color: ' .. (currentSetting.color or 3),
                icon = 'info',
                disabled = true
            },
            {
                title = 'Change Sprite',
                description = 'Set blip sprite ID (current: ' .. (currentSetting.sprite or 478) .. ')',
                icon = 'image',
                onSelect = function()
                    local input = lib.inputDialog('Set Blip Sprite', {
                        {type = 'number', label = 'Sprite ID', description = 'Enter blip sprite ID (e.g., 478 for box)', default = currentSetting.sprite or 478, required = true, min = 1, max = 826}
                    })
                    
                    if input and input[1] then
                        UpdateBlipSetting(stashType, input[1], currentSetting.color or 3, currentSetting.label or typeLabel)
                    end
                end
            },
            {
                title = 'Change Color',
                description = 'Set blip color ID (current: ' .. (currentSetting.color or 3) .. ')',
                icon = 'palette',
                onSelect = function()
                    local input = lib.inputDialog('Set Blip Color', {
                        {type = 'number', label = 'Color ID', description = 'Enter blip color ID (0-85)', default = currentSetting.color or 3, required = true, min = 0, max = 85}
                    })
                    
                    if input and input[1] then
                        UpdateBlipSetting(stashType, currentSetting.sprite or 478, input[1], currentSetting.label or typeLabel)
                    end
                end
            },
            {
                title = 'Change Label',
                description = 'Set blip label (current: ' .. (currentSetting.label or typeLabel) .. ')',
                icon = 'tag',
                onSelect = function()
                    local input = lib.inputDialog('Set Blip Label', {
                        {type = 'input', label = 'Label', description = 'Enter blip label', default = currentSetting.label or typeLabel, required = true, max = 100}
                    })
                    
                    if input and input[1] then
                        UpdateBlipSetting(stashType, currentSetting.sprite or 478, currentSetting.color or 3, input[1])
                    end
                end
            },
            {
                title = 'Quick Color Presets',
                description = 'Select common blip colors',
                icon = 'paint-brush',
                arrow = true,
                onSelect = function()
                    OpenBlipColorPresets(stashType, currentSetting)
                end
            }
        }
    })
    
    lib.showContext('blip_config_' .. stashType)
end

function OpenBlipColorPresets(stashType, currentSetting)
    local colorPresets = {
        {name = 'Red', color = 1},
        {name = 'Green', color = 2},
        {name = 'Blue', color = 3},
        {name = 'Yellow', color = 5},
        {name = 'Orange', color = 17},
        {name = 'Purple', color = 27},
        {name = 'Pink', color = 23},
        {name = 'White', color = 4},
        {name = 'Black', color = 0}
    }
    
    local typeLabels = {
        ['private'] = 'Private Stash',
        ['public'] = 'Public Stash',
        ['job'] = 'Job Stash',
        ['shared'] = 'Shared Stash'
    }
    local typeLabel = typeLabels[stashType] or stashType
    
    local options = {}
    for _, preset in ipairs(colorPresets) do
        table.insert(options, {
            title = preset.name,
            description = 'Color ID: ' .. preset.color,
            icon = 'circle',
            onSelect = function()
                UpdateBlipSetting(stashType, currentSetting.sprite or 478, preset.color, currentSetting.label or typeLabel)
            end
        })
    end
    
    lib.registerContext({
        id = 'blip_color_presets_' .. stashType,
        title = 'Color Presets',
        menu = 'blip_config_' .. stashType,
        options = options
    })
    
    lib.showContext('blip_color_presets_' .. stashType)
end

function UpdateBlipSetting(stashType, sprite, color, label)
    TriggerServerEvent('qb-stashmanager:server:UpdateBlipSetting', stashType, sprite, color, label)
    Notify('Blip settings updated! Refreshing...', 'success')
    Wait(500)
    OpenBlipConfigurationMenu()
end

