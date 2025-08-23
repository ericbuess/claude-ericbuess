-- ============================================================================
-- CLEAN TWO-PANE NEOVIM CONFIG FOR WATCHING CLAUDE CODE
-- ============================================================================
-- Layout: Top explorer (20%), Bottom smart view (80% - shows file OR diff)

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
vim.o.foldmethod = "manual"
vim.o.foldlevel = 99
vim.o.foldenable = false

-- Auto-reload files changed externally
vim.api.nvim_create_autocmd({"CursorHold", "CursorHoldI", "FocusGained", "BufEnter"}, {
  pattern = "*",
  command = "silent! checktime",
})

-- ============================================================================
-- PLUGIN MANAGER SETUP
-- ============================================================================
local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.local/share/nvim/plugged')

-- File explorer
Plug('nvim-neo-tree/neo-tree.nvim', { branch = 'v3.x' })
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'MunifTanjim/nui.nvim'

-- Git integration
Plug 'tpope/vim-fugitive'
Plug 'lewis6991/gitsigns.nvim'

-- Syntax highlighting
Plug('nvim-treesitter/nvim-treesitter', { ['do'] = ':TSUpdate' })

-- Status line
Plug 'nvim-lualine/lualine.nvim'

-- Color scheme
Plug 'folke/tokyonight.nvim'

vim.call('plug#end')

-- ============================================================================
-- APPEARANCE
-- ============================================================================
vim.defer_fn(function()
  pcall(vim.cmd, 'colorscheme tokyonight-night')
end, 50)

-- ============================================================================
-- SMART VIEW FUNCTIONALITY (File OR Diff, not both)
-- ============================================================================
vim.g.mapleader = " "
vim.g.current_view_mode = "file"  -- "file" or "diff"

-- Function to check if file has git changes
local function file_has_changes()
  local file = vim.fn.expand('%:p')
  if file == '' then return false end
  
  local ok, result = pcall(function()
    local git_dir = vim.fn.system('git rev-parse --git-dir 2>/dev/null')
    if vim.v.shell_error ~= 0 then
      return false
    end
    
    local git_status = vim.fn.system('git status --porcelain ' .. vim.fn.shellescape(file))
    return git_status ~= ''
  end)
  
  return ok and result or false
end

-- Show unified diff with line numbers in current buffer
local function show_diff_view()
  local file = vim.fn.expand('%')
  if file == '' or vim.bo.filetype == 'neo-tree' then return end
  
  local ok, err = pcall(function()
    -- Get better formatted diff with line numbers
    local diff_cmd = 'git diff --no-ext-diff --no-color --no-prefix -U5 ' .. vim.fn.shellescape(file)
    local diff_output = vim.fn.system(diff_cmd)
    
    if diff_output ~= '' and vim.v.shell_error == 0 then
      -- Switch buffer to diff view
      vim.cmd('enew')
      vim.cmd('setlocal buftype=nofile bufhidden=wipe noswapfile')
      vim.cmd('setlocal filetype=diff')
      vim.cmd('setlocal number')  -- Show line numbers
      vim.cmd('setlocal cursorline')  -- Highlight current line
      
      -- Format the diff output with better headers
      local header = {
        "╔══════════════════════════════════════════════════════════════╗",
        "║ DIFF VIEW: " .. file,
        "║ [Space+v] Return to file  |  [Space+W] Toggle wrap",
        "╚══════════════════════════════════════════════════════════════╝",
        "",
      }
      
      -- Parse and format the diff
      local lines = {}
      for _, line in ipairs(header) do
        table.insert(lines, line)
      end
      
      -- Add the diff content with better formatting
      for line in diff_output:gmatch("[^\r\n]+") do
        if line:match("^@@") then
          -- Format hunk headers
          local formatted = "───────────────────────────────────────"
          table.insert(lines, formatted)
          table.insert(lines, line)
          table.insert(lines, formatted)
        else
          table.insert(lines, line)
        end
      end
      
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.cmd('setlocal readonly nomodifiable')
      vim.g.current_view_mode = "diff"
      vim.g.diff_file = file
    end
  end)
  
  if not ok then
    vim.notify("Error showing diff: " .. tostring(err), vim.log.levels.ERROR)
  end
end

-- Show normal file view
local function show_file_view()
  if vim.g.diff_file then
    pcall(function()
      vim.cmd('edit ' .. vim.fn.fnameescape(vim.g.diff_file))
      vim.g.current_view_mode = "file"
      vim.g.diff_file = nil
    end)
  end
