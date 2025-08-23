-- ============================================================================
-- SIMPLE TWO-PANE CONFIG WITH TOP EXPLORER
-- ============================================================================
-- Using built-in netrw instead of neo-tree for guaranteed horizontal layout

-- ============================================================================
-- BASIC SETTINGS
-- ============================================================================
vim.o.autoread = true
vim.o.updatetime = 100
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.scrolloff = 8
vim.o.wrap = false

-- Auto-reload files
vim.api.nvim_create_autocmd({"CursorHold", "CursorHoldI", "FocusGained", "BufEnter"}, {
  pattern = "*",
  command = "silent! checktime",
})

-- ============================================================================
-- NETRW CONFIGURATION (Built-in File Explorer)
-- ============================================================================
vim.g.netrw_banner = 0        -- Hide banner
vim.g.netrw_liststyle = 3     -- Tree view
vim.g.netrw_browse_split = 0  -- Open in same window
vim.g.netrw_winsize = 20      -- 20% of screen
vim.g.netrw_altv = 1          -- Open splits to the right

-- ============================================================================
-- PLUGIN SETUP (Minimal)
-- ============================================================================
local Plug = vim.fn['plug#']
vim.call('plug#begin', '~/.local/share/nvim/plugged')

-- Git integration
Plug 'tpope/vim-fugitive'
Plug 'lewis6991/gitsigns.nvim'

-- Status line
Plug 'nvim-lualine/lualine.nvim'

-- Color scheme
Plug 'folke/tokyonight.nvim'

vim.call('plug#end')

-- Color scheme
vim.defer_fn(function()
  pcall(vim.cmd, 'colorscheme tokyonight-night')
end, 50)

-- ============================================================================
-- CUSTOM TOP EXPLORER FUNCTION
-- ============================================================================
vim.g.explorer_buf = nil
vim.g.mapleader = " "

