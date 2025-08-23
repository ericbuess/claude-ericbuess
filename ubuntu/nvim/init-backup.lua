-- ============================================================================
-- LIVE-UPDATING NEOVIM CONFIG FOR WATCHING CLAUDE CODE
-- ============================================================================
-- This config is optimized for real-time file watching and auto-updating
-- as Claude Code makes changes in another tmux pane

-- ============================================================================
-- CRITICAL: AUTO-RELOAD SETTINGS (MUST BE FIRST!)
-- ============================================================================
vim.o.autoread = true                    -- Auto-read files changed externally
vim.o.updatetime = 100                   -- Check for changes every 100ms
vim.o.swapfile = false                   -- Disable swap files (interferes with watching)
vim.o.backup = false                     -- No backup files
vim.o.writebackup = false                -- No write backup

-- Force check for file changes on various events
vim.api.nvim_create_autocmd({"CursorHold", "CursorHoldI", "FocusGained", "BufEnter", "WinEnter"}, {
  pattern = "*",
  command = "silent! checktime",
})

-- Tmux focus event support (CRITICAL for live updates)
vim.cmd([[
  if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\e[5 q\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\e[2 q\<Esc>\\"
    set ttimeoutlen=0
  endif
]])

-- Global timer for aggressive file checking (every 500ms)
local timer = vim.loop.new_timer()
timer:start(500, 500, vim.schedule_wrap(function()
  vim.cmd("silent! checktime")
end))


-- ============================================================================
-- PLUGIN MANAGER SETUP
-- ============================================================================
local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.local/share/nvim/plugged')

-- File explorer with git integration
Plug('nvim-neo-tree/neo-tree.nvim', { branch = 'v3.x' })
Plug 'nvim-lua/plenary.nvim'           -- Required dependency
Plug 'nvim-tree/nvim-web-devicons'     -- File icons (will use text fallback)
Plug 'MunifTanjim/nui.nvim'            -- UI components for neo-tree

-- Git integration
Plug 'tpope/vim-fugitive'              -- Git commands
Plug 'lewis6991/gitsigns.nvim'         -- Git signs in gutter + live diff

-- Better syntax highlighting
Plug('nvim-treesitter/nvim-treesitter', { ['do'] = ':TSUpdate' })

-- Fuzzy finder for quick file navigation
Plug 'nvim-telescope/telescope.nvim'

-- Auto-pairs for brackets
Plug 'windwp/nvim-autopairs'

-- Status line
Plug 'nvim-lualine/lualine.nvim'

-- Color scheme optimized for readability
Plug 'folke/tokyonight.nvim'

vim.call('plug#end')

-- ============================================================================
-- APPEARANCE
-- ============================================================================
-- Try to set colorscheme, fall back to default if not installed
vim.defer_fn(function()
  local ok = pcall(vim.cmd, 'colorscheme tokyonight-night')
  if not ok then
    vim.cmd('colorscheme default')
  end
end, 50)

vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.scrolloff = 8
vim.o.wrap = false

-- Prevent diff folding issues
vim.o.foldmethod = "manual"
vim.o.foldlevel = 99
vim.o.foldenable = false
vim.o.diffopt = "internal,filler,closeoff,hiddenoff,algorithm:patience"

-- ============================================================================
-- NEO-TREE CONFIGURATION (WITH LIVE UPDATES)
-- ============================================================================
vim.cmd([[
  highlight NeoTreeGitModified guifg=#ff9900 gui=bold
  highlight NeoTreeGitAdded guifg=#00ff00 gui=bold
  highlight NeoTreeGitDeleted guifg=#ff0000 gui=bold
  highlight NeoTreeGitUntracked guifg=#808080
  highlight NeoTreeGitStaged guifg=#00ff00 gui=bold
  highlight NeoTreeGitUnstaged guifg=#ffaa00 gui=bold
]])

-- Schedule neo-tree setup after plugins load
vim.defer_fn(function()
  local ok, neotree = pcall(require, 'neo-tree')
  if ok then
    neotree.setup({
      close_if_last_window = false,
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = false,
      
      -- CRITICAL: Filesystem watcher for live updates
      filesystem = {
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        },
        use_libuv_file_watcher = true,  -- OS-level file watching
        scan_mode = "shallow",
        window = {
          position = "left",
          width = 30,
          mappings = {
            ["<space>"] = "none",
            ["<cr>"] = "open_with_window_picker",
            ["S"] = "split_with_window_picker",
            ["s"] = "vsplit_with_window_picker",
            ["t"] = "open_tabnew",
            ["C"] = "close_node",
            ["z"] = "close_all_nodes",
            ["R"] = "refresh",
            ["a"] = "add",
            ["d"] = "delete",
            ["r"] = "rename",
            ["y"] = "copy_to_clipboard",
            ["x"] = "cut_to_clipboard",
            ["p"] = "paste_from_clipboard",
          }
        },
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = {
            "node_modules",
            ".git",
          },
        },
      },
      
      -- Git status in tree (ASCII for better compatibility)
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
      
      -- File/folder icons (disable icons, use ASCII text only)
      default_component_configs = {
        icon = {
          folder_closed = "[>]",
          folder_open = "[v]",
          folder_empty = "[ ]",
          folder_empty_open = "[ ]",
          default = "",
          highlight = "NeoTreeDirectoryIcon",
          provider = function(icon, node)
            if node.type == "directory" then
              if node:is_expanded() then
                return "[v]", "NeoTreeDirectoryIcon"
              else
                return "[>]", "NeoTreeDirectoryIcon"
              end
            else
              return "", "NeoTreeFileIcon"
            end
          end,
        },
        modified = {
          symbol = "[M]",
          highlight = "NeoTreeGitModified",
        },
        name = {
          use_git_status_colors = true,
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
      
      -- Disable web devicons entirely
      use_default_mappings = true,
      use_libuv_file_watcher = true,
      renderers = {
        directory = {
          { "indent" },
          { "icon" },
          { "current_filter" },
          { "name" },
          { "clipboard" },
          { "diagnostics" },
          { "git_status" },
        },
        file = {
          { "indent" },
          { "name" },
          { "clipboard" },
          { "diagnostics" },
          { "git_status" },
        }
      },
      
      -- Refresh neo-tree on various events
      event_handlers = {
        {
          event = "file_opened",
          handler = function(file_path)
            -- Auto close neo-tree when opening file
            -- require("neo-tree").close_all()
          end
        },
        {
          event = "file_added",
          handler = function(file_path)
            vim.cmd("silent! checktime")
          end
        },
        {
          event = "file_deleted",
          handler = function(file_path)
            vim.cmd("silent! checktime")
          end
        },
        {
          event = "file_renamed",
          handler = function(args)
            vim.cmd("silent! checktime")
          end
        },
        {
          event = "file_moved",
          handler = function(args)
            vim.cmd("silent! checktime")
          end
        },
      },
    })
    
    -- Auto-open neo-tree on startup
    vim.cmd("Neotree show")
  end
end, 100)

-- Refresh neo-tree only on focus, not constantly
vim.api.nvim_create_autocmd("FocusGained", {
  callback = function()
    if vim.fn.exists(":Neotree") > 0 then
      vim.cmd("silent! Neotree action=refresh")
    end
  end
})

-- ============================================================================
-- GITSIGNS CONFIGURATION (LIVE GIT DIFF)
-- ============================================================================
vim.defer_fn(function()
  local ok, gitsigns = pcall(require, 'gitsigns')
  if ok then
    gitsigns.setup({
      signs = {
        add          = { text = '│' },
        change       = { text = '│' },
        delete       = { text = '_' },
        topdelete    = { text = '‾' },
        changedelete = { text = '~' },
        untracked    = { text = '┆' },
      },
      signcolumn = true,
      numhl      = false,
      linehl     = false,
      word_diff  = false,
      watch_gitdir = {
        interval = 100,      -- Check git dir every 100ms
        follow_files = true,
      },
      attach_to_untracked = true,
      current_line_blame = false,
      sign_priority = 6,
      update_debounce = 10,    -- Super fast updates
      status_formatter = nil,
      max_file_length = 40000,
      preview_config = {
        border = 'single',
        style = 'minimal',
        relative = 'cursor',
        row = 0,
        col = 1
      },
      yadm = {
        enable = false
      },
      on_attach = function(bufnr)
        -- Refresh gitsigns on any text change
        vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "BufWritePost"}, {
          buffer = bufnr,
          callback = function()
            vim.schedule(function()
              pcall(function() require('gitsigns').refresh() end)
            end)
          end
        })
      end,
    })
    
    -- Refresh gitsigns only on specific events, not constantly
    vim.api.nvim_create_autocmd({"BufWritePost", "FocusGained"}, {
      callback = function()
        vim.defer_fn(function()
          pcall(function() require('gitsigns').refresh() end)
        end, 100)
      end
    })
  end
end, 200)

