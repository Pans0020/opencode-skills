---
name: use-native-edge-browser-harness
description: Use when Pans0020 asks to use a browser, open a website, browse with login state, access Xiaohongshu/小红书, or recover browser-harness after CDP or WebSocket errors on this Windows machine.
---

# Use Native Edge Browser Harness

## Overview

For browser tasks on this machine, use Pans0020's **native Microsoft Edge login state** by default. Do not open an isolated `browser-harness-edge-profile` browser unless the user explicitly asks for a clean/no-login browser.

Fixed paths and ports:

- Edge executable: `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
- Native Edge profile: `C:\Users\Pans0020\AppData\Local\Microsoft\Edge\User Data`
- CDP endpoint: `http://127.0.0.1:9222`
- Browser Harness repo: `C:\Users\Pans0020\browser-harness-mcp`
- Browser Harness Python: `C:\Users\Pans0020\browser-harness-mcp\.venv\Scripts\python.exe`
- Stale daemon files: `C:\Users\Pans0020\AppData\Local\Temp\bu-default.*`

Core rule: if the user says “打开浏览器”, “打开网页”, “打开小红书”, “用浏览器”, or needs a logged-in site, connect `browser-harness` to native Edge on port `9222`.

## Quick Path

1. Check whether native Edge CDP is alive:

```powershell
try { (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:9222/json/version" -TimeoutSec 5).Content } catch { $_.Exception.Message }
```

2. If `9222` is not reachable, if `browser-harness` says `Daemon is unreachable`, or if a tool returns `no close frame received or sent`, restart native Edge with the real profile:

```powershell
Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Remove-Item -Force -ErrorAction SilentlyContinue "C:\Users\Pans0020\AppData\Local\Temp\bu-default.pid", "C:\Users\Pans0020\AppData\Local\Temp\bu-default.port", "C:\Users\Pans0020\AppData\Local\Temp\bu-default.sock"
Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList '--remote-debugging-port=9222 --user-data-dir="C:\Users\Pans0020\AppData\Local\Microsoft\Edge\User Data" "https://www.xiaohongshu.com/"'
Start-Sleep -Seconds 8
```

Important: keep `-ArgumentList` as **one single-quoted string**. Do not pass `--user-data-dir=C:\Users\Pans0020\AppData\Local\Microsoft\Edge\User Data` as an unquoted array item; PowerShell may split `User Data` and Edge may open `http://data/`.

3. Start/reconnect Browser Harness against `9222`:

```powershell
$env:BU_CDP_URL='http://127.0.0.1:9222'
& "C:\Users\Pans0020\browser-harness-mcp\.venv\Scripts\python.exe" run.py -c "print(page_info())"
```

4. Use the MCP tools normally:

- `browser-harness_browser_navigate` for navigation
- `browser-harness_browser_list_tabs` to inspect tabs
- `browser-harness_browser_switch_tab` to switch to an existing logged-in tab
- `browser-harness_browser_page_info` to verify the final page

For Xiaohongshu, prefer `https://www.xiaohongshu.com/`; successful final URL is often `https://www.xiaohongshu.com/explore`.

## Recovery Decision Table

| Symptom | Meaning | Action |
|---|---|---|
| `127.0.0.1:9222` unreachable | Native Edge is closed or not started with CDP | Run the restart command above |
| `Daemon is unreachable` | Browser Harness daemon is not listening | Start with `BU_CDP_URL=http://127.0.0.1:9222` and `run.py -c` |
| `no close frame received or sent` | CDP WebSocket behind daemon went stale | Stop Edge, remove `bu-default.*`, restart native Edge, reconnect |
| `chrome-error://chromewebdata/` or `http://data/` | `User Data` path was split by bad quoting | Restart with the single-string `-ArgumentList` command |
| `browser-harness --reload` raises `SystemError` / `WinError 87` | Known Windows bug in `os.kill(pid, 0)` path | Do not rely on reload; clear `bu-default.*` and restart Edge |
| No login state | Wrong profile was used | Verify `--user-data-dir="C:\Users\Pans0020\AppData\Local\Microsoft\Edge\User Data"` |

## Verification

Before saying the browser is open or connected, run at least one fresh verification:

```powershell
try { $v = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:9222/json/version" -TimeoutSec 5).Content | ConvertFrom-Json; "9222 OK: $($v.Browser) $($v.webSocketDebuggerUrl)" } catch { $_.Exception.Message }
```

Then verify from MCP:

```text
browser-harness_browser_page_info()
```

Expected for Xiaohongshu:

```json
{
  "url": "https://www.xiaohongshu.com/explore",
  "title": "🟢 小红书 - 你的生活兴趣社区"
}
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Opening `C:\Users\Pans0020\browser-harness-edge-profile` | Use the native Edge profile path unless user asks for isolation |
| Using `chrome-devtools` MCP for browser work | Prefer `browser-harness`; Chrome DevTools MCP may be disabled |
| Trusting `daemon alive` alone | Also check `9222/json/version`; daemon can be stale while Edge is gone |
| Not switching tabs | Use `browser-harness_browser_list_tabs(false)` and switch to the real target tab |
| Claiming success after restart only | Verify with `browser_page_info()` and mention the current URL/title |

## Safe Defaults

- It is acceptable to close/restart Edge only when browser control is requested and `9222` is unavailable or stale.
- Warn the user briefly if closing Edge may disrupt visible work.
- Preserve login state by using the native profile; do not delete Edge user data.
- Do not delete `C:\Users\Pans0020\AppData\Local\Microsoft\Edge\User Data`.
