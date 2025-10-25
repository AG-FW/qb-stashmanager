-- server/version.lua
-- GitHub Version Checker for AG-StashManager

local CURRENT_VERSION = '1.0.2'
local RESOURCE_NAME = 'AG-StashManager'
local GITHUB_REPO = 'AG-FW/qb-stashmanager'
local CHECK_URL = 'https://api.github.com/repos/AG-FW/qb-stashmanager/releases/latest'


CreateThread(function()
    Wait(2000) -- Wait for server to fully start
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    print('^5[' .. RESOURCE_NAME .. ']^7 Checking for updates...')
    
    PerformHttpRequest(CHECK_URL, function(statusCode, response, headers)
        if statusCode == 200 then
            local success, data = pcall(function() return json.decode(response) end)
            
            if success and data and data.tag_name then
                local latestVersion = data.tag_name:gsub('v', '')
                
                if latestVersion ~= CURRENT_VERSION then
                    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
                    print('^1[' .. RESOURCE_NAME .. ']^7 ^1UPDATE AVAILABLE!^7')
                    print('^3[' .. RESOURCE_NAME .. ']^7 Current: ^1' .. CURRENT_VERSION .. '^7 → Latest: ^2' .. latestVersion .. '^7')
                    
                    if data.body then
                        local changelog = data.body:sub(1, 300)
                        print('^3[' .. RESOURCE_NAME .. ']^7 Changelog:')
                        print('^7' .. changelog .. '^7')
                    end
                    
                    print('^3[' .. RESOURCE_NAME .. ']^7 Download: ^5' .. data.html_url .. '^7')
                    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
                else
                    print('^2[' .. RESOURCE_NAME .. ']^7 You are running the latest version! (^2' .. CURRENT_VERSION .. '^7)')
                    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
                end
            end
        elseif statusCode == 404 then
            print('^3[' .. RESOURCE_NAME .. ']^7 No releases found on GitHub')
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        else
            print('^1[' .. RESOURCE_NAME .. ']^7 Failed to check for updates (Status: ' .. statusCode .. ')')
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        end
    end, 'GET')
end)
