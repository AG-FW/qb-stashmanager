
# 🗄️ QBCore Stash Manager

> A powerful, feature-rich stash storage system for QBCore framework with multi-inventory support

[![License: MIT](https://img.shields.io/badge/License-MIT-bluelds.io/badge/QBCore📝 Description

**QBCore Stash Manager** is an advanced storage system that revolutionizes how players interact with stashes on your FiveM roleplay server. With support for multiple inventory systems and an intuitive interface, this script provides seamless stash management for private, job-based, and public storage solutions.

### ✨ Key Features

- 🔐 **Multiple Stash Types** - Private, job-specific, and public stashes
- 🎨 **Interactive Placement** - Position peds and objects with live preview mode
- 🔄 **Multi-Inventory Support** - Works with ox_inventory, qb-inventory, qs-inventory, and ps-inventory
- 🎯 **Target Integration** - Compatible with ox_target and qb-target
- 📊 **MySQL Database** - Persistent storage with automatic schema management
- 🛠️ **Admin Menu** - Easy-to-use interface for stash creation and management
- 🎮 **In-Game Positioning** - Drag, rotate, and snap objects to ground with keyboard controls
- 📝 **Full Customization** - Configure slots, weight limits, and stash properties

---

## 🎮 Features in Detail

### Stash Types
- **Private Stashes** - Tied to specific player citizen IDs for personal storage
- **Job Stashes** - Restricted access based on player job (police, ambulance, etc.)
- **Public Stashes** - Open access for all players on the server

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

***

## 🚀 Installation

1. **Download** the latest release
2. **Extract** to your server's `resources` folder
3. **Import** `stashes.sql` into your database
4. **Add** to your `server.cfg`:
   ```cfg
   ensure qb-stashmanager
   ```
5. **Configure** settings in `config.lua`
6. **Restart** your server

***

## ⚙️ Configuration

Edit `config.lua` to customize:
- Default stash slots and weight limits
- Admin permission groups
- Target system preferences
- Blip display options
- Default stash locations

***

## 🎯 Usage

### Commands
- `/stashmanager` - Open the stash management menu (admin only)

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

*[SOON]*

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