---
name: notion-mcp-oauth-windows-self-auth
description: Use when Notion MCP OAuth on Windows needs to be completed by the agent itself through Edge/CDP, including stale-tab cleanup, localhost callback verification, and post-auth MCP checks.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [notion, mcp, oauth, windows, browser-harness, self-auth]
---

# Notion MCP OAuth Windows Self-Auth

Use this skill when the user asks the agent to authenticate Notion MCP itself, or when `hermes mcp test notion` reports authorization is required on Pans0020's Windows Hermes setup.

## Goal

Complete Notion MCP OAuth without handing manual browser/OAuth work back to the user, unless a human-only step appears (unknown workspace choice, missing Notion login, 2FA, or account confirmation).

## Known setup

- Hermes source/runtime: `C:\Users\Pans0020\hermes-agent-local`
- Hermes command: `C:\Users\Pans0020\hermes.cmd`
- Hermes home: `C:\Users\Pans0020\.hermes`
- Notion MCP may be configured as a remote server: `https://mcp.notion.com/mcp`
- Native Edge Browser Harness/CDP is available on this machine.

## Procedure

1. **Load related skills first**
   - `hermes-agent`
   - `use-native-edge-browser-harness`
   - `notion` if available

2. **Check MCP state**

   ```bat
   C:\Users\Pans0020\hermes.cmd mcp list
   C:\Users\Pans0020\hermes.cmd mcp test notion
   ```

   If `mcp test notion` already reports connected and tools discovered, do not re-authenticate.

3. **Start with a clean browser state**

   Use Browser Harness/CDP to list tabs and close stale tabs whose URL contains either:

   - `notion.so/install-integration`
   - `127.0.0.1` and `/callback`

   Stale tabs are dangerous because they can show an old “Authorization Successful” page for an expired callback port.

4. **Start the OAuth attempt and keep it alive**

   Start the test/login command in the background so the local `127.0.0.1:<port>/callback` listener remains alive while the browser flow runs:

   ```bat
   C:\Users\Pans0020\hermes.cmd mcp test notion
   ```

   or, if available:

   ```bat
   C:\Users\Pans0020\hermes.cmd mcp login notion
   ```

   Do not let the process exit before operating the browser page. The callback port changes on every attempt.

5. **Find the current Notion consent tab**

   Inspect Edge tabs and choose the newest `notion.so/install-integration` tab. If multiple tabs exist, match the current callback port when visible in the URL/body.

6. **Operate the consent page via DOM, not coordinates**

   On the Notion authorization page:

   - If there is a trusted URL checkbox, check it via JS:

     ```js
     const box = document.querySelector('#trusted-url-checkbox');
     if (box && !box.checked) box.click();
     ```

   - Click the real Continue/Authorize button via DOM or accessible text.
   - If Notion asks for workspace/account choice or 2FA, stop and ask the user only for that specific human-only decision.

7. **Verify callback and token persistence**

   Browser success text is not enough. Verify with all applicable checks:

   ```bat
   dir C:\Users\Pans0020\.hermes\mcp-tokens
   C:\Users\Pans0020\hermes.cmd mcp test notion
   ```

   Success means `mcp test notion` reports connected and discovers tools such as Notion search/fetch/create/update.

8. **Use MCP tools through Hermes if needed**

   If direct Notion MCP tools are not exposed in the current agent tool list, invoke Hermes' native MCP client in a short Python helper from `C:\Users\Pans0020\hermes-agent-local`:

   ```python
   import sys
   from pathlib import Path
   root = Path(r"C:\Users\Pans0020\hermes-agent-local")
   sys.path.insert(0, str(root))
   from tools.mcp_tool import discover_mcp_tools, shutdown_mcp_servers
   from tools.registry import registry

   discover_mcp_tools()
   search = registry.get_entry('mcp_notion_notion_search').handler
   fetch = registry.get_entry('mcp_notion_notion_fetch').handler
   print(search({'query': 'JH'}))
   print(fetch({'id': '<page-id-or-url>'}))
   shutdown_mcp_servers()
   ```

## Pitfalls

- Do not conclude Notion is unavailable merely because `NOTION_API_KEY` is missing; OAuth MCP can be the intended path.
- Do not ask the user to perform the OAuth browser flow if they explicitly asked the agent to authenticate itself.
- Do not click old Notion OAuth tabs. Always close stale tabs before a fresh attempt.
- Do not claim success from the browser page alone; verify `hermes mcp test notion` after the callback.
- Keep the OAuth command alive while authorizing; otherwise the local callback listener disappears.
- On affected Hermes/MCP SDK versions, the browser may redirect before the callback server is ready. If auth appears successful but token is not saved, apply the Hermes callback race fix skill.

## Verification checklist

- `hermes mcp list` shows Notion configured and enabled.
- `hermes mcp test notion` completes without requiring authorization.
- Notion MCP tools are discovered.
- A token file under `C:\Users\Pans0020\.hermes\mcp-tokens\` is updated, when applicable.
- A real Notion operation, such as search/fetch, succeeds.
