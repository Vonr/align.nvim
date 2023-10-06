# align.nvim

### align.nvim is a minimal plugin for NeoVim for aligning lines

align.nvim supports aligning lines to the most feasible leftward or rightmost character, string, or Vim regex.

### Installation

Packer
```lua
use {
    'Vonr/align.nvim',
    branch = "v2",
}
```

Lazy
```lua
{
    'Vonr/align.nvim',
    branch = "v2",
    lazy = true,
    init = function()
        -- Create your mappings here
    end
}
```

### Usage

Bind the functions to your preferred bindings and use them in the operator and visual modes.

This plugin does not and will not provide any default mappings or commands for the foreseeable future.

Preview mode is opt-in, but no longer pollutes the undotree as it did in v1, making it recommended.

Suggested mappings:

```lua
local NS = { noremap = true, silent = true }

-- Aligns to 1 character
vim.keymap.set(
    'x',
    'aa',
    function()
        require'align'.align_to_char({
            length = 1,
        })
    end,
    NS
)

-- Aligns to 2 characters with previews
vim.keymap.set(
    'x',
    'ad',
    function()
        require'align'.align_to_char({
            preview = true,
            length = 2,
        })
    end,
    NS
)

-- Aligns to a string with previews
vim.keymap.set(
    'x',
    'aw',
    function()
        require'align'.align_to_string({
            preview = true,
            regex = false,
        })
    end,
    NS
)

-- Aligns to a Vim regex with previews
vim.keymap.set(
    'x',
    'ar',
    function()
        require'align'.align_to_string({
            preview = true,
            regex = true,
        })
    end,
    NS
)

-- Example gawip to align a paragraph to a string with previews
vim.keymap.set(
    'n',
    'gaw',
    function()
        local a = require'align'
        a.operator(
            a.align_to_string,
            {
                regex = false,
                preview = true,
            }
        )
    end,
    NS
)

-- Example gaaip to align a paragraph to 1 character
vim.keymap.set(
    'n',
    'gaa',
    function()
        local a = require'align'
        a.operator(a.align_to_char)
    end,
    NS
)
```

### Types

Types are provided in the source through [LuaCATS](https://luals.github.io/wiki/annotations/).

```lua
---@class Marks
---@field sr number
---@field sc number
---@field er number
---@field ec number

---@class AlignOptions
---@field reverse boolean?
---@field preview boolean?
---@field regex boolean?
---@field marks Marks?
---@field callback (fun(): any)?

---@class AlignToCharOptions: AlignOptions
---@field length integer?

---@class AlignWrapperOptions: AlignOptions
---@field pattern string?

---@class AlignInnerOptions: AlignOptions
---@field pattern string?


---@param pattern string
---@param opts AlignOptions?
function align(pattern, opts)

---@param opts AlignToCharOptions?
function align_to_char(opts)

---@param opts AlignOptions?
function align_to_string(opts)

---@param fn function
---@param opts (AlignOptions | AlignWrapperOptions | AlignToCharOptions)?
function operator(fn, opts)
```

![Usage GIF](https://user-images.githubusercontent.com/24369412/194233191-c0b36092-9f33-4f6f-8181-548e2a3d0b9c.gif)
The above GIF shows outdated mappings, refer to the section on recommended mappings instead
