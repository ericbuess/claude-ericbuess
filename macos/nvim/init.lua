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

-- Set up colors for git status
vim.api.nvim_set_hl(0, 'ExplorerModified', { fg = '#ff9900', bold = true })
vim.api.nvim_set_hl(0, 'ExplorerAdded', { fg = '#00ff00', bold = true })
vim.api.nvim_set_hl(0, 'ExplorerUntracked', { fg = '#808080' })
vim.api.nvim_set_hl(0, 'ExplorerDirectory', { fg = '#4488ff', bold = true })
vim.api.nvim_set_hl(0, 'Question', { fg = '#ffff00', bold = true })

-- Cache for git status to improve performance
local git_status_cache = {}
local cache_timestamp = 0

-- Directory navigation history for cursor positioning
local dir_cursor_positions = {}

-- Get git status with caching
function GetGitStatus(path)
  local current_time = vim.loop.now()
  
  -- Clear cache if older than 2 seconds
  if current_time - cache_timestamp > 2000 then
    git_status_cache = {}
    cache_timestamp = current_time
  end
  
  if not git_status_cache[path] then
    git_status_cache[path] = vim.fn.system('git status --porcelain ' .. vim.fn.shellescape(path) .. ' 2>/dev/null')
  end
  
  return git_status_cache[path]
end

