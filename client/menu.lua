local QBCore = exports['qb-core']:GetCoreObject()
function OpenStashManagerMenu()
    lib.registerContext({
        id = 'stash_manager_main',
        title = 'Stash Manager',
        options = {
            {title = 'Create New Stash', description = 'Create a new stash at your location', icon = 'plus', onSelect = function() OpenCreateStashMenu() end},
            {title = 'Manage Stashes', description = 'View and edit existing stashes', icon = 'list', onSelect = function() OpenManageStashesMenu() end}
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
            {title = 'Job Stash', description = 'Only specific job can access', icon = 'briefcase', onSelect = function() OpenStashCreationForm('job') end}
        }
    })
    lib.showContext('stash_create_type')
end

function OpenStashCreationForm(stashType)
    local input = lib.inputDialog('Create ' .. Config.StashTypes[stashType], {
        {type = 'input', label = 'Stash Name', description = 'Enter stash name', required = true, max = 50},
        {type = 'number', label = 'Slots', description = 'Inventory slots', default = Config.DefaultSlots, min = 1, max = 500},
        {type = 'number', label = 'Weight (grams)', description = 'Max weight', default = Config.DefaultWeight, min = 1000, max = 10000000},
        {type = 'input', label = 'Ped Model (optional)', description = 'e.g., s_m_m_ups_01', required = false},
        {type = 'input', label = 'Object Model (optional)', description = 'e.g., prop_box_wood05a', required = false}
    })
    
    if not input then return end
    
    --print('^3[StashManager Debug]^7 Form submitted')
    --print('^3[StashManager Debug]^7 Ped model: ' .. (input[4] or 'none'))
    --print('^3[StashManager Debug]^7 Object model: ' .. (input[5] or 'none'))
    
    if input[4] and input[4] ~= '' then
        --print('^3[StashManager Debug]^7 Ped specified, opening ped positioning')
        OpenLivePedPositioning(input, stashType)
    elseif input[5] and input[5] ~= '' then
        --print('^3[StashManager Debug]^7 Object specified, opening object positioning')
        OpenObjectPositioningMenu(input, stashType)
    else
        --print('^3[StashManager Debug]^7 No ped/object, proceeding directly')
        if stashType == 'job' then
            OpenJobSelectionMenu(input, nil, nil)
        elseif stashType == 'private' then
            OpenPrivateStashOptionsMenu(input, nil, nil)
        elseif stashType == 'public' then
            CreateStashAtLocation(input, 'public', nil, nil, nil, nil)
        end
    end
end

function OpenLivePedPositioning(stashData, stashType)
    --print('^2[StashManager Debug]^7 Starting ped positioning')
    --print('^2[StashManager Debug]^7 Ped model: ' .. stashData[4])
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local pedModel = GetHashKey(stashData[4])
    
    RequestModel(pedModel)
    
    local loadAttempts = 0
    while not HasModelLoaded(pedModel) and loadAttempts < 200 do
        Wait(100)
        loadAttempts = loadAttempts + 1
    end
    
    if not HasModelLoaded(pedModel) then
        QBCore.FunctionsNotify('Failed to load ped model!', 'error')
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
    
    QBCore.FunctionsNotify('Arrows=Move | Q/E/Scroll=Rotate | G=Snap | Enter=Save | Backspace=Cancel', 'primary', 10000)
    
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
               -- QBCore.FunctionsNotify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            if IsControlJustPressed(0, 242) then
                heading = heading - (rotSpeed * 2)
                if heading < 0 then heading = heading + 360 end
              --  QBCore.FunctionsNotify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            
            if IsControlJustPressed(0, 47) then
                local success, groundZ = GetGroundZFor_3dCoord(finalX, finalY, finalZ + 5.0, false)
                if success then
                    offset.z = (groundZ - baseCoords.z)
                    QBCore.FunctionsNotify('Ped snapped to ground!', 'success', 2000)
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
                
                --print('^2[StashManager]^7 Ped offset saved: X=' .. offset.x .. ' Y=' .. offset.y .. ' Z=' .. offset.z .. ' H=' .. heading)
                QBCore.FunctionsNotify('Ped position saved!', 'success')
                
                stashData.ped_offset = offset
                stashData.ped_heading = heading
                
                if stashData[5] and stashData[5] ~= '' then
                    OpenObjectPositioningMenu(stashData, stashType)
                else
                    ProceedWithStashCreation(stashData, stashType, nil, nil)
                end
            end
            
            if IsControlJustPressed(0, 194) then
                adjusting = false
                DeleteEntity(previewPed)
                SetModelAsNoLongerNeeded(pedModel)
                QBCore.FunctionsNotify('Cancelled', 'error')
            end
        end
    end)
