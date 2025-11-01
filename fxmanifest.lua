fx_version 'cerulean'
game 'gta5'

author 'AG Framework'
description 'QBCore Stash Manager with Ped & Object Positioning'
version '1.0.3'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/menu.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
    'server/version.lua'  -- Add this new file
}

dependencies {
    'qb-core',
    'oxmysql',
    -- ONE of the following:
    'ox_inventory'
    -- 'qb-inventory'
    -- 'qs-inventory'
    -- 'ps-inventory'
}


lua54 'yes'

