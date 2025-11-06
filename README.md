
# 🗄️ QBCore Stash Manager

> A powerful, feature-rich stash storage system for QBCore framework with multi-inventory support

[![License: MIT](https://img.shields.io/badge/License-MIT-bluelds.io/badge/QBCore📝 Description

**QBCore Stash Manager** is an advanced storage system that revolutionizes how players interact with stashes on your FiveM roleplay server. With support for multiple inventory systems and an intuitive interface, this script provides seamless stash management for private, job-based, and public storage solutions.

### ✨ Key Features

- 🔐 **Multiple Stash Types** - Private, job-specific, public, and shared stashes
- 🤝 **Shared Access Control** - Create collaborative stashes, manage members, and rename on the fly
- 🎨 **Interactive Placement** - Position peds and objects with live preview mode
- 🔄 **Multi-Inventory Support** - Works with ox_inventory, qb-inventory, qs-inventory, and ps-inventory
- 🎯 **Target Integration** - Compatible with ox_target and qb-target
- 📊 **MySQL Database** - Persistent storage with automatic schema management
- 🛠️ **Admin Menu** - Easy-to-use interface for stash creation and management
- 🎮 **In-Game Positioning** - Drag, rotate, and snap objects to ground with keyboard controls
- 📝 **Full Customization** - Configure slots, weight limits, and stash properties
- 🔔 **Flexible Notifications** - Toggle between QBCore or ox_lib notify systems
- 📍 **Advanced Blip System** - Custom blips per stash type, per-stash blip customization, access-based visibility
- 🔍 **Search & Filter** - Search by name, filter by type, and sort stashes in the manage menu
- 📋 **Access Logging** - Track who accessed stashes and when, with item addition/removal tracking
- 👮 **Admin Controls** - Admins can open any stash directly from the manage menu

---

## 🎮 Features in Detail

### Stash Types
- **Private Stashes** - Tied to specific player citizen IDs for personal storage
- **Job Stashes** - Restricted access based on player job (police, ambulance, etc.)
- **Public Stashes** - Open access for all players on the server
- **Shared Stashes** - Admin-created stashes with managed member lists and rename tools

### Interactive Placement System
- Live preview mode for ped and object positioning
- Keyboard controls for precise placement:
  - Arrow keys for movement
  - Q/E + Scroll wheel for rotation
  - PageUp/PageDown for height adjustment
  - G key for instant ground snapping
  - Shift for fine-tuning
- Real-time 3D coordinate display

### Management Tools
- Comprehensive admin menu (`/stashmanager`)
- Edit stash properties on-the-fly
- Reposition peds and objects after creation
- Change models without losing stash data
- Teleport to stash locations
- Player-facing shared stash manager (`/sharedstash`) with member invites, removals, and rename tools
- **Search & Filter** - Search stashes by name, filter by type (private, public, job, shared), and sort by creation date, name, or type
- **Admin Access** - Admins can open any stash directly from the manage menu, bypassing access restrictions

### Access Logging & Security
- **Audit Trail** - Complete logging of all stash access events
- **Item Tracking** - Log item additions and removals with timestamps
- **Admin Viewable** - Access detailed logs by stash, by player, or view recent activity
- **Player Activity** - Track which players accessed which stashes and when

### Blip Customization
- **Type-Based Blips** - Configure different blip sprites, colors, and labels per stash type (private, public, job, shared)
- **Per-Stash Blips** - Override default type settings with custom blip configurations for individual stashes
- **In-Game Configuration** - Use FiveM's blip manager to select sprites, colors, and labels directly in-game
- **Access-Based Visibility** - Smart blip display:
  - **Public stashes** - Visible to everyone
  - **Job stashes** - Only visible to players with that job
  - **Private stashes** - Only visible to the owner
  - **Shared stashes** - Only visible to members with access
- **Toggle Per Stash** - Enable or disable blip visibility for each individual stash

***

## 📦 Requirements

- [QBCore Framework](https://github.com/qbcore-framework)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- **One of the following inventory systems:**
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [qb-inventory](https://github.com/qbcore-framework/qb-inventory)
- [qs-inventory](https://github.com/quasar-store/qs-inventory)
- [ps-inventory](https://github.com/Project-Sloth/ps-inventory)
- [Notification](`Config.Notification = 'qb'` or `'ox'`)
***

## 🚀 Installation

1. **Download** the latest release
2. **Extract** to your server's `resources` folder
3. **Import** `stashes.sql` into your database
4. **Add** to your `server.cfg`:
   ```cfg
   ensure qb-stashmanager
   ```
5. dependencies {
    'qb-core',
    'oxmysql',
    -- ONE of the following:
    'ox_inventory'
    -- 'qb-inventory'
    -- 'qs-inventory'
    -- 'ps-inventory'
}
6. **Configure** settings in `config.lua`
7. **Restart** your server

***

## ⚙️ Configuration

Edit `config.lua` to customize:
- Default stash slots and weight limits
- Admin permission groups
- Target system preferences
- Blip display options
- Notification provider (`Config.Notification = 'qb'` or `'ox'`)
- Default stash locations

**Note:** Blip settings can be configured both in `config.lua` and in-game via the admin menu for more flexibility.

***

## 🎯 Usage

### Commands
- `/stashmanager` - Open the stash management menu (admin only)
- `/sharedstash` - Manage shared stash members, rename, and open stashes (first manager only)

### Controls (During Placement)
- **Arrow Keys** - Move object/ped horizontally
- **PageUp/PageDown** - Adjust height
- **Q/E** - Rotate left/right
- **Mouse Scroll** - Fine rotation adjustment
- **G** - Snap to ground
- **Shift** - Fine-tuning mode
- **Enter** - Confirm placement
- **Backspace** - Cancel

***

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

***

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

***

## 🙏 Credits

**Developer:** AG Framework  
**Support:** https://discord.gg/UCaztzGeNz

***

## 📸 Preview

*[https://www.youtube.com/@AG-Framework]*

***

This enhanced description includes:
- Professional badges and formatting
- Clear feature breakdown
- Detailed usage instructions
- Visual hierarchy with emojis and sections
- Complete installation guide
- Contributing guidelines
- Credits section

You can copy this directly to your GitHub repository's README.md file!
