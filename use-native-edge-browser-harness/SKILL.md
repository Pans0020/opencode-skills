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

3. Start/reconnect Browser Harness against `9222` using the **WebSocket URL**, not just `BU_CDP_URL`:

```powershell
$v = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:9222/json/version" -TimeoutSec 5).Content | ConvertFrom-Json
$env:BU_CDP_WS = $v.webSocketDebuggerUrl
Remove-Item Env:BU_CDP_URL -ErrorAction SilentlyContinue
& "C:\Users\Pans0020\browser-harness-mcp\.venv\Scripts\python.exe" run.py -c "print(page_info())"
```

Important: on this Windows Browser Harness build, `admin.py` decides “remote CDP vs local Chrome mode” by checking `BU_CDP_WS`. If only `BU_CDP_URL='http://127.0.0.1:9222'` is set, Browser Harness may still think it is in local Chrome mode and auto-launch extra Chrome windows. Prefer `BU_CDP_WS` from `/json/version` whenever connecting to native Edge.

4. Use the MCP tools normally:

- `browser-harness_browser_navigate` for navigation
- `browser-harness_browser_list_tabs` to inspect tabs
- `browser-harness_browser_switch_tab` to switch to an existing logged-in tab
- `browser-harness_browser_page_info` to verify the final page

For Xiaohongshu, prefer `https://www.xiaohongshu.com/`; successful final URL is often `https://www.xiaohongshu.com/explore`.


## Login / QR-Code Handoff Rule

When using a browser to log into a website or app and the page requires the user to scan a QR code, verify in the browser and send a screenshot to the user immediately. Do not only say “please scan in the browser”; the user may be on QQ/voice and needs the image in chat.

Required workflow:

1. Detect the login/QR state from `page_info()` and visible page text. Common signs include 登录, 扫码, QR code, 阿里云APP/支付宝/钉钉, 微信扫码, 手机确认, or a visible login canvas/image.
2. Capture the current viewport with `browser-harness_browser_take_screenshot(filename='login_qr_<site>.png')`.
3. Send the screenshot back as native QQ media, preferably with a Windows-native `MEDIA:` path on this setup, e.g. `MEDIA:C:\Users\Pans0020\AppData\Local\Temp\login_qr_aliyun.png`. Avoid relying on `/mnt/c/...` or `/tmp/...` for QQ media delivery when a Windows path is available.
4. Include one short instruction such as “请扫这张图，登录完成后告诉我好了，我会继续操作。”
5. After the user confirms login, continue from the existing tab/session; do not restart Edge unless CDP is stale.

If the screenshot tool returns only a POSIX/WSL path, convert it to a Windows path before sending on QQ when possible:

```text
/mnt/c/Users/Pans0020/AppData/Local/Temp/login_qr_aliyun.png
→ C:\Users\Pans0020\AppData\Local\Temp\login_qr_aliyun.png
```

Example response when blocked by QR login:

```text
需要你扫码登录，我把当前浏览器二维码截图发你了。登录完成后回我“好了”。
MEDIA:C:\Users\Pans0020\AppData\Local\Temp\login_qr_aliyun.png
```

## Recovery Decision Table

| Symptom | Meaning | Action |
|---|---|---|
| `127.0.0.1:9222` unreachable | Native Edge is closed or not started with CDP | Run the restart command above |
| `Daemon is unreachable` | Browser Harness daemon is not listening | Set `BU_CDP_WS` from `http://127.0.0.1:9222/json/version`, then run `run.py -c`; do not rely on `BU_CDP_URL` alone |
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

## Direct CDP / run.py Workflow When MCP Tools Are Not Yet Loaded

If Hermes has just installed or reconfigured the MCP and the current session does not yet expose `browser-harness_*` tools, use the local Browser Harness scripts through terminal as a fallback.

1. Start Edge with CDP and the native profile, then verify `9222/json/version`.

2. List tabs directly:

```powershell
$tabs = (Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:9222/json/list').Content | ConvertFrom-Json
$tabs | ForEach-Object { "$($_.id)`t$($_.title)`t$($_.url)" }
```

3. Use `run.py` with `BU_CDP_WS` set from `/json/version` (not `BU_CDP_URL`). This avoids Browser Harness misclassifying the session as local Chrome mode and opening extra Chrome windows:

```powershell
$v = (Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:9222/json/version' -TimeoutSec 5).Content | ConvertFrom-Json
$env:BU_CDP_WS = $v.webSocketDebuggerUrl
Remove-Item Env:BU_CDP_URL -ErrorAction SilentlyContinue
Set-Location 'C:\Users\Pans0020\browser-harness-mcp'
$code = @'
from helpers import switch_tab, page_info, wait_for_load, js
switch_tab('<targetId-from-json-list>')
wait_for_load(15)
print(page_info())
print(js('document.body.innerText'))
'@
& 'C:\Users\Pans0020\browser-harness-mcp\.venv\Scripts\python.exe' run.py -c $code
```

For Xiaohongshu notifications, `/notification` exposes the visible text via `document.body.innerText`; parse the first entries under `评论和@`, `赞和收藏`, or `新增关注` depending on what the user asked.

For Xiaohongshu recommendations (`/explore`), fetch the visible card grid with JS after verifying `page_info()`. Prefer extracting several note/card elements (`a[href*='/explore/']`, visible title/text/author/like hints) and summarize the first few cards back to the user. If a previous tool turn succeeded but the assistant returned an empty response, continue from the last successful tool result instead of restarting from scratch.

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
