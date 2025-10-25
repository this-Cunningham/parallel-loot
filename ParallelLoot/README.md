# ParallelLoot - WoW Addon

A World of Warcraft addon for Mists of Pandaria Classic that enables parallel loot rolling during raids.

## Version
1.0.0

## Installation

1. Copy the `ParallelLoot` folder to your WoW addons directory:
   - Windows: `World of Warcraft\_retail_\Interface\AddOns\`
   - Mac: `World of Warcraft/_retail_/Interface/AddOns/`

2. Restart WoW or reload UI with `/reload`

## Usage

- `/ploot` or `/parallelloot` - Toggle main UI (when implemented)
- `/ploot debug` - Toggle debug mode
- `/ploot version` - Show addon version
- `/ploot help` - Show help message

## Features

- Persistent loot sessions throughout raids
- Parallel rolling on multiple items
- Categorized priority levels (BIS, MS, OS, COZ)
- Automatic roll range management
- Class-based item filtering
- Loot master controls

## Directory Structure

```
ParallelLoot/
├── ParallelLoot.toc          # Addon manifest
├── Core/                     # Core functionality
│   ├── Init.lua             # Main initialization
│   ├── DataManager.lua      # Data persistence
│   ├── LootManager.lua      # Loot management
│   ├── RollManager.lua      # Roll management
│   ├── CommManager.lua      # Communication
│   └── UIManager.lua        # UI management
└── UI/                       # User interface
    ├── MainFrame.xml        # UI definitions
    └── MainFrame.lua        # UI logic
```

## Data Persistence

The addon uses SavedVariables to persist data across sessions:
- Settings and preferences
- Current loot session
- Session history (last 10 sessions)

Data is stored in `WTF/Account/[Account]/SavedVariables/ParallelLoot.lua`

## Development Status

This is the initial framework. Core features will be implemented in subsequent tasks.