end

-- Smart view switcher (only for editor window)
local function smart_view_switch()
  -- Don't switch if we're in neo-tree or a special buffer
  if vim.bo.filetype == 'neo-tree' or vim.bo.buftype ~= '' then
    return
  end
  
  if file_has_changes() then
    if vim.g.current_view_mode ~= "diff" then
      show_diff_view()
    end
  else
    if vim.g.current_view_mode ~= "file" then
      show_file_view()
    end
  end
end

-- DISABLED: Auto-switching causes unexpected diff views
-- Only switch views manually with Space+v

-- Clean up timer on exit (if we add any timers later)
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    -- Cleanup code here if needed
  end
})

-- ============================================================================
-- NEO-TREE CONFIGURATION (NO AUTO-OPEN)
-- ============================================================================
vim.g.explorer_opened = false  -- Track if explorer is opened

vim.defer_fn(function()
  local ok, neotree = pcall(require, 'neo-tree')
  if ok then
    neotree.setup({
      close_if_last_window = false,
      enable_git_status = true,
      
      window = {
        position = "current",  -- We'll control the window placement manually
        mappings = {
          ["<cr>"] = function(state)
            -- Custom open that ensures file opens in bottom window
            local node = state.tree:get_node()
            if node.type == "file" then
              -- Always move to the bottom window (editor)
              vim.cmd('wincmd j')
              -- If we're still in neo-tree, create a new window below
              if vim.bo.filetype == 'neo-tree' then
                vim.cmd('below new')
              end
              -- Open the file
              vim.cmd('edit ' .. node.path)
              -- Reset to file mode when opening a new file
              vim.g.current_view_mode = "file"
            else
              require('neo-tree.sources.filesystem.commands').toggle_node(state)
            end
          end,
          ["<space>"] = "none",
          ["h"] = "close_node",
          ["l"] = "open",
          ["R"] = "refresh",
        }
      },
      
      filesystem = {
        follow_current_file = {
          enabled = false,  -- Don't auto-follow (causes window issues)
        },
        use_libuv_file_watcher = true,
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = { "node_modules", ".git" },
        },
      },
      
      -- ASCII icons
      default_component_configs = {
        icon = {
          folder_closed = "[>]",
          folder_open = "[v]",
          folder_empty = "[ ]",
          default = "",
        },
        git_status = {
          symbols = {
            added     = "[+]",
            modified  = "[M]",
            deleted   = "[D]",
            renamed   = "[R]",
            untracked = "[?]",
            ignored   = "[I]",
            unstaged  = "[U]",
            staged    = "[S]",
            conflict  = "[!]",
          }
        },
      },
    })
  end
end, 100)

-- Function to create the two-pane layout (global for keymap access)
function setup_layout()
  -- Check if neo-tree already exists
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
    if ft == 'neo-tree' then
      vim.g.explorer_opened = true
      return  -- Already have explorer, don't create another
    end
  end
  
  pcall(function()
    -- FORCE HORIZONTAL SPLIT LAYOUT
    vim.cmd('only')           -- Start with single window
    vim.cmd('split')          -- Create HORIZONTAL split (not vsplit!)
    vim.cmd('wincmd k')       -- Move to TOP window
    vim.cmd('resize 10')      -- Set height to 10 lines
    
    -- Open neo-tree in the current (top) window
    vim.cmd('Neotree filesystem show current')
    
    -- Move cursor to bottom window (editor)
    vim.cmd('wincmd j')
    
    vim.g.explorer_opened = true
  end)
end

-- Set up layout after plugins load
vim.defer_fn(setup_layout, 500)

-- ============================================================================
-- KEY MAPPINGS
-- ============================================================================
-- CLEAR NAVIGATION: Jump between explorer (top) and editor (bottom)
vim.keymap.set('n', '<C-k>', function()
  -- Go UP to explorer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
    if ft == 'neo-tree' then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.cmd('wincmd k')  -- Fallback
end, { silent = true, desc = "Jump to EXPLORER (top)" })

vim.keymap.set('n', '<C-j>', function()
  -- Go DOWN to editor
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
    if ft ~= 'neo-tree' then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.cmd('wincmd j')  -- Fallback
end, { silent = true, desc = "Jump to EDITOR (bottom)" })

-- Alternative shortcuts
vim.keymap.set('n', '<leader>e', '<C-k>', { remap = true, desc = "Focus explorer" })
vim.keymap.set('n', '<leader>f', '<C-j>', { remap = true, desc = "Focus editor/file" })