-- ============================================================================
-- SMART BOTTOM DIFF VIEW FUNCTIONALITY
-- ============================================================================
-- Track diff window to avoid duplicates
vim.g.diff_win_id = vim.g.diff_win_id or nil
vim.g.auto_diff_enabled = false  -- START WITH DIFF DISABLED (toggle with Space+gd)

-- Cache for git status to prevent too many calls
local git_cache = {}
local cache_timeout = 2000  -- Cache for 2 seconds

-- Function to check if file has git changes (with caching)
function file_has_changes()
  local file = vim.fn.expand('%:p')
  if file == '' then return false end
  
  -- Check cache first
  local now = vim.loop.now()
  if git_cache[file] and (now - git_cache[file].time) < cache_timeout then
    return git_cache[file].has_changes
  end
  
  -- Check if in git repo (safe check)
  local ok, result = pcall(function()
    local git_dir = vim.fn.system('git rev-parse --git-dir 2>/dev/null')
    if vim.v.shell_error ~= 0 then
      return false
    end
    
    -- Check if file has changes
    local git_status = vim.fn.system('git status --porcelain ' .. vim.fn.shellescape(file))
    return git_status ~= ''
  end)
  
  -- Cache the result
  local has_changes = ok and result or false
  git_cache[file] = {
    time = now,
    has_changes = has_changes
  }
  
  return has_changes