end

function OpenObjectPositioningMenu(stashData, stashType)
    --print('^2[StashManager Debug]^7 Object positioning menu opened')
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
                    --print('^2[StashManager Debug]^7 Live preview selected')
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
    --print('^2[StashManager Debug]^7 Starting live positioning')
    --print('^2[StashManager Debug]^7 Object model: ' .. stashData[5])
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local objectModel = GetHashKey(stashData[5])
    
    RequestModel(objectModel)
    
    local loadAttempts = 0
    while not HasModelLoaded(objectModel) and loadAttempts < 200 do
        Wait(100)
        loadAttempts = loadAttempts + 1
    end
    
    if not HasModelLoaded(objectModel) then
        QBCore.FunctionsNotify('Failed to load object model!', 'error')
        SetModelAsNoLongerNeeded(objectModel)
        return
    end
    
    local previewObject = CreateObject(objectModel, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
    SetEntityAlpha(previewObject, 200, false)
    SetEntityCollision(previewObject, false, false)
    
    local offset = {x = 0.0, y = 1.0, z = 0.0}
    local heading = 0.0
    local baseCoords = playerCoords
    
    QBCore.FunctionsNotify('Arrows=Move | Q/E/Scroll=Rotate | PgUp/Dn=Height | G=Snap | Enter=Save | Backspace=Cancel', 'primary', 10000)
    
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
               -- QBCore.FunctionsNotify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            if IsControlJustPressed(0, 242) then
                heading = heading - (rotSpeed * 2)
                if heading < 0 then heading = heading + 360 end
               -- QBCore.FunctionsNotify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            
            if IsControlJustPressed(0, 47) then
                local success, groundZ = GetGroundZFor_3dCoord(finalX, finalY, finalZ + 5.0, false)
                if success then
                    offset.z = (groundZ - baseCoords.z) + 0.5
                    QBCore.FunctionsNotify('Snapped to ground! Z: ' .. string.format('%.2f', offset.z), 'success', 2000)
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
                
                --print('^2[StashManager]^7 Object offset saved: X=' .. offset.x .. ' Y=' .. offset.y .. ' Z=' .. offset.z .. ' H=' .. heading)
                QBCore.FunctionsNotify('Position saved!', 'success')
                
                ProceedWithStashCreation(stashData, stashType, offset, heading)
            end
            
            if IsControlJustPressed(0, 194) then
                adjusting = false
                DeleteEntity(previewObject)
                SetModelAsNoLongerNeeded(objectModel)
                QBCore.FunctionsNotify('Cancelled', 'error')
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
    --print('^2[StashManager Debug]^7 Proceeding with creation. Type: ' .. stashType)
    if stashType == 'job' then
        OpenJobSelectionMenu(stashData, objectOffset, objectHeading)
    elseif stashType == 'private' then
        OpenPrivateStashOptionsMenu(stashData, objectOffset, objectHeading)
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
            QBCore.FunctionsNotify('Player not found', 'error')
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
            QBCore.FunctionsNotify('Citizen ID not found', 'error')
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
        ped_model = data[4] ~= '' and data[4] or nil,
        ped_offset = data.ped_offset,
        ped_heading = data.ped_heading or 0.0,
        object_model = data[5] ~= '' and data[5] or nil,
        object_offset = objectOffset,
        object_heading = objectHeading or 0.0
    }
    
    --print('^2[StashManager Debug]^7 Creating private stash with ped/object data')
    TriggerServerEvent('qb-stashmanager:server:CreatePrivateStash', stashData, citizenid)
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

function CreateStashAtLocation(data, stashType, job, owner, objectOffset, objectHeading)
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
        ped_model = data[4] ~= '' and data[4] or nil,
        ped_offset = data.ped_offset,
        ped_heading = data.ped_heading or 0.0,
        object_model = data[5] ~= '' and data[5] or nil,
        object_offset = objectOffset,
        object_heading = objectHeading or 0.0
    }
    
    --print('^2[StashManager Debug]^7 Creating stash with all data')
    TriggerServerEvent('qb-stashmanager:server:CreateStash', stashData)
