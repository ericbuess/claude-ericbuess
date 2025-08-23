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
  if file == '' then return end
  
  -- Save cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  
  -- Get the diff output with line numbers
  local diff_cmd = 'git diff --no-ext-diff --no-color -U5 ' .. vim.fn.shellescape(file) .. 
                   ' | cat -n | sed "s/^\\s*\\([0-9]\\+\\)\\s/\\1: /"'
  local diff_output = vim.fn.system(diff_cmd)
  
  if diff_output ~= '' then
    -- Switch buffer to diff view
    vim.cmd('enew')
    vim.cmd('setlocal buftype=nofile bufhidden=wipe noswapfile')
    vim.cmd('setlocal filetype=diff')
    vim.cmd('setlocal number')  -- Show line numbers
    
    -- Add header
    local header = {
      "=== DIFF VIEW: " .. file .. " ===",
      "=== Press Space+v to return to file view ===",
      "",
    }
    
    local lines = vim.split(diff_output, '\n')
    for i = 1, #header do
      table.insert(lines, i, header[i])
    end
    
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.cmd('setlocal readonly nomodifiable')
    vim.g.current_view_mode = "diff"
    vim.g.diff_file = file
  end
end

-- Show normal file view
local function show_file_view()
  if vim.g.diff_file then
    vim.cmd('edit ' .. vim.fn.fnameescape(vim.g.diff_file))
    vim.g.current_view_mode = "file"
    vim.g.diff_file = nil
  end
end

-- Smart view switcher
local function smart_view_switch()
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

-- Auto-switch on file open and changes
vim.api.nvim_create_autocmd({"BufReadPost", "BufWritePost"}, {
  callback = function()
    -- Skip if in neo-tree
    if vim.bo.filetype == 'neo-tree' then return end
    
    vim.defer_fn(function()
      smart_view_switch()
    end, 100)
  end
})

-- Check for external changes periodically
local check_timer = vim.loop.new_timer()
check_timer:start(2000, 2000, vim.schedule_wrap(function()
  if vim.g.current_view_mode and vim.bo.filetype ~= 'neo-tree' then
    smart_view_switch()
  end
end))

-- ============================================================================
-- NEO-TREE CONFIGURATION (TOP HORIZONTAL)
-- ============================================================================
vim.defer_fn(function()
  local ok, neotree = pcall(require, 'neo-tree')
  if ok then
    neotree.setup({
      close_if_last_window = false,
      enable_git_status = true,
      
      window = {
        position = "top",
        height = 10,  -- Fixed height for explorer
        mappings = {
          ["<cr>"] = "open",
          ["<space>"] = "none",
          ["h"] = "close_node",
          ["l"] = "open",
          ["R"] = "refresh",
        }
      },
      
      filesystem = {
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
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
      
      event_handlers = {
        {
          event = "file_opened",
          handler = function(file_path)
            -- Focus on the file buffer after opening
            vim.defer_fn(function()
              -- Find and focus the non-neo-tree window
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                local buf = vim.api.nvim_win_get_buf(win)
                local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
                if ft ~= 'neo-tree' then
                  vim.api.nvim_set_current_win(win)
                  break
                end
              end
            end, 10)
          end
        },
      },
    })
    
    -- Auto-open neo-tree at the top
    vim.cmd("Neotree top show")
  end
end, 100)

-- ============================================================================
-- KEY MAPPINGS
-- ============================================================================
-- Neo-tree navigation
vim.keymap.set('n', '<leader>e', ':Neotree top focus<CR>', { silent = true, desc = "Focus explorer" })
vim.keymap.set('n', '<leader>n', ':Neotree top toggle<CR>', { silent = true, desc = "Toggle explorer" })

-- Navigate between top explorer and bottom editor
vim.keymap.set('n', '<C-k>', function()
  -- Go to top window (explorer)
  vim.cmd('wincmd k')
end, { desc = "Go to explorer" })

vim.keymap.set('n', '<C-j>', function()
  -- Go to bottom window (editor)
  vim.cmd('wincmd j')
end, { desc = "Go to editor" })

-- Toggle between file and diff view manually
vim.keymap.set('n', '<leader>v', function()
  if vim.g.current_view_mode == "diff" then
    show_file_view()
    vim.notify("File view", vim.log.levels.INFO)
  else
    if file_has_changes() then
      show_diff_view()
      vim.notify("Diff view", vim.log.levels.INFO)
    else
      vim.notify("No changes to diff", vim.log.levels.INFO)
    end
  end
end, { desc = "Toggle file/diff view" })

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
  print("Two-pane mode | Top: Explorer (Ctrl+k) | Bottom: Smart view (Ctrl+j) | Space+v: Toggle view | Space+W: Wrap")
end, 500)