# align.nvim

### align.nvim is a minimal plugin for NeoVim for aligning lines

align.nvim supports aligning lines to the rightmost character, string, or Lua pattern.

Escapes for Lua patterns can either be % or \\, the latter both of which can be escaped again with another \\.

### Installation

Packer
```lua
use 'Vonr/align.nvim'
```

### Usage

Bind the functions to your preferred bindings and use them in Visual or Visual Lines mode.

Example:

```lua
local NS = { noremap = true, silent = true }
vim.keymap.set('v', 'aa', function() require'align'.align_to_char()       end, NS) -- Align to character
vim.keymap.set('v', 'aw', function() require'align'.align_to_string()     end, NS) -- Align to word
vim.keymap.set('v', 'ar', function() require'align'.align_to_string(true) end, NS) -- Align to pattern
```
