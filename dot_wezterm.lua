-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- Color scheme:
config.color_scheme = 'synthwave-everything'

-- Enable the scrollbar
config.enable_scroll_bar = true
config.window_padding = {
    left = 2,
    right = 2,
    top = 0,
    bottom = 0,
}
config.font_size = 15.0

-- General options
config.window_close_confirmation = 'AlwaysPrompt'
config.window_decorations = "RESIZE"

-- Keybindings
config.keys = {
    -- Next tab
    {
        key = 'RightArrow',
        mods = 'CMD',
        action = wezterm.action.ActivateTabRelative(1),
    },
    {
        key = 'LeftArrow',
        mods = 'CMD',
        action = wezterm.action.ActivateTabRelative(-1),
    },
    {
        key = 'd',
        mods = 'CMD',
        action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },
    {
        key = 'D',
        mods = 'CMD',
        action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },
    {
        key = 'w',
        mods = 'CMD',
        action = wezterm.action.CloseCurrentPane { confirm = false },
    },
    {
        key = 'W',
        mods = 'CMD',
        action = wezterm.action.CloseCurrentTab { confirm = true },
    },
    { key = 'l', mods = 'ALT',  action = wezterm.action.ShowLauncher },
    { key = 'w', mods = 'CTRL', action = wezterm.action.SwitchWorkspaceRelative(1) },
    {
        key = 'k',
        mods = 'CMD',
        action = wezterm.action.Multiple {
            wezterm.action.ClearScrollback 'ScrollbackAndViewport',
            wezterm.action.SendKey { key = 'L', mods = 'CTRL' },
        },
    },
}

-- and finally, return the configuration to wezterm
return config