-- Toggle explorer visibility
vim.keymap.set('n', '<leader>n', function()
  local found_neotree = false
  
  -- Check if neo-tree window exists
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
    if ft == 'neo-tree' then
      found_neotree = true
      -- Close the neo-tree window
      vim.api.nvim_win_close(win, true)
      vim.g.explorer_opened = false
      break
    end
  end
  
  -- If no neo-tree, recreate the horizontal layout
  if not found_neotree then
    -- Save current buffer
    local current_buf = vim.api.nvim_get_current_buf()
    
    -- Create horizontal split layout
    vim.cmd('split')          -- HORIZONTAL split
    vim.cmd('wincmd k')       -- Move to TOP
    vim.cmd('resize 10')      -- 10 lines height
    vim.cmd('Neotree filesystem show current')
    vim.cmd('wincmd j')       -- Back to bottom
    
    -- Restore the buffer
    vim.api.nvim_set_current_buf(current_buf)
    
    vim.g.explorer_opened = true
  end
end, { silent = true, desc = "Toggle explorer" })

-- MANUAL TOGGLE: Switch between file and diff view (Space+v)
vim.keymap.set('n', '<leader>v', function()
  -- Ensure we're not in neo-tree
  if vim.bo.filetype == 'neo-tree' then
    -- First jump to editor
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
      if ft ~= 'neo-tree' then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
  end
  
  -- Now toggle the view
  if vim.g.current_view_mode == "diff" then
    show_file_view()
    vim.notify("📄 FILE view", vim.log.levels.INFO)
  else
    if file_has_changes() then
      show_diff_view()
      vim.notify("🔍 DIFF view", vim.log.levels.INFO)
    else
      vim.notify("No changes to diff", vim.log.levels.INFO)
    end
  end
end, { desc = "Toggle file/diff view (manual)" })

-- Line wrap toggle
vim.keymap.set('n', '<leader>W', function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify(vim.wo.wrap and "Wrap: ON" or "Wrap: OFF", vim.log.levels.INFO)
end, { desc = "Toggle line wrap" })

vim.keymap.set('n', '<F3>', ':set wrap!<CR>', { silent = true, desc = "Toggle line wrap" })

-- Git commands
vim.keymap.set('n', '<leader>gs', ':Git status<CR>', { desc = "Git status" })
vim.keymap.set('n', '<leader>gb', ':Git blame<CR>', { desc = "Git blame" })
vim.keymap.set('n', '<leader>gl', ':Git log<CR>', { desc = "Git log" })

-- Basic commands
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = "Save" })
vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = "Quit" })
vim.keymap.set('n', '<F5>', ':checktime<CR>:Neotree action=refresh<CR>', { desc = "Refresh all" })

-- ============================================================================
-- GITSIGNS (for gutter indicators)
-- ============================================================================
vim.defer_fn(function()
  local ok, gitsigns = pcall(require, 'gitsigns')
  if ok then
    gitsigns.setup({
      signs = {
        add          = { text = '+' },
        change       = { text = '~' },
        delete       = { text = '-' },
        topdelete    = { text = '‾' },
        changedelete = { text = '~' },
      },
      watch_gitdir = {
        interval = 2000,
        follow_files = true,
      },
      update_debounce = 100,
    })
  end
end, 200)

-- ============================================================================
-- STATUS LINE
-- ============================================================================
vim.defer_fn(function()
  local ok, lualine = pcall(require, 'lualine')
  if ok then
    lualine.setup({
      options = {
        theme = 'tokyonight',
        component_separators = { left = '|', right = '|' },
      },
      sections = {
        lualine_a = {function() 
          return vim.g.current_view_mode == "diff" and "DIFF" or "FILE" 
        end},
        lualine_b = {'branch'},
        lualine_c = {'filename'},
        lualine_x = {'filetype'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
      },
    })
  end
end, 300)

-- ============================================================================
-- STARTUP MESSAGE
-- ============================================================================
vim.defer_fn(function()
  -- Debug: Check window layout
  local wins = vim.api.nvim_list_wins()
  local layout_info = "Windows: " .. #wins .. " | "
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
    layout_info = layout_info .. ft .. " "
  end
  
  print("Horizontal Layout: Explorer TOP, Editor BOTTOM | Ctrl+k/j: Navigate | " .. layout_info)
end, 700)