-- Create horizontal split with explorer on top
function OpenTopExplorer()
  -- Save current buffer
  local current_buf = vim.api.nvim_get_current_buf()
  
  -- Create new buffer for explorer
  vim.cmd('enew')
  local explorer_buf = vim.api.nvim_get_current_buf()
  vim.g.explorer_buf = explorer_buf
  
  -- Split horizontally
  vim.cmd('split')
  
  -- Top window: Set up as file list
  vim.cmd('wincmd k')
  vim.cmd('resize 12')
  
  -- Use simple directory listing
  vim.api.nvim_buf_set_option(explorer_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(explorer_buf, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(explorer_buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(explorer_buf, 'modifiable', true)
  
  RefreshExplorer()
  
  -- Bottom window: Restore original buffer
  vim.cmd('wincmd j')
  vim.api.nvim_set_current_buf(current_buf)
end

-- Refresh file list in explorer
function RefreshExplorer()
  if not vim.g.explorer_buf or not vim.api.nvim_buf_is_valid(vim.g.explorer_buf) then
    return
  end
  
  -- Get file list with git status
  local files = {}
  local handle = vim.loop.fs_scandir('.')
  
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      
      -- Skip hidden files and .git
      if not name:match('^%.') then
        local prefix = type == 'directory' and '[>] ' or '    '
        
        -- Check git status
        local git_status = vim.fn.system('git status --porcelain ' .. vim.fn.shellescape(name))
        if git_status ~= '' then
          if git_status:match('^M') or git_status:match('^.M') then
            prefix = '[M] '  -- Modified
          elseif git_status:match('^??') then
            prefix = '[?] '  -- Untracked
          elseif git_status:match('^A') then
            prefix = '[+] '  -- Added
          end
        end
        
        table.insert(files, prefix .. name)
      end
    end
  end
  
  -- Update buffer
  vim.api.nvim_buf_set_option(vim.g.explorer_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(vim.g.explorer_buf, 0, -1, false, files)
  vim.api.nvim_buf_set_option(vim.g.explorer_buf, 'modifiable', false)
end

-- Open file from explorer
function OpenFileFromExplorer()
  local line = vim.api.nvim_get_current_line()
  local filename = line:gsub('^%[.%] ', ''):gsub('^    ', '')
  
  if filename ~= '' then
    -- Check if it's a directory
    local stat = vim.loop.fs_stat(filename)
    if stat and stat.type == 'directory' then
      vim.cmd('cd ' .. filename)
      RefreshExplorer()
    else
      -- Open file in bottom window
      vim.cmd('wincmd j')
      vim.cmd('edit ' .. filename)
    end
  end
end

-- ============================================================================
-- SMART DIFF VIEW
-- ============================================================================
vim.g.current_view_mode = "file"

function ShowDiffView()
  local file = vim.fn.expand('%')
  if file == '' then return end
  
  local diff_output = vim.fn.system('git diff ' .. vim.fn.shellescape(file))
  if diff_output ~= '' then
    vim.cmd('enew')
    vim.cmd('setlocal buftype=nofile bufhidden=wipe noswapfile')
    vim.cmd('setlocal filetype=diff')
    vim.cmd('setlocal number')
    
    local lines = {"=== DIFF: " .. file .. " ===", ""}
    for line in diff_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.cmd('setlocal readonly nomodifiable')
    vim.g.current_view_mode = "diff"
    vim.g.diff_file = file
  end
end

function ShowFileView()
  if vim.g.diff_file then
    vim.cmd('edit ' .. vim.fn.fnameescape(vim.g.diff_file))
    vim.g.current_view_mode = "file"
  end
end

-- ============================================================================
-- KEY MAPPINGS
-- ============================================================================
-- In explorer buffer: Enter opens file
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if vim.api.nvim_get_current_buf() == vim.g.explorer_buf then
      vim.keymap.set('n', '<CR>', OpenFileFromExplorer, { buffer = true, silent = true })
      vim.keymap.set('n', 'R', RefreshExplorer, { buffer = true, silent = true })
    end
  end
})

-- Navigation
vim.keymap.set('n', '<C-k>', function()
  -- Go to top window (explorer)
  vim.cmd('wincmd k')
end, { silent = true, desc = "Go to explorer (TOP)" })

vim.keymap.set('n', '<C-j>', function()
  -- Go to bottom window (editor)
  vim.cmd('wincmd j')
end, { silent = true, desc = "Go to editor (BOTTOM)" })

-- Toggle explorer
vim.keymap.set('n', '<leader>e', function()
  if vim.g.explorer_buf and vim.api.nvim_buf_is_valid(vim.g.explorer_buf) then
    -- Find and close explorer window
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == vim.g.explorer_buf then
        vim.api.nvim_win_close(win, true)
        vim.g.explorer_buf = nil
        return
      end
    end
  end
  
  -- Open explorer
  local current_buf = vim.api.nvim_get_current_buf()
  vim.cmd('split')
  vim.cmd('wincmd k')
  vim.cmd('resize 12')
  
  if vim.g.explorer_buf and vim.api.nvim_buf_is_valid(vim.g.explorer_buf) then
    vim.api.nvim_set_current_buf(vim.g.explorer_buf)
  else
    vim.cmd('enew')
    vim.g.explorer_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_option(vim.g.explorer_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(vim.g.explorer_buf, 'bufhidden', 'hide')
  end
  
  RefreshExplorer()
  vim.cmd('wincmd j')
end, { silent = true, desc = "Toggle explorer" })

-- Diff toggle
vim.keymap.set('n', '<leader>v', function()
  if vim.g.current_view_mode == "diff" then
    ShowFileView()
  else
    ShowDiffView()
  end
end, { desc = "Toggle file/diff view" })

-- Line wrap
vim.keymap.set('n', '<leader>W', function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify(vim.wo.wrap and "Wrap: ON" or "Wrap: OFF")
end, { desc = "Toggle wrap" })

-- ============================================================================
-- GITSIGNS
-- ============================================================================
vim.defer_fn(function()
  pcall(require, 'gitsigns').setup({
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '-' },
    },
  })
end, 200)

-- ============================================================================
-- STATUS LINE
-- ============================================================================
vim.defer_fn(function()
  pcall(require, 'lualine').setup({
    options = { theme = 'tokyonight' },
  })
end, 300)

-- ============================================================================
-- STARTUP
-- ============================================================================
vim.defer_fn(function()
  OpenTopExplorer()
  print("TOP: Explorer (12 lines) | BOTTOM: Editor | Ctrl+k/j: Navigate | Space+e: Toggle | Space+v: Diff")
end, 100)