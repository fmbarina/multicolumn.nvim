# multicolumn.nvim

A Neovim plugin to (hopefully) satisfy all your colorcolumn needs.

|![c-full-to-end](https://github.com/fmbarina/multicolumn.nvim/assets/70731450/67928475-c863-4697-9bbe-bc4d157e0400)|![lua-file-full](https://github.com/fmbarina/multicolumn.nvim/assets/70731450/e57709c8-6b09-4287-8e9a-33aea1f91452)|
|-|-|
|![py-to-end-win](https://github.com/fmbarina/multicolumn.nvim/assets/70731450/99ff8362-3cc5-4c10-b8bb-b7e2225e49ae)|![git-mixed-set](https://github.com/fmbarina/multicolumn.nvim/assets/70731450/50e97396-9c3d-4129-9579-ca17c7d39792)|

## Features

- ⚙️ Highly configurable Colorcolumn
  - 🎯 Show focused colorcolumn at desired position(s)
  - ➡️ Highlight excess characters
  - 🧰 Specify working scope
  - 🌈 Define your own color values
  - 😐 Enable always-on, when you want boring functionality
  - ⚡ Use a callback for dynamic settings
  - ...all configurable per filetype
- 🔌 Toggle On/Off the entire plugin and remember state through sessions.
- ⏰️ Refresh colorcolumn when you move, lazily or on timed intervals.
- 🎈 Ignore floating windows - no manually excluding lazy, mason, etc.
- 📄 Exclude specific filetypes

## Installation

- Install `fmbarina/multicolumn.nvim`
- Ensure `require('multicolumn').setup(opts)` is called.

Using lazy.nvim:

```lua
{
  'fmbarina/multicolumn.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {},
}
```

## Configuration

The settings table (`opts`) may define the following fields.

| Setting              | Type                                          | Description                                                                                                    |
|----------------------|-----------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| **start**            | `string`: `enabled`, `disabled` or `remember` | Plugin start behavior opening neovim. When `remember`, the plugin will persist state through neovim sessions.  |
| **update**           | `string` (`on_move` or `lazy_hold`) or `int`  | Defines when the colorcolumn is updated, defaults to `on_move`. See explanation for options below.             |
| **command**          | `string` `multiple`, `single` or `none`       | Controls how many commands are created for the plugin.                                                         |
| **max_lines**        | `int`                                         | Maximum lines allowed for `file` scope line scanning. When `0`, there is no limit.                             |
| **max_size**         | `int`                                         | Maximum file size (in bytes) allowed for any scope. When `0`, there is no limit.                               |
| **use_default_set**  | `bool`                                        | Whether to use the `default` set when no `filetype` set is found, defaults to true.                            |
| **exclude_floating** | `bool`                                        | Whether the plugin should be disabled in floating windows, such as mason.nvim and lazy.nvim.                   |
| **exclude_ft**       | `string[]`                                    | List of filetypes (strings) the plugin should be disabled under.                                               |
| **editorconfig**     | `bool`                                        | Whether to use the max_line_length value from .editorconfig                                                    |
| **base_set**         | `table`: set, see below                       | Base set all other sets inherit from when options are missing.                                                 |
| **sets**             | `table[]`: set list, see below                | Defines plugin behavior for each defined `filetype` set. Accepts a `default` set for fallback behavior.        |

You can choose when to update the colorcolumn with the value of the `update` setting:

- `on_move`: update colorcolumn everytime the cursor moves or window scrolls.
- `lazy_hold`: update colorcolumn when you stop moving for a while. Slower feedback, lighter performance impact.
- If the value is an `int`, update colorcolumn in timed intervals spaced by this value in miliseconds.

### Sets

A `set` defines a _set of options_ governing colorcolumn behavior i.e. it's a table that tells multicolumn.nvim which features to use and how.

- When editing a file, multicolumn.nvim looks for a set with the same name as the `filetype` of the file.
- If a `filetype` set isn't found, it uses the `default` set (that's the actual name) defined in `sets`
- If a set is missing an option, it's inherited from the `base_set` (including the `default` set)
- Also, a set may be a `function(buf, win) -> set`, so you can hook into neovim to build dynamic sets.

These are the options that multicolumn.nvim looks for in a set:

| Option          | Type                                 | Description                                                                                         |
|-----------------|--------------------------------------|-----------------------------------------------------------------------------------------------------|
| **scope**       | `string`: `file`, `window` or `line` | Scope that the plugin will scan and generate colorcolumns for                                       |
| **rulers**      | `int[]`                              | List of integers defining the colorcolumn numbers. Remember: if the max line length is 80, use 81   |
| **to_line_end** | `bool`                               | Whether to highlight characters exceeding the colorcolumn to the end of the line                    |
| **full_column** | `bool`                               | Whether to draw a full colorcolumn (window ceiling to bottom) when the column number is hit         |
| **always_on**   | `bool`                               | Whether to always draw the full colorcolumns. When true, implies `full_column` is true as well      |
| **bg_color**    | `string`: hex code (e.g. "#c92aaf")  | Background highlight color of the colorcolumn as a hex code                                         |
| **fg_color**    | `string`: hex code (e.g. "#c92aaf")  | Foreground highlight color of the colorcolumn as a hex code                                         |

Note that some options are related and may override your configuration, but this *should* only happen in ways you'd expect (and hopefully want):

- `always_on` → `full_column` (because you can't have an always on focused column)
- `scope` is `file`, but `full_column` not true → `scope` is reduced to `window` (saving some cpu cycles)

### Default settings

`multicolumn.nvim` comes with the following defaults:

```lua
start = 'enabled', -- enabled, disabled, remember
update = 'on_move', -- on_move, lazy_hold, int
command = 'multiple', -- multiple, single, none
max_lines = 6000, -- 0 (disabled) OR int
max_size = 64 * 1024 * 1024, -- 0 (disabled) OR int
use_default_set = true,
exclude_floating = true,
exclude_ft = { 'markdown', 'help', 'netrw' },
editorconfig = false,
base_set = {
  scope = 'window', -- file, window, line
  rulers = {}, -- { int, int, ... }
  to_line_end = false,
  full_column = false,
  always_on = false,
  bg_color = nil,
  fg_color = nil,
},
sets = {
  default = {
    rulers = { 81 },
  },
},
```

### Example settings

```lua
sets = {
  lua = {
      scope = 'file',
      rulers = { 81 },
      full_column = true,
  },
  python = {
      scope = 'window',
      rulers = { 80 },
      to_line_end = true,
      bg_color = '#f08800',
      fg_color = '#17172e',
  },
  c = {
      scope = 'window',
      rulers = { 81 },
      to_line_end = true,
      always_on = true,
  },
  gitcommit = function(buf, win)
      local T = function(c, x, y) if c then return x else return y end
      return {
          scope = T(vim.fn.line('.', win) == 1, 'line', 'window'),
          rulers = { T(vim.fn.line('.', win) == 1, 51, 73) },
          to_line_end = true,
          bg_color = '#691b1b',
          fg_color = '#ffd8ad',
      }
  end,
},
```

## Acknowledgements

This plugin draws great inpiration from [NeoColumn.nvim](https://github.com/ecthelionvi/NeoColumn.nvim "Thank you, Robert!") and [smartcolumn.nvim](https://github.com/m4xshen/smartcolumn.nvim "Thank you, Max!"). They were used as references and even some terms were borrowed from them, but more than that, they were what pushed me to create this plugin. Multicolumn wouldn't exist without them, so, thank you!
