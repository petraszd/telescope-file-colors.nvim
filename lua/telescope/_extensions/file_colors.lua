local tele_pickers = require("telescope.pickers")
local tele_conf = require("telescope.config").values
local tele_finders = require("telescope.finders")
local tele_make_entry = require("telescope.make_entry")

local file_colors_ns = vim.api.nvim_create_namespace("File_Colors_NS")

--- @class Color
--- @field line string
--- @field hex string
--- @field lnum number
--- @field col number
local Color = {}
Color.__index = Color

--- @param bufnr number
--- @param hex string
--- @param node TSNode
--- @return Color
function Color:new_using_node(bufnr, hex, node)
  local start_row, start_col, _, _ = node:range()
  return Color:new(bufnr, hex, start_row + 1, start_col + 1)
end

--- @param bufnr number
--- @param hex string
--- @param lnum integer
--- @param col integer
--- @return Color
function Color:new(bufnr, hex, lnum, col)
  local obj = setmetatable({
    line = vim.trim(
      vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
    ),
    hex = hex,
    lnum = lnum,
    col = col
  }, self)
  return obj
end

--- @param raw_color string
--- @return string
local function normalize_hex_color(raw_color)
  if #raw_color == 7 then
    return raw_color
  end

  if #raw_color == 4 then
    local r = string.sub(raw_color, 2, 2)
    local g = string.sub(raw_color, 3, 3)
    local b = string.sub(raw_color, 4, 4)
    return "#" .. r .. r .. g .. g .. b .. b
  end

  error("normalize_hex_color: I do not know how to deal with :" .. raw_color)
end