-- Refresh file list in explorer
function RefreshExplorer(restore_position)
  if not vim.g.explorer_buf or not vim.api.nvim_buf_is_valid(vim.g.explorer_buf) then
    return
  end
  
  -- Get current directory
  local current_dir = vim.fn.getcwd()
  local dir_parts = vim.split(current_dir, '/')
  local dir_name = dir_parts[#dir_parts] or '/'
  
  -- Save the directory we're coming from if restore_position is specified
  local target_line = nil
  if restore_position and type(restore_position) == 'string' then
    target_line = restore_position
  end
  
  -- Start with header, help, and parent directory option
  local files = {
    "━━━ " .. current_dir .. " ━━━",
    "[?] Help - Keyboard Shortcuts",
    "[..] Parent Directory"
  }
  local highlights = {
    {line = 0, hl = 'Comment'},  -- Header in comment color
    {line = 1, hl = 'Question'},  -- Help in special color
    {line = 2, hl = 'ExplorerDirectory'}  -- Parent dir
  }
  local line_num = 3
  
  -- Get file list
  local handle = vim.loop.fs_scandir('.')
  
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      
      -- Only skip .git directory itself (show other hidden files)
      if name ~= '.git' then
        local prefix = '    '
        local highlight = nil
        
        if type == 'directory' then
          -- Check if directory contains modified files (recursively)
          local dir_status = GetGitStatus(name)
          if dir_status ~= '' then
            prefix = '[M>]'  -- Directory with modifications
            highlight = 'ExplorerModified'
          else
            prefix = '[>] '
            highlight = 'ExplorerDirectory'
          end
        else
          -- Check file git status
          local git_status = GetGitStatus(name)
          if git_status ~= '' then
            if git_status:match('^M') or git_status:match('^.M') then
              prefix = '[M] '  -- Modified
              highlight = 'ExplorerModified'
            elseif git_status:match('^??') then
              prefix = '[?] '  -- Untracked
              highlight = 'ExplorerUntracked'
            elseif git_status:match('^A') then
              prefix = '[+] '  -- Added
              highlight = 'ExplorerAdded'
            end
          end
        end
        
        table.insert(files, prefix .. name)
        if highlight then
          table.insert(highlights, {line = line_num, hl = highlight})
        end
        line_num = line_num + 1
      end
    end
  end
  
  -- Update buffer
  vim.api.nvim_buf_set_option(vim.g.explorer_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(vim.g.explorer_buf, 0, -1, false, files)
  vim.api.nvim_buf_set_option(vim.g.explorer_buf, 'modifiable', false)
  
  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace('explorer_highlights')
  vim.api.nvim_buf_clear_namespace(vim.g.explorer_buf, ns_id, 0, -1)
  
  for _, hl_info in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(vim.g.explorer_buf, ns_id, hl_info.hl, hl_info.line, 0, -1)
  end
  
  -- Restore cursor position if requested
  if target_line then
    -- Find the line with the target directory/file
    for i, line in ipairs(files) do
      if line:match(target_line .. '$') then
        -- Check if we're in the explorer window
        local current_win = vim.api.nvim_get_current_win()
        local current_buf = vim.api.nvim_win_get_buf(current_win)
        if current_buf == vim.g.explorer_buf then
          vim.api.nvim_win_set_cursor(current_win, {i, 0})
        else
          -- Find explorer window and set cursor there
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win) == vim.g.explorer_buf then
              vim.api.nvim_win_set_cursor(win, {i, 0})
              break
            end
          end
        end
        break
      end
    end
  end
end

-- Open file from explorer
function OpenFileFromExplorer()
  local line = vim.api.nvim_get_current_line()
  
  -- Handle Help
  if line:match('%[%?%]') then
    local explorer_win = vim.api.nvim_get_current_win()
    vim.cmd('wincmd j')
    ShowHelp()
    vim.api.nvim_set_current_win(explorer_win)
    return
  end
  
  -- Handle parent directory
  if line:match('%[%.%.%]') then
    -- Get the current directory name before going up
    local current_dir = vim.fn.getcwd()
    local dir_parts = vim.split(current_dir, '/')
    local current_dir_name = dir_parts[#dir_parts]
    
    vim.cmd('cd ..')
    -- Refresh and position cursor on the directory we came from
    RefreshExplorer(current_dir_name)
    return
  end
  
  -- Skip header line
  if line:match('^━━━') then
    return
  end
  
  -- Extract filename (handle both [M>] and [>] for directories)
  local filename = line:gsub('^%[M?>%] ', ''):gsub('^%[.%] ', ''):gsub('^    ', '')
  
  if filename ~= '' then
    -- Check if it's a directory
    local stat = vim.loop.fs_stat(filename)
    if stat and stat.type == 'directory' then
      vim.cmd('cd ' .. filename)
      RefreshExplorer()
    else
      -- Save current window (explorer)
      local explorer_win = vim.api.nvim_get_current_win()
      
      -- Get full path for the file
      local full_path = vim.fn.getcwd() .. '/' .. filename
      
      -- Go to bottom window
      vim.cmd('wincmd j')
      
      -- Check if we're looking at this file already (in any view mode)
      -- When in diff view, vim.g.diff_file holds the actual file path
      local currently_viewing_file = vim.g.diff_file or vim.fn.expand('%:p')
      local is_same_file = currently_viewing_file == full_path
      
      if is_same_file then
        -- File is already open - toggle between diff and file view
        if vim.g.current_view_mode == "diff" then
          ShowFileView()
        else
          ShowDiffView()
        end
      else
        -- Different file or no file open - open the new file
        -- Reset view mode if we were in special views
        if vim.g.current_view_mode == "all_diffs" or vim.g.current_view_mode == "help" then
          vim.g.current_view_mode = "file"
        end
        
        -- Clear old diff file reference when switching to a new file
        vim.g.diff_file = nil
        vim.g.current_view_mode = "file"
        
        vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
        
        -- Now that file is open, check if it's modified and show diff if it is
        local git_status = GetGitStatus(filename)
        if git_status ~= '' and (git_status:match('^M') or git_status:match('^.M')) then
          ShowDiffView()  -- This will set vim.g.diff_file properly
        end
      end
      
      -- Return focus to explorer
      vim.api.nvim_set_current_win(explorer_win)
    end
  end
end

-- ============================================================================
-- SMART DIFF VIEW
-- ============================================================================
vim.g.current_view_mode = "file"

function ShowDiffView()
  -- Store the current file before potentially switching buffers
  local file = vim.g.diff_file or vim.fn.expand('%:p')
  if file == '' then 
    vim.notify("No file to diff")
    return 
  end
  
  -- Store the file path for later
  vim.g.diff_file = file
  
  local diff_output = vim.fn.system('git diff ' .. vim.fn.shellescape(file))
  
  -- Create diff view even if no changes (to show that)
  vim.cmd('enew')
  vim.cmd('setlocal buftype=nofile bufhidden=wipe noswapfile')
  vim.cmd('setlocal filetype=diff')
  vim.cmd('setlocal number')
  
  local lines = {"=== DIFF: " .. vim.fn.fnamemodify(file, ':~:.') .. " ===", ""}
  
  if diff_output ~= '' then
    for line in diff_output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  else
    table.insert(lines, "No changes in this file")
  end
  
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.cmd('setlocal readonly nomodifiable')
  vim.g.current_view_mode = "diff"
end

function ShowFileView()
  if vim.g.diff_file then
    vim.cmd('edit ' .. vim.fn.fnameescape(vim.g.diff_file))
    vim.g.current_view_mode = "file"
    -- Don't clear diff_file here, we might need it for toggling
  end
end

-- Show help in editor
function ShowHelp()
  vim.cmd('enew')
  vim.cmd('setlocal buftype=nofile bufhidden=wipe noswapfile')
  vim.cmd('setlocal filetype=markdown')
  vim.cmd('setlocal wrap')
  
  local help_lines = {
    "# Neovim Watch Mode - Keyboard Shortcuts",
    "",
    "## Navigation",
    "- `Ctrl+k` - Go to explorer (top pane)",
    "- `Ctrl+j` - Go to editor (bottom pane)",
    "",
    "## In Explorer",
    "- `Enter` or `l` - Open file/directory",
    "- `-` or `u` or `h` - Go to parent directory",
    "- `R` - Refresh explorer",
    "- `F5` - Refresh all (explorer + check for file changes)",
    "",
    "## In Editor",
    "- `Enter` - Toggle between file and diff view (same as Space+v)",
    "- `Space+v` - Toggle single file diff view",
    "- `Space+V` - Show/hide all diffs in one view",
    "- `Space+W` - Toggle line wrap",
    "- `Space+e` - Toggle explorer visibility",
    "",
    "## File Status Indicators",
    "- `[M]` - Modified file",
    "- `[+]` - Added file",
    "- `[?]` - Untracked file",
    "- `[>]` - Directory",
    "- `[M>]` - Directory with modified files",
    "",
    "## Tips",
    "- Modified files automatically show diff view when opened",
    "- Explorer auto-refreshes every 3 seconds",
    "- Cursor position is remembered when navigating directories",
    "- Select any file to exit help or all-diffs view",
    "",
    "Press `Enter` or select a file to close this help"
  }
  
  vim.api.nvim_buf_set_lines(0, 0, -1, false, help_lines)
  vim.cmd('setlocal readonly nomodifiable')
  vim.g.current_view_mode = "help"
  vim.cmd('normal! gg')
end

-- Show all diffs in one view
function ShowAllDiffs()
  -- Get all modified files
  local git_status = vim.fn.system('git status --porcelain')
  if git_status == '' then
    vim.notify("No modified files")
    return
  end
  
  -- Create new buffer for all diffs
  vim.cmd('enew')
  vim.cmd('setlocal buftype=nofile bufhidden=wipe noswapfile')
  vim.cmd('setlocal filetype=diff')
  vim.cmd('setlocal number')
  
  local all_lines = {"=== ALL DIFFS ===", "=== Press Space+V again or select a file to exit ===", ""}
  
  -- Process each modified file
  for line in git_status:gmatch("[^\r\n]+") do
    local status = line:sub(1, 2)
    local filename = line:sub(4)
    
    -- Only show diffs for modified files (not untracked/deleted)
    if status:match('M') then
      table.insert(all_lines, "")
      table.insert(all_lines, "════════════════════════════════════════════════════════")
      table.insert(all_lines, "FILE: " .. filename)
      table.insert(all_lines, "════════════════════════════════════════════════════════")
      
      local diff_output = vim.fn.system('git diff ' .. vim.fn.shellescape(filename))
      if diff_output ~= '' then
        for diff_line in diff_output:gmatch("[^\r\n]+") do
          table.insert(all_lines, diff_line)
        end
      end
    end
  end
  
  vim.api.nvim_buf_set_lines(0, 0, -1, false, all_lines)
  vim.cmd('setlocal readonly nomodifiable')
  vim.g.current_view_mode = "all_diffs"
  
  -- Jump to top of buffer
  vim.cmd('normal! gg')
end

-- ============================================================================
-- KEY MAPPINGS
-- ============================================================================
-- Explorer-specific key mappings
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    
    -- Only set mappings for explorer buffer
    if buf == vim.g.explorer_buf then
      -- Enter is now handled globally
      vim.keymap.set('n', 'l', OpenFileFromExplorer, { buffer = true, silent = true, desc = "Open file/dir" })
      vim.keymap.set('n', 'R', RefreshExplorer, { buffer = true, silent = true, desc = "Refresh" })
      vim.keymap.set('n', '-', function()
        local current_dir = vim.fn.getcwd()
        local dir_parts = vim.split(current_dir, '/')
        local current_dir_name = dir_parts[#dir_parts]
        vim.cmd('cd ..')
        RefreshExplorer(current_dir_name)
      end, { buffer = true, silent = true, desc = "Go to parent" })
      vim.keymap.set('n', 'u', function()
        local current_dir = vim.fn.getcwd()
        local dir_parts = vim.split(current_dir, '/')
        local current_dir_name = dir_parts[#dir_parts]
        vim.cmd('cd ..')
        RefreshExplorer(current_dir_name)
      end, { buffer = true, silent = true, desc = "Go up" })
      vim.keymap.set('n', 'h', function()
        local current_dir = vim.fn.getcwd()
        local dir_parts = vim.split(current_dir, '/')
        local current_dir_name = dir_parts[#dir_parts]
        vim.cmd('cd ..')
        RefreshExplorer(current_dir_name)
      end, { buffer = true, silent = true, desc = "Go to parent" })
    end
  end
})

-- GLOBAL Enter key mapping - handles all cases
vim.keymap.set('n', '<CR>', function()
  -- Case 1: In explorer - open file/dir
  if vim.api.nvim_get_current_buf() == vim.g.explorer_buf then
    OpenFileFromExplorer()
    return
  end
  
  -- Case 2: In diff view - go back to file
  if vim.g.current_view_mode == "diff" then
    ShowFileView()
    return
  end
  
  -- Case 3: In help or all_diffs - exit to file
  if vim.g.current_view_mode == "help" or vim.g.current_view_mode == "all_diffs" then
    if vim.g.diff_file then
      ShowFileView()
    else
      OpenFirstFile()
    end
    return
  end
  
  -- Case 4: In regular file - show diff
  if vim.g.current_view_mode == "file" then
    ShowDiffView()
    return
  end
  
  -- Default: do nothing (shouldn't reach here)
end, { desc = "Smart Enter: Toggle diff/file or open in explorer" })

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

-- Single file diff toggle
vim.keymap.set('n', '<leader>v', function()
  local was_in_explorer = vim.api.nvim_get_current_buf() == vim.g.explorer_buf
  
  -- If in explorer, switch to editor window first
  if was_in_explorer then
    vim.cmd('wincmd j')
  end
  
  -- Now toggle the view in the editor window
  if vim.g.current_view_mode == "diff" then
    ShowFileView()
  else
    ShowDiffView()
  end
  
  -- Return to explorer if we started there
  if was_in_explorer then
    vim.cmd('wincmd k')
  end
end, { desc = "Toggle file/diff view" })

-- All diffs toggle (Space+V)
vim.keymap.set('n', '<leader>V', function()
  local was_in_explorer = vim.api.nvim_get_current_buf() == vim.g.explorer_buf
  
  -- If in explorer, switch to editor window first
  if was_in_explorer then
    vim.cmd('wincmd j')
  end
  
  -- Toggle all diffs view
  if vim.g.current_view_mode == "all_diffs" then
    -- Exit all diffs view
    if vim.g.diff_file then
      ShowFileView()
    else
      -- No previous file, just open first file
      OpenFirstFile()
    end
  else
    ShowAllDiffs()
  end
  
  -- Return to explorer if we started there
  if was_in_explorer then
    vim.cmd('wincmd k')
  end
end, { desc = "Toggle all diffs view" })

-- Line wrap
vim.keymap.set('n', '<leader>W', function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify(vim.wo.wrap and "Wrap: ON" or "Wrap: OFF")
end, { desc = "Toggle wrap" })

-- Manual refresh all
vim.keymap.set('n', '<F5>', function()
  -- Clear git cache
  git_status_cache = {}
  cache_timestamp = 0
  
  -- Refresh explorer
  RefreshExplorer()
  
  -- Check for file changes
  vim.cmd('checktime')
  
  vim.notify("Refreshed")
end, { desc = "Refresh all" })

-- ============================================================================
-- GITSIGNS
-- ============================================================================
vim.defer_fn(function()
  local ok, gitsigns = pcall(require, 'gitsigns')
  if ok then
    gitsigns.setup({
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '-' },
      },
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
      options = { theme = 'tokyonight' },
    })
  end
end, 300)

-- Function to open first file automatically
function OpenFirstFile()
  -- Find first actual file (not directory)
  local handle = vim.loop.fs_scandir('.')
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      
      -- Open first non-hidden file
      if not name:match('^%.') and type == 'file' then
        vim.cmd('edit ' .. name)
        
        -- Check if file is modified and show diff if it is
        local git_status = GetGitStatus(name)
        if git_status ~= '' and (git_status:match('^M') or git_status:match('^.M')) then
          ShowDiffView()
        end
        
        return
      end
    end
  end
  
  -- If no files found, just show empty buffer
  vim.cmd('enew')
end

-- ============================================================================
-- AUTO-REFRESH
-- ============================================================================
-- Set up timer to refresh explorer periodically (catches external changes)
local refresh_timer = vim.loop.new_timer()
refresh_timer:start(3000, 3000, vim.schedule_wrap(function()
  if vim.g.explorer_buf and vim.api.nvim_buf_is_valid(vim.g.explorer_buf) then
    -- Only refresh if explorer buffer exists
    local current_win = vim.api.nvim_get_current_win()
    RefreshExplorer()
    -- Restore focus to original window
    pcall(vim.api.nvim_set_current_win, current_win)
  end
end))

-- ============================================================================
-- STARTUP
-- ============================================================================
vim.defer_fn(function()
  OpenTopExplorer()
  
  -- Open first file in bottom window but stay in explorer
  vim.defer_fn(function()
    vim.cmd('wincmd j')  -- Go to bottom window
    OpenFirstFile()
    vim.cmd('wincmd k')  -- Return focus to explorer (top)
    
    -- Position cursor on first actual file/directory (line 4, after help)
    if vim.g.explorer_buf and vim.api.nvim_buf_is_valid(vim.g.explorer_buf) then
      local lines = vim.api.nvim_buf_get_lines(vim.g.explorer_buf, 0, -1, false)
      if #lines >= 4 then
        vim.api.nvim_win_set_cursor(0, {4, 0})
      end
    end
  end, 150)
  
  print("TOP: Explorer | Enter = Open | Ctrl+k/j: Navigate | Space+v: Diff | Space+V: All diffs | F5: Refresh")
end, 100)