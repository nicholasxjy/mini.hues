-- Run from the repository root: nvim --headless -u NONE -l tests/highlights.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local hues = require('mini.hues')
local hl = function(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end
local hex = function(color) return tonumber(color:sub(2), 16) end
local minimum = { text = math.huge, syntax = math.huge }
local count = 0

local function luminance(color)
  local result = 0
  for i, weight in ipairs({ 0.2126, 0.7152, 0.0722 }) do
    local channel = math.floor(color / 256 ^ (3 - i)) % 256 / 255
    result = result + weight * (channel <= 0.04045 and channel / 12.92 or ((channel + 0.055) / 1.055) ^ 2.4)
  end
  return result
end

local function contrast(fg, bg)
  local a, b = luminance(fg), luminance(bg)
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

local function check(p)
  count = count + 1
  local roles = {
    Normal = 'fg', Identifier = 'fg', Function = 'azure', Type = 'cyan', String = 'green',
    Character = 'green', Constant = 'orange', Number = 'orange', Boolean = 'orange',
    Keyword = 'purple', Statement = 'pink', Operator = 'cyan', Comment = 'fg_mid',
    ['@variable.parameter'] = 'yellow', ['@variable.member'] = 'teal', ['@variable.builtin'] = 'red',
    ['@keyword.conditional'] = 'pink', ['@keyword.function'] = 'pink', ['@keyword.return'] = 'purple',
    ['@lsp.type.parameter'] = 'yellow', ['@lsp.type.property'] = 'teal', ['@lsp.type.function'] = 'azure',
    ['@lsp.typemod.variable.defaultLibrary'] = 'red', ['@lsp.type.decorator'] = 'cyan',
    ['@markup.heading'] = 'accent', ['@markup.heading.1'] = 'pink',
    RainbowDelimiterCyan = 'cyan', BlinkPairsCyan = 'cyan', BlinkIndentCyan = 'cyan',
    CmpItemKindField = 'teal', BlinkCmpKindField = 'teal', BlinkCmpKindEnumMember = 'orange',
    GitSignsChange = 'blue', NeoTreeGitModified = 'blue', NvimTreeGitDirty = 'blue',
  }
  for group, color in pairs(roles) do
    assert(hl(group).fg == hex(p[color]), group .. ' must use palette.' .. color)
    minimum.syntax = math.min(minimum.syntax, contrast(hl(group).fg, hex(p.bg)))
  end
  for _, group in ipairs({ '@lsp.type.variable', '@lsp.mod.defaultLibrary' }) do
    assert(hl(group).fg == nil, group .. ' must preserve underlying syntax colors')
  end
  for level = 1, 6 do
    assert(vim.deep_equal(hl('RenderMarkdownH' .. level), hl('@markup.heading.' .. level)))
    assert(vim.deep_equal(hl('markdownH' .. level), hl('@markup.heading.' .. level)))
  end
  for _, group in ipairs({ 'Normal', 'Comment', 'Delimiter', 'NormalFloat', 'Visual', 'Search',
    'Pmenu', 'PmenuSel', 'StatusLine', 'DiffText', 'BlinkCmpLabelDetail', 'BlinkCmpLabelDescription' }) do
    local data = hl(group)
    local ratio = contrast(data.fg or hex(p.fg), data.bg or hex(p.bg))
    minimum.text = math.min(minimum.text, ratio)
    assert(ratio >= 4.5, string.format('%s: contrast %.2f < 4.5', group, ratio))
  end
  assert(contrast(hl('Comment').fg, hl('CursorLine').bg) >= 4.5, 'comments must remain readable on the cursor line')
  assert(contrast(hl('CmpItemMenu').fg, hl('Pmenu').bg) >= 4.5, 'completion details must remain readable')
  -- Plugin labels and matches can override the selected row's foreground.
  for _, group in ipairs({ 'BlinkCmpLabel', 'BlinkCmpLabelMatch', 'CmpItemAbbr', 'CmpItemAbbrMatch' }) do
    assert(contrast(hl(group).fg, hl('PmenuSel').bg) >= 4.5, group .. ' disappears on selected rows')
  end
  assert(hl('DiagnosticUnderlineError').undercurl)
  assert(hl('DiagnosticDeprecated').strikethrough)
  assert(hl('PmenuSel').reverse == nil)
  assert(vim.deep_equal(hl('BlinkCmpMenuSelection'), hl('PmenuSel')))
  assert(vim.deep_equal(hl('GitSignsChangeInline'), hl('DiffText')))
end

for _, background in ipairs({ 'dark', 'light' }) do
  vim.o.background = background
  for _, scheme in ipairs({ 'miniwinter', 'minispring', 'minisummer', 'miniautumn' }) do
    vim.cmd.colorscheme(scheme)
    check(hues.get_palette())
  end
  for _, saturation in ipairs({ 'low', 'lowmedium', 'medium', 'mediumhigh', 'high' }) do
    for n_hues = 0, 12 do
      local config = hues.gen_random_base_colors({ gen_hue = function() return 225 end })
      config.saturation, config.n_hues = saturation, n_hues
      hues.setup(config)
      check(hues.get_palette())
    end
  end
end

local p = hues.get_palette()
local original = vim.deepcopy(p)
for _, dim_popup in ipairs({ false, true }) do
  hues.apply_palette(p, nil, { dim_popup = dim_popup })
  local expected = hex(dim_popup and p.bg_edge or p.bg)
  for _, group in ipairs({ 'NormalFloat', 'FloatBorder', 'FloatTitle', 'DiagnosticFloatingError', 'BlinkCmpDoc',
    'SnacksPickerPreview', 'SnacksPickerPreviewBorder', 'SnacksPickerTitle', 'FzfLuaPreviewNormal', 'WhichKeyFloat' }) do
    assert(hl(group).bg == expected, group .. ' must respect dim_popup')
  end
  if vim.fn.exists('+pumborder') == 1 then
    for _, border in ipairs({ 'none', 'single' }) do
      vim.o.pumborder = border
      vim.api.nvim_exec_autocmds('VimEnter', {})
      assert(hl('Pmenu').bg == (border == 'none' and hex(p.bg_mid) or expected))
    end
  end
end
assert(vim.deep_equal(p, original), 'apply_palette must not mutate its input')
assert(vim.deep_equal(hues.get_palette(), original), 'stored palette must retain original colors')

vim.cmd('highlight clear')
hues.apply_palette(p, { default = false, ['ibhagwan/fzf-lua'] = true }, { autoadjust = false })
assert(hl('FzfLuaDirPart').fg == hex(p.fg_mid), 'fzf directory text must work without Snacks')
assert(hl('FzfLuaFzfMatch').fg == hex(p.accent), 'fzf matches must work without Snacks')
assert(hl('Pmenu').bg == hex(p.bg_mid), 'autoadjust=false must keep the unbordered menu style')
print(string.format('Passed %d palettes; minimum text contrast %.2f:1; original syntax colors %.2f:1',
  count, minimum.text, minimum.syntax))
