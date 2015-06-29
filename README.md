# TF2
Repository for all our TF2 servers.

The goal here is to go 100% open source, and allow contributions from the community. To allow new programmers, sysadmins, etc to gain some real world experience in a safe environment. :)

# Overview of server config yaml layout.
```
sourcemod:
    # URL to grab SourceMod from, this allows us to change version or use a custom build.
    url: http://www.sourcemod.net/smdrop/1.8/sourcemod-1.8.0-git5483-linux.tar.gz
    # Only these files/folders will be copied from the sourcemod download into our server build
    include:
        - addons/sourcemod/bin
        - addons/sourcemod/extensions
        - addons/sourcemod/gamedata
        - addons/sourcemod/translations
    # List of plugins to install, minus file extension (eg basechat but NOT basechat.smx)
    # Plugins will be searched for in...
    # Default sourcemod plugins, eg sourcemod/plugins/
    # Disabled default sourcemod plugins, eg sourcemod/plugins/disabled
    # .sp and folders in sourcemod_plugins.
    plugins:
        - admin-sql-prefetch
        - sql-admin-manager
        - adminhelp
        - adminmenu
        - antiflood
        - basebans
        - basechat
        - basecomm
        - basecommands
        - basetriggers
        - basevotes
        - clientprefs
        - funcommands
        - funvotes
        - nextmap
        - playercommands
        - reservedslots
        - sounds
    # List of SourceMod config files
    # These are config files that will reside in /addons/sourcemod/configs
    # and NOT for configs that will reside in /cfg/
    # Config files will be searched for in sourcemod_configs first
    # then in sourcemod/configs if nothing exists.
    # The syntax is source, destination. This allows us to have
    # One config file shared between one or more servers.
    configs: [
        ['geoip', 'geoip'],
        ['admin_groups.cfg', 'admin_groups.cfg'],
        ['admin_levels.cfg', 'admin_levels.cfg'],
        ['adminmenu_cfgs.txt', 'adminmenu_cfgs.txt'],
        ['adminmenu_custom.txt', 'adminmenu_custom.txt'],
        ['adminmenu_grouping.txt', 'adminmenu_grouping.txt'],
        ['adminmenu_sorting.cfg', 'adminmenu_sorting.cfg'],
        ['admin_overrides.cfg', 'admin_overrides.cfg'],
        ['admins.cfg', 'admins.cfg'],
        ['banreasons.txt', 'banreasons.txt'],
        ['core.cfg', 'core.cfg'],
        ['databases.cfg', 'databases.cfg'],
        ['languages.cfg', 'languages.cfg'],
        ['maplists.cfg', 'maplists.cfg'],
    ]
    # List of SourceMod extensions
    # These will be searched for in the sourcemod_extensions directory
    # Note that all default SourceMod extensions are installed by default.
    extensions:
        - socket

metamod:
    # URL to grab MetaMod from, this allows us to change version or use a custom build.
    url: http://www.metamodsource.net/mmsdrop/1.11/mmsource-1.11.0-git985-linux.tar.gz
    # Only these files/folders will be copied from the metamod download into our server build
    include:
        - addons/

# List of config files
# These are config files that will reside in /cfg/
# and NOT for configs that will reside in /addons/sourcemod/configs/
# Config files will be searched for in the cfg folder
# The syntax is source, destination. This allows us to have
# One config file shared between one or more servers.
configs: [
    ['sourcemod/afk_manager.cfg', 'sourcemod/afk_manager.cfg'],
    ['sourcemod/sourcemod.cfg', 'sourcemod/sourcemod.cfg']
]

```

# Adding a new plugin
#### If the plugin is a single SP file
- Place the .sp file into the sourcemod_plugins directory
- Add the plugin file name (minus the .sp) to the servers yaml file in the sourcemod > plugins section

#### If the plugin is a collection of files
- Put the folder in sourcemod_plugins/addon_name/, so for example sourcemod_plugins/SourceIRC/scripting/sourceirc.sp
- Add the plugin folder name to the servers yaml file in sourcemod > plugins section

#### If the plugin has cvar config files (files that go in /cfg)
- Add the file to the cfg folder
- Add the file to the configs section (not the sourcemod > configs section)

#### If the plugin has sourcemod config files (files that go in sourcemod/configs)
- Add the file to the sourcemod_configs folder
- Add the file to the sourcemod > configs section (not the top-level configs section)
