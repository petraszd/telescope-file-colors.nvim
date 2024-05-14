# telescope-file-colors.nvim

A [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) extension to see/find colors in the current
buffer.

## Demo

![telescope-file-colors](https://github.com/petraszd/telescope-file-colors.nvim/assets/1826042/4eecfc90-19ac-4286-82e1-34f4d03d2b2a)

## Install / Setup

```lua
require("lazy").setup({
  {
    "petraszd/telescope-file-colors.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  }
})

require("telescope").load_extension("file_colors")
```

## Optional config

```lua
require("telescope").setup {
  ...
  extensions = {
    file_colors = {
      -- Turns on treesitter querying (instead of bruteforce pattern matching)
      -- for scss and css files.
      use_treesitter = true,
    }
  },
}
```

## Usage

```
:Telescope file_colors
```
