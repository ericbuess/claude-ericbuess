
## Testing Requirements
When implementing or changing features:
1. **Create a test plan** before coding
2. **Use Puppeteer** in `/tests/puppeteer` for UI testing
3. **Document expected results** clearly
4. **Have subagents validate** screenshots/logs match expectations
5. **Never claim something works** unless blind subagent returns that it successfuly ran the validation but **can't find any part that failed**.

Example test approach:
```javascript
// 1. Create test plan
const testPlan = {
  feature: "Streaming message display",
  steps: [
    "Send command to agent",
    "Verify 'Claude is thinking...' appears",
    "Verify complete message displays when ready"
  ],
  expectedResults: {
    thinkingIndicator: "visible with animated dots",
    finalMessage: "complete text displayed at once"
  }
}

// 2. Execute with Puppeteer
// 3. Take screenshots
// 4. Have subagent verify results match plan
```


### File Management
- Clean up temporary files after use
- Don't leave test files or one-off scripts lying around
- If you create a file for testing, delete it when done
- Keep the project structure clean and organized

### Testing and Verification
Always close the testing loop:
1. Use available tools (like a browser MCP server) to test what you build
2. Take screenshots to verify UI looks correct and save the console logs -- you'll use these for debugging yourself or with a subagent.
3. Test that features actually work before saying they're done
4. If you can't fully test something, tell the user what they need to verify
5. Don't claim something works without testing it

**CRITICAL FOR WEB PROJECTS**: You MUST connect BOTH Puppeteer AND BrowserTools MCP before testing:
```javascript
// 1. Connect Puppeteer first
mcp__puppeteer__puppeteer_connect_active_tab({ debugPort: 9222 })

// 2. Clear BrowserTools logs
mcp__browser-tools__wipeLogs()

// 3. Now you can interact with Puppeteer and monitor with BrowserTools
// Use Puppeteer for actions, BrowserTools for monitoring
```

Example: If building a web interface, use Puppeteer to:
- Navigate to the page
- Click buttons
- Verify elements appear
- Take screenshots
- Test voice recording if possible

## Browser tools (CRITICAL FOR UI TESTING)

**IMPERATIVE**: BrowserTools MCP server MUST be running for any UI testing. Without it, you're flying blind!

### Always Start BrowserTools First
```bash
# ALWAYS run this before ANY UI testing:
npx @agentdeskai/browser-tools-server --port 3025 &
# Save the process ID that's returned

# Verify it's connected:
# Check BashOutput on the process ID for "Chrome extension connected"
```

### Why BrowserTools is Essential
- **You CANNOT properly test UI without monitoring console logs**
- **You CANNOT verify what's actually happening in the browser**
- **You CANNOT debug issues without seeing errors**
- BrowserTools captures ALL console logs, errors, network requests
- Without it, you're just guessing if things work

You have access to Chrome and Puppeteer and BrowserTools MCP servers.

### Puppeteer on ARM/Apple Silicon with GUI Desktop (CRITICAL)
**You're running macOS in a Parallels VM with FULL GUI on Apple Silicon Mac.**

```
const browser = await puppeteer.launch({
  headless: false,  // Show the browser window!
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--window-size=1280,800'
  ],
  defaultViewport: null,  // Use full browser window
  slowMo: 500  // Optional: slow down actions so user can see them
});

// Use the first tab instead of creating a new one
const pages = await browser.pages();
const page = pages[0] || await browser.newPage();
await page.goto('http://localhost:5173');

// Note: page.waitForTimeout() doesn't exist in newer Puppeteer
// Use: await new Promise(resolve => setTimeout(resolve, milliseconds));
```

For headless testing (when visibility not needed):
```javascript
const browser = await puppeteer.launch({
  executablePath: '/usr/bin/chromium',
  headless: 'new',  // New headless mode
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu'
  ]
});
```

**IMPORTANT**:
- User prefers VISIBLE browser when debugging issues

### Browser Tools MCP Server Setup

**CRITICAL REQUIREMENTS FOR BROWSER TOOLS TO WORK**:
- **ONLY ONE TAB OPEN** - Must have exactly one browser tab (close all others)
- **DEVTOOLS MUST BE OPEN** - Press F12 or open via Chrome menu
- **BROWSER TOOLS EXTENSION INSTALLED** - Must be enabled in Chrome/Chromium

**Setup Process**:

1. **Start the Browser Tools Server** (this creates the bridge to the browser extension):
```bash
npx @agentdeskai/browser-tools-server --port 3025 &
```

2. **Ensure Chrome has ONLY ONE TAB and DevTools OPEN**:
   - Close ALL other tabs first
   - Press F12 to open DevTools (or menu → More Tools → Developer Tools)
   - DevTools MUST stay open for Browser Tools to work

3. **Verify the Browser Extension is connected**:
   - The Browser Tools extension must be installed in Chrome/Chromium
   - Look for "Browser Tools MCP started debugging this browser" in DevTools console
   - The extension icon should show as active/connected
   - Server logs should show "WebSocket connection to Chrome extension"

4. **The MCP tools will then be available** through the mcp__browser-tools__ prefix

**If Browser Tools shows empty logs or "extension not connected"**:
- Check that DevTools is open (F12)
- Verify only ONE tab is open
- Restart the browser-tools-server
- Refresh the page with DevTools open

### When to use

Puppeteer: For active control – refresh pages, click elements, navigate, type, or automate workflows.

BrowserTools: For passive monitoring – get console logs, network/WS traffic, screenshots, element inspection, or run audits (accessibility, performance, SEO). Really useful if user is driving the browser or if you are via Puppeteer.

Choose Based On Task: Use Puppeteer if action needed (e.g., change state); BrowserTools if observing (e.g., analyze data).

Hybrid Tasks (e.g., refresh/click then monitor): Puppeteer for actions first, then BrowserTools for logs/network/elements.

Current Project Tip: Puppeteer to refresh/click/interact; BrowserTools to check logs/WS/network and inspect/modify elements post-action.

### Using Puppeteer MCP + Browser Tools MCP Together

**IMPORTANT**: When using both MCP servers together:

1. **Browser Tools requires DevTools to be open**:
   - The Browser Tools Chrome extension only works when DevTools is open
   - Without DevTools, you'll get "Chrome extension not connected" errors
   - The extension must show "Browser Tools MCP started debugging this browser"

2. **Puppeteer MCP connects to existing Chrome**:
   ```javascript
   // Connect to Chrome with DevTools already open
   mcp__puppeteer__puppeteer_connect_active_tab({ debugPort: 9222 })
   ```

3. **Workflow for using both together**:
   ```javascript
   // 1. Start Browser Tools server (if not running)
   npx @agentdeskai/browser-tools-server --port 3025 &

   // 2. Connect Puppeteer to existing browser
   mcp__puppeteer__puppeteer_connect_active_tab

   // 3. Use Puppeteer for actions
   mcp__puppeteer__puppeteer_navigate({ url: 'http://localhost:5173' })
   mcp__puppeteer__puppeteer_click({ selector: 'button' })

   // 4. Use Browser Tools for monitoring
   mcp__browser-tools__wipeLogs()  // Clear old logs first
   mcp__browser-tools__getConsoleLogs()  // Get console output
   mcp__browser-tools__takeScreenshot()  // Visual verification
   ```

4. **Key Points**:
   - Open Chrome/Chromium manually with DevTools open first
   - Browser Tools needs the extension and DevTools active
   - Puppeteer connects to the existing browser (don't launch new)
   - Clear logs before testing to avoid confusion
   - Browser Tools won't work if DevTools closes