end

-- Close existing diff window (global for keymaps)
function close_diff_window()
  if vim.g.diff_win_id and vim.api.nvim_win_is_valid(vim.g.diff_win_id) then
    vim.api.nvim_win_close(vim.g.diff_win_id, true)
    vim.g.diff_win_id = nil
  end
end

-- Open bottom diff window with proper sizing (global for keymaps)
function open_bottom_diff()
  local file = vim.fn.expand('%')
  if file == '' then return end
  
  -- Protect against errors
  local ok, err = pcall(function()
    -- Save current window
    local main_win = vim.api.nvim_get_current_win()
    
    -- Close any existing diff window
    close_diff_window()
    
    -- Create new bottom split for diff
    vim.cmd('botright new')
    vim.g.diff_win_id = vim.api.nvim_get_current_win()
    
    -- Set the buffer to show git diff
    vim.cmd('setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline')
    vim.cmd('setlocal filetype=diff')
    
    -- Get and display the diff (with timeout protection)
    local diff_output = vim.fn.system('timeout 2 git diff ' .. vim.fn.shellescape(file))
    if vim.v.shell_error == 0 then
      local lines = vim.split(diff_output, '\n')
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    else
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {"Error: Could not get git diff"})
    end
    
    -- Configure the diff window
    vim.cmd('setlocal readonly nomodifiable')
    vim.cmd('setlocal nonumber norelativenumber')
    vim.cmd('setlocal signcolumn=no')
    
    -- Resize: top window 30%, bottom diff 70%
    local total_height = vim.o.lines - 4  -- Account for statusline and cmdline
    local top_height = math.floor(total_height * 0.3)
    
    -- Go back to main window and resize
    vim.api.nvim_set_current_win(main_win)
    vim.cmd('resize ' .. top_height)
    
    -- Stay in the main editing window
    vim.api.nvim_set_current_win(main_win)
  end)
  
  if not ok then
    vim.notify("Error opening diff: " .. tostring(err), vim.log.levels.ERROR)
    close_diff_window()
  end
end