end

function OpenManageStashesMenu()
    QBCore.Functions.TriggerCallback('qb-stashmanager:server:GetAllStashes', function(stashes)
        if #stashes == 0 then
            QBCore.FunctionsNotify('No stashes found', 'error')
            return
        end
        
        local options = {}
        
        for _, stash in pairs(stashes) do
            local description = 'Type: ' .. stash.type:upper()
            if stash.type == 'private' and stash.owner then
                description = description .. '\nOwner: ' .. stash.owner
            elseif stash.type == 'job' and stash.job then
                description = description .. '\nJob: ' .. stash.job:upper()
            end
            
            table.insert(options, {
                title = stash.name,
                description = description,
                icon = stash.type == 'private' and 'user' or (stash.type == 'job' and 'briefcase' or 'users'),
                onSelect = function()
                    OpenStashEditMenu(stash)
                end
            })
        end
        
        lib.registerContext({
            id = 'stash_manage_list',
            title = 'Manage Stashes (' .. #stashes .. ')',
            menu = 'stash_manager_main',
            options = options
        })
        
        lib.showContext('stash_manage_list')
    end)
end

function OpenStashEditMenu(stash)
    local options = {
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
                    QBCore.FunctionsNotify('Teleported', 'success')
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
                    QBCore.FunctionsNotify('Ped model updated!', 'success')
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
                    QBCore.FunctionsNotify('Ped removed!', 'success')
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
                    QBCore.FunctionsNotify('Object model updated!', 'success')
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
                    QBCore.FunctionsNotify('Object removed!', 'success')
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
        QBCore.FunctionsNotify('Failed to load stash coordinates', 'error')
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
        QBCore.FunctionsNotify('Failed to load ped model!', 'error')
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
    
    QBCore.FunctionsNotify('Arrows=Move | Q/E/Scroll=Rotate | G=Snap | Enter=Save | Backspace=Cancel', 'primary', 10000)
    
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
               -- QBCore.FunctionsNotify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            if IsControlJustPressed(0, 242) then
                heading = heading - (rotSpeed * 2)
                if heading < 0 then heading = heading + 360 end
              --  QBCore.FunctionsNotify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            
            if IsControlJustPressed(0, 47) then
                local success, groundZ = GetGroundZFor_3dCoord(finalX, finalY, finalZ + 5.0, false)
                if success then
                    offset.z = (groundZ - baseCoords.z)
                    QBCore.FunctionsNotify('Ped snapped to ground!', 'success', 2000)
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
                
                QBCore.FunctionsNotify('Ped repositioned!', 'success')
                
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
                QBCore.FunctionsNotify('Cancelled', 'error')
            end
        end
    end)
end

function OpenRepositionObject(stash)
    local success, coords = pcall(function() return json.decode(stash.coords) end)
    if not success or not coords then
        QBCore.FunctionsNotify('Failed to load stash coordinates', 'error')
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
        QBCore.FunctionsNotify('Failed to load object model!', 'error')
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
    
    QBCore.FunctionsNotify('Arrows=Move | Q/E/Scroll=Rotate | PgUp/Dn=Height | G=Snap | Enter=Save | Backspace=Cancel', 'primary', 20000)
    
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
               -- QBCore.FunctionsNotify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            if IsControlJustPressed(0, 242) then
                heading = heading - (rotSpeed * 2)
                if heading < 0 then heading = heading + 360 end
                --QBCore.FunctionsNotify('Heading: ' .. math.floor(heading) .. '°', 'primary', 500)
            end
            
            if IsControlJustPressed(0, 47) then
                local success, groundZ = GetGroundZFor_3dCoord(finalX, finalY, finalZ + 5.0, false)
                if success then
                    offset.z = (groundZ - baseCoords.z) + 0.5
                    QBCore.FunctionsNotify('Object snapped to ground!', 'success', 2000)
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
                
                QBCore.FunctionsNotify('Object repositioned!', 'success')
                
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
                QBCore.FunctionsNotify('Cancelled', 'error')
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