--- @param bufnr number
--- @param lang string
--- @return Color[]
local function _get_treesitter_colors(bufnr, lang)
  local ts_utils = require("nvim-treesitter.ts_utils")

  --- @type Color[]
  local result = {}

  local cursor_node = vim.treesitter.get_node({ bufnr = bufnr })
  if cursor_node == nil then
    return result
  end

  local root_node = ts_utils.get_root_for_node(cursor_node)
  local num_lines = vim.api.nvim_buf_line_count(bufnr)

  -- Nice thing about CSS (and it's extension languages) is that they have a color
  -- as data type. So it is very easy to query for it.
  local hex_query = vim.treesitter.query.parse(lang, "(color_value) @val")
  for _, match, _ in hex_query:iter_matches(root_node, bufnr, 0, num_lines + 1) do
    local node = match[1]
    local hex = vim.treesitter.get_node_text(node, bufnr)
    table.insert(result, Color:new_using_node(bufnr, normalize_hex_color(hex), node))
  end

  -- There is also a rgba, rgb functions
  local rgba_query = vim.treesitter.query.parse(lang, [[
    (call_expression
      (function_name) @name
      (arguments
        (integer_value) @r
        (integer_value) @g
        (integer_value) @b
        (float_value)))
  ]])
  for _, match, _ in rgba_query:iter_matches(root_node, bufnr, 0, num_lines + 1) do
    local node = match[1]
    local func_name = vim.treesitter.get_node_text(node, bufnr)
    if func_name:lower() == "rgba" then
      local r = tonumber(vim.treesitter.get_node_text(match[2], bufnr))
      local g = tonumber(vim.treesitter.get_node_text(match[3], bufnr))
      local b = tonumber(vim.treesitter.get_node_text(match[4], bufnr))
      if r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 then
        local hex = string.format("#%02x%02x%02x", r, g, b)
        table.insert(result, Color:new_using_node(bufnr, hex, node))
      end
    end
  end

  -- Duplicated code. I do not feel that now it is the right time to abstract it.
  local rgb_query = vim.treesitter.query.parse(lang, [[
    (call_expression
      (function_name) @name
      (arguments
        (integer_value) @r
        (integer_value) @g
        (integer_value) @b))
  ]])
  for _, match, _ in rgb_query:iter_matches(root_node, bufnr, 0, num_lines + 1) do
    local node = match[1]
    local func_name = vim.treesitter.get_node_text(node, bufnr)
    if func_name:lower() == "rgb" then
      local r = tonumber(vim.treesitter.get_node_text(match[2], bufnr))
      local g = tonumber(vim.treesitter.get_node_text(match[3], bufnr))
      local b = tonumber(vim.treesitter.get_node_text(match[4], bufnr))
      if r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 then
        local hex = string.format("#%02x%02x%02x", r, g, b)
        table.insert(result, Color:new_using_node(bufnr, hex, node))
      end
    end
  end

  -- I am ignoring color constants (like white, black, etc, etc)

  return result
end

--- @param bufnr number
--- @return Color[]
local function _get_bruteforce_colors(bufnr)
  --- @type Color[]
  local result = {}

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  local ints_pattern = "()(%d+)%s*,%s*(%d+)%s*,%s*(%d+)"
  local hex3_pattern = "()(#%x%x%x)[%X$]"
  local hex6_pattern = "()(#%x%x%x%x%x%x)[%X$]"

  for lnum, line in ipairs(lines) do
    for pos, c1, c2, c3 in string.gmatch(line, ints_pattern) do
      local r = tonumber(c1)
      local g = tonumber(c2)
      local b = tonumber(c3)
      if r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 then
        local hex = string.format("#%02x%02x%02x", r, g, b)
        local col = tonumber(pos) or 0
        table.insert(result, Color:new(bufnr, hex, lnum, col))
      end
    end

    for pos, hex in string.gmatch(line, hex3_pattern) do
      local col = tonumber(pos) or 0
      table.insert(result, Color:new(bufnr, normalize_hex_color(hex), lnum, col))
    end

    for pos, hex in string.gmatch(line, hex6_pattern) do
      local col = tonumber(pos) or 0
      table.insert(result, Color:new(bufnr, normalize_hex_color(hex), lnum, col))
    end
  end

  return result
end

--- @param bufnr number
--- @return Color[]
local function get_colors(bufnr)
  local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
  local lang = vim.treesitter.language.get_lang(ft)
  local has_parser, _ = pcall(vim.treesitter.get_parser, bufnr, lang)
  if has_parser and (lang == "scss" or lang == "css") then
    return _get_treesitter_colors(bufnr, lang)
  else
    return _get_bruteforce_colors(bufnr)
  end
end

local function file_colors()
  local bufnr = 0
  local opts = {}

  local bufname = vim.api.nvim_buf_get_name(bufnr)

  local colors = get_colors(bufnr)

  local n = 0
  local hex_to_hl = {}
  for _, c in ipairs(colors) do
    if hex_to_hl[c.hex] == nil then
      n = n + 1
      local hl = "File_Colors_HL_" .. n
      hex_to_hl[c.hex] = hl
      vim.api.nvim_set_hl(file_colors_ns, hl, { fg = c.hex, bg = c.hex })
    end
  end

  local picker = tele_pickers.new(opts, {
    prompt_title = "Find Colors",
    preview_title = "Preview",
    finder = tele_finders.new_table {
      results = colors,
      --- @param color Color
      entry_maker = function(color)
        return tele_make_entry.set_default_entry_mt({
          value = color.line,
          ordinal = color.line,
          display = function(entry)
            local hl = hex_to_hl[color.hex]
            return "XXXXXX " .. entry.ordinal, { { { 0, 6 }, hl } }
          end,
          filename = bufname,
          lnum = color.lnum,
          start = color.lnum,
          col = color.col,
        }, opts)
      end
    },
    previewer = tele_conf.grep_previewer(opts),
    sorter = tele_conf.generic_sorter(opts),
    push_cursor_on_edit = true,
    push_tagstack_on_edit = true,
  })
  picker:find()

  if picker.results_win ~= nil then
    local results_win = picker.results_win
    local results_bufnr = picker.results_bufnr

    vim.api.nvim_win_set_hl_ns(results_win, file_colors_ns)
    vim.api.nvim_buf_attach(results_bufnr, false, {
      on_detach = function()
        vim.api.nvim_buf_clear_namespace(results_bufnr, file_colors_ns, 0, -1)
      end,
    })
  end
end

return require("telescope").register_extension({
  exports = {
    file_colors = file_colors
  },
})
