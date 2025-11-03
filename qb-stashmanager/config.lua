Config = {}

-- Database settings
Config.AutoCreateDatabase = true -- Set to false if you want to run SQL manually
Config.AutoUpdateSchema = true -- Automatically add missing columns on updates

-- Admin permission
Config.AdminGroup = 'admin' -- QBCore permission group

-- Default stash settings
Config.DefaultSlots = 50
Config.DefaultWeight = 100000 -- 100kg in grams

-- Notification system: 'qb' for QBCore.Notify, 'ox' for ox_lib notifications
Config.Notification = 'qb'

-- Stash types
Config.StashTypes = {
    ['private'] = 'Private Stash',
    ['public'] = 'Public Stash',
    ['job'] = 'Job Stash',
    ['shared'] = 'Shared Stash'
}

-- Available jobs for job stashes
Config.Jobs = {
    'police',
    'ambulance',
    'mechanic',
    'taxi',
    'realestate',
    'cardealer',
    'lawyer',
    'gang',
    'ballas',
    'families',
    'vagos',
    'lostmc'
}

-- Target options
Config.UseTarget = true -- Set to false to use zone-based interaction
Config.TargetResource = 'ox_target' -- ox_target or qb-target

-- Stash blip settings
Config.ShowBlips = false -- Global toggle (can be overridden per stash)
Config.BlipScale = 0.7
Config.BlipShortRange = true -- Whether blips only show when nearby

-- Blip settings per stash type
Config.BlipSettings = {
    ['private'] = {
        sprite = 478, -- Box icon
        color = 1, -- Red
        label = 'Private Stash'
    },
    ['public'] = {
        sprite = 478, -- Box icon
        color = 2, -- Green
        label = 'Public Stash'
    },
    ['job'] = {
        sprite = 478, -- Box icon
        color = 3, -- Blue
        label = 'Job Stash'
    },
    ['shared'] = {
        sprite = 478, -- Box icon
        color = 5, -- Yellow
        label = 'Shared Stash'
    }
}

-- Interaction distance
Config.InteractionDistance = 2.0

-- Object positioning presets
Config.PositionPresets = {
    ['none'] = {x = 0.0, y = 0.0, z = 0.0},
    ['front'] = {x = 0.0, y = 1.0, z = 0.0},
    ['back'] = {x = 0.0, y = -1.0, z = 0.0},
    ['left'] = {x = -1.0, y = 0.0, z = 0.0},
    ['right'] = {x = 1.0, y = 0.0, z = 0.0},
    ['up'] = {x = 0.0, y = 0.0, z = 1.0},
    ['down'] = {x = 0.0, y = 0.0, z = -1.0},
}

-- Pre-configured stashes
Config.DefaultStashes = {
    {
        name = 'Police Evidence',
        type = 'job',
        job = 'police',
        coords = vector3(441.7, -996.9, 30.7),
        slots = 100,
        weight = 500000,
        ped = nil,
        object = 'prop_box_wood05a',
        objectOffset = {x = 0.0, y = 0.5, z = 0.0},
        objectHeading = 0.0
    },
    {
        name = 'Public Storage',
        type = 'public',
        coords = vector3(215.8, -809.7, 30.7),
        slots = 25,
        weight = 50000,
        ped = 's_m_m_ups_01',
        object = nil
    }
}