-- Smart auto-diff that updates on file switch (global for keymaps)
function smart_auto_diff()
  if not vim.g.auto_diff_enabled then
    close_diff_window()
    return
  end
  
  -- Skip if in neo-tree or special buffer
  local ft = vim.bo.filetype
  if ft == 'neo-tree' or ft == 'fugitive' or ft == 'git' then
    close_diff_window()
    return
  end
  
  if file_has_changes() then
    open_bottom_diff()
  else
    close_diff_window()
  end
end

-- SAFER: Auto-update with debouncing and error handling
local diff_timer = nil
local last_file = nil

vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
  callback = function()
    -- Cancel any pending diff update
    if diff_timer then
      vim.fn.timer_stop(diff_timer)
    end
    
    -- Debounce: wait 500ms before checking diff
    diff_timer = vim.fn.timer_start(500, function()
      local current_file = vim.fn.expand('%:p')
      -- Only update if file actually changed
      if current_file ~= last_file then
        last_file = current_file
        pcall(smart_auto_diff)  -- Protected call to prevent errors
      end
      diff_timer = nil
    end)
  end
})

-- Safer external change handler
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  callback = function()
    if vim.g.auto_diff_enabled then
      vim.defer_fn(function()
        pcall(open_bottom_diff)
      end, 500)
    end
  end
})

-- ============================================================================
-- KEY MAPPINGS
-- ============================================================================
vim.g.mapleader = " "

-- Neo-tree toggles
vim.keymap.set('n', '<leader>n', ':Neotree toggle<CR>', { silent = true, desc = "Toggle Neo-tree" })
vim.keymap.set('n', '<leader>e', ':Neotree focus<CR>', { silent = true, desc = "Focus Neo-tree" })
vim.keymap.set('n', '<C-n>', ':Neotree toggle<CR>', { silent = true, desc = "Toggle Neo-tree" })

-- Git diff controls with smart bottom view

-- Toggle auto-diff feature on/off
vim.keymap.set('n', '<leader>gd', function()
  vim.g.auto_diff_enabled = not vim.g.auto_diff_enabled
  if vim.g.auto_diff_enabled then
    vim.notify("Auto-diff: ENABLED", vim.log.levels.INFO)
    smart_auto_diff()  -- Trigger immediate check
  else
    vim.notify("Auto-diff: DISABLED", vim.log.levels.INFO)
    close_diff_window()
  end
end, { silent = true, desc = "Toggle auto-diff view" })

-- Manually refresh diff
vim.keymap.set('n', '<leader>gr', function()
  if file_has_changes() then
    open_bottom_diff()
  else
    vim.notify("No changes in this file", vim.log.levels.INFO)
  end
end, { silent = true, desc = "Refresh diff view" })

-- Alternative diff views (when you want them)
vim.keymap.set('n', '<leader>gD', function()
  -- Side-by-side split diff (traditional view)
  local file = vim.fn.expand('%:p')
  if file == '' then return end
  
  close_diff_window()  -- Close bottom diff first
  local git_status = vim.fn.system('git status --porcelain ' .. vim.fn.shellescape(file))
  if git_status ~= '' then
    vim.cmd('Gdiffsplit')
    vim.cmd('set foldlevel=99')
    vim.cmd('wincmd =')
  else
    vim.notify("No changes in this file", vim.log.levels.INFO)
  end
end, { silent = true, desc = "Git diff - side-by-side view" })

-- Full screen unified diff
vim.keymap.set('n', '<leader>gf', function()
  close_diff_window()  -- Close bottom diff first
  vim.cmd('Git diff %')
end, { silent = true, desc = "Git diff - full screen" })

-- INLINE PREVIEW (hover to see changes)
vim.keymap.set('n', '<leader>gp', ':Gitsigns preview_hunk<CR>', { silent = true, desc = "Preview git changes inline" })

-- Navigate between changes
vim.keymap.set('n', ']c', ':Gitsigns next_hunk<CR>', { silent = true, desc = "Next change" })
vim.keymap.set('n', '[c', ':Gitsigns prev_hunk<CR>', { silent = true, desc = "Previous change" })

-- Close diff window
vim.keymap.set('n', '<leader>gc', function()
  close_diff_window()
  vim.cmd('diffoff!')
end, { silent = true, desc = "Close any diff view" })

