-- Pull in the wezterm API
local wezterm = require 'wezterm'
local mux = wezterm.mux

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
        key = 'LeftArrow',
        mods = 'OPT',
        action = wezterm.action.ActivatePaneDirection 'Left',
    },
    {
        key = 'RightArrow',
        mods = 'OPT',
        action = wezterm.action.ActivatePaneDirection 'Right',
    },
    {
        key = 'UpArrow',
        mods = 'OPT',
        action = wezterm.action.ActivatePaneDirection 'Up',
    },
    {
        key = 'DownArrow',
        mods = 'OPT',
        action = wezterm.action.ActivatePaneDirection 'Down',
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

-- Create workspaces on gui start
wezterm.on('gui-startup', function(cmd)
    -- allow `wezterm start -- something` to affect what we spawn
    -- in our initial window
    local args = {}
    if cmd then
        args = cmd.args
    end

    -- Setup a workspace for work
    -- Open a tab in the work directory for now, maybe later open things I know I need
    -- Top pane is for the editor, bottom pane is for the build tool
    local project_dir = wezterm.home_dir .. '/work/hashicorp'
    mux.spawn_window {
        workspace = 'work',
        cwd = project_dir,
        args = args,
    }

    -- Setup a workspace for configuration changes (dotfiles, etc)
    -- runs some docker containners for home automation
    local chezmoi_dir = wezterm.home_dir .. '/.local/share/chezmoi'
    mux.spawn_window {
        workspace = 'config',
        cwd = chezmoi_dir,
    }

    -- Setup a workspace for blogging
    mux.spawn_window {
        workspace = 'blog',
        cwd = wezterm.home_dir .. '/fun/danielmschmidt.de',
    }

    -- We want to startup in the coding workspace
    mux.set_active_workspace 'work'
end)

-- and finally, return the configuration to wezterm
return config