-- Other git commands
vim.keymap.set('n', '<leader>gs', ':Git status<CR>', { silent = true, desc = "Git status" })
vim.keymap.set('n', '<leader>gb', ':Git blame<CR>', { silent = true, desc = "Git blame" })
vim.keymap.set('n', '<leader>gl', ':Git log<CR>', { silent = true, desc = "Git log" })

-- Navigation between splits
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = "Navigate left" })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = "Navigate down" })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = "Navigate up" })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = "Navigate right" })

-- Refresh commands
vim.keymap.set('n', '<F5>', ':checktime<CR>:Neotree action=refresh<CR>:e!<CR>', { silent = true, desc = "Force refresh all" })
vim.keymap.set('n', '<leader>r', ':checktime<CR>', { silent = true, desc = "Check for file changes" })
vim.keymap.set('n', '<leader>R', ':bufdo e!<CR>', { silent = true, desc = "Reload all buffers" })

-- Telescope for fuzzy finding
vim.keymap.set('n', '<leader>ff', ':Telescope find_files<CR>', { desc = "Find files" })
vim.keymap.set('n', '<leader>fg', ':Telescope live_grep<CR>', { desc = "Live grep" })
vim.keymap.set('n', '<leader>fb', ':Telescope buffers<CR>', { desc = "Find buffers" })

-- Quick save and quit
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = "Save file" })
vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = "Quit" })

-- LINE WRAP TOGGLE (easy to remember: leader + wrap)
vim.keymap.set('n', '<leader>W', function()
  vim.wo.wrap = not vim.wo.wrap
  if vim.wo.wrap then
    vim.notify("Line wrap: ON", vim.log.levels.INFO)
  else
    vim.notify("Line wrap: OFF", vim.log.levels.INFO)
  end
end, { desc = "Toggle line wrap" })

-- Alternative wrap toggle with F3
vim.keymap.set('n', '<F3>', ':set wrap!<CR>', { silent = true, desc = "Toggle line wrap" })

-- Fold management (for diffs)
vim.keymap.set('n', 'zo', 'zo', { desc = "Open fold under cursor" })
vim.keymap.set('n', 'zc', 'zc', { desc = "Close fold under cursor" })
vim.keymap.set('n', 'zR', 'zR', { desc = "Open all folds" })
vim.keymap.set('n', 'zM', 'zM', { desc = "Close all folds" })

-- ============================================================================
-- STATUS LINE
-- ============================================================================
vim.defer_fn(function()
  local ok, lualine = pcall(require, 'lualine')
  if ok then
    lualine.setup({
      options = {
        theme = 'tokyonight',
        section_separators = { left = '', right = '' },
        component_separators = { left = '', right = '' },
      },
      sections = {
        lualine_a = {'mode'},
        lualine_b = {'branch', 'diff', 'diagnostics'},
        lualine_c = {
          {
            'filename',
            path = 1,  -- Show relative path
            symbols = {
              modified = ' ●',
              readonly = ' ',
              unnamed = '[No Name]',
            }
          }
        },
        lualine_x = {'encoding', 'fileformat', 'filetype'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
      },
    })
  end
end, 300)

-- ============================================================================
-- TREESITTER (Better syntax highlighting)
-- ============================================================================
vim.defer_fn(function()
  local ok, treesitter = pcall(require, 'nvim-treesitter.configs')
  if ok then
    treesitter.setup({
      ensure_installed = { "lua", "vim", "python", "javascript", "typescript", "bash", "json", "yaml", "markdown" },
      sync_install = false,
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
      indent = {
        enable = true,
      },
    })
  end
end, 400)

-- ============================================================================
-- AUTO-RELOAD NOTIFICATION
-- ============================================================================
-- Show a subtle notification when files are reloaded
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  callback = function()
    vim.notify("File reloaded", vim.log.levels.INFO, { timeout = 500 })
  end
})


-- ============================================================================
-- STARTUP MESSAGE
-- ============================================================================
vim.defer_fn(function()
  print("Live-update active | Auto-diff: OFF | <Space>gd: Toggle diff ON | <Space>W or F3: Toggle wrap | <Space>n: Tree")
end, 500)