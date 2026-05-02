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

## Direct Access Checks for Global Sites

When the user asks whether this machine can access Google, X/Twitter, or another external site, do not answer from assumption. Open the site in native Edge through Browser Harness, wait for load, and verify with `browser_page_info()`.

Known-good checks from this Windows setup:

- `https://www.google.com/` should load with title `Google`.
- `https://x.com/` should load with title similar to `X。尽是新鲜事 / X`.

For search questions, Google search works from this browser session; after opening the search URL, extract `document.body.innerText` and summarize the first credible results.


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
| `browser-harness` auto-launches `chrome.exe --remote-debugging-port=9222` | The daemon fell back to local Chrome mode instead of native Edge CDP, often after calling MCP browser tools while `Daemon is unreachable` or with only `BU_CDP_URL` set | Do **not** keep using MCP browser tools. Inspect process chain, stop the Chrome/daemon fallback if unwanted, then restart/reconnect native Edge with `BU_CDP_WS` from `/json/version` |
| User asks “who opened my Chrome clone?” / unexpected Chrome window appears | Browser Harness may have spawned Chrome from `mcp_server.py -> daemon.py -> chrome.exe` | Run the process-inspection script below; admit if our browser-harness action caused it; clean up only after confirming/when safe |
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

## Aliyun Console / Security Group Tasks

When asked to open Aliyun console or change ECS security groups, use native Edge login state and be prepared for no existing Aliyun session. Start with the target console URL (for this server, region is often `cn-shenzhen`), e.g.:

```text
https://ecs.console.aliyun.com/securityGroup/region/cn-shenzhen
```

If `page_info()` ends at `https://account.aliyun.com/login/login.htm?...` with title `阿里云登录页`, do not guess credentials or try to bypass login. Tell the user to complete login/scan in the visible Edge window, then continue after they confirm. The login page may show options including 阿里云APP/支付宝/钉钉, 账密登录, 手机号登录, 通行密钥, RAM登录.

For opening a port for Pans0020's Grok2API sidecar, the intended security-group rule is usually:

- Inbound rule
- TCP
- Port: `8090` (not `8000` if Docker maps `8090 -> container 8000`)
- Source: `0.0.0.0/0` unless the user requests a narrower source

After changing the rule, verify from outside the server with a direct HTTP/TCP probe, not just server-local curl.

## Direct CDP / run.py Workflow When MCP Tools Are Not Yet Loaded

Reference: see `references/unexpected-chrome-spawn.md` for the process chain and probe to diagnose accidental Browser Harness Chrome launches (`mcp_server.py -> daemon.py -> chrome.exe --remote-debugging-port=9222`).

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

For current Chinese/local news checks (e.g. “成都今天有什么交通事故”), first clarify/choose the access mode implied by the user:

- Do not assume the user's “domestic/国内” means China just because the user writes in Chinese or is on QQ. If the region/country matters and was not specified, either use neutral labels such as “Google News 中文/中国区版块” or ask/briefly state the chosen scope. Avoid presenting “国内” as the user's country unless they specified it.
- Be explicit about source and collection method before summarizing when the user asks “数据来源是什么” or challenges sourcing. Distinguish Google News RSS/statistical collection from manually browsing Google News pages/screenshots.
- If the user asks to “在 Google 上统计今日新闻” and does not require screenshots, Google News RSS is the preferred statistical path: fetch topic RSS feeds, filter by today's local date, count total/unique titles, category counts, top sources, and summarize dominant themes. Browser page inspection is mainly for screenshots/manual verification.
- If the user asks to use a browser or wants screenshots/evidence images, use native Edge Browser Harness. Capture/send 1-2 screenshots when requested (e.g. search results plus official/authoritative article or map) and include them as `MEDIA:/absolute/path/to/file` in the reply.
- If the user explicitly says “不通过浏览器”, “直接访问”, or asks whether sites are reachable outside the browser, use direct terminal HTTP checks (`python`/`urllib`, `curl`, or PowerShell) instead of Browser Harness. Verify with HTTP status/final URL, then fetch authoritative pages/RSS directly when possible.

For current Chinese/local news checks (e.g. “成都今天有什么交通事故”), browser search is acceptable when web_search is unavailable: open Baidu with date-specific Chinese keywords, inspect the first results, then run a second targeted query using distinctive details (location/time/official agency) to corroborate. Prefer official/public-authority and wire-service sources such as 成都公安/成都交警、新华社、中国新闻网/中新网、人民网 before self-media. Report only confirmed facts with time, location, casualties/status, suspect/driver details if officially stated, and investigation status; mention sources generically and avoid overstating unverified commentary.

If the user asks whether Google/X or another site works “without the browser” (`不通过浏览器`), verify with a direct HTTP client from terminal, not browser-harness. A compact Python `urllib.request` probe is reliable on this Windows/WSL setup:

```bash
python3 - <<'PY'
import urllib.request, ssl
for u in ['https://www.google.com/','https://x.com/']:
    try:
        req = urllib.request.Request(u, headers={'User-Agent':'Mozilla/5.0 Hermes direct connectivity test'}, method='GET')
        with urllib.request.urlopen(req, timeout=15, context=ssl.create_default_context()) as r:
            print(f"{u} -> HTTP {r.status}; final={r.geturl()}; content-type={r.headers.get('content-type','')}")
    except Exception as e:
        print(f"{u} -> ERROR {type(e).__name__}: {e}")
PY
```

For direct/non-browser news checks, Google News RSS is useful without opening a browser:

```bash
python3 - <<'PY'
import urllib.request, urllib.parse, xml.etree.ElementTree as ET
q='成都 交通事故 2026年5月1日 成都公安 剑南大道 天府四街'
url='https://news.google.com/rss/search?'+urllib.parse.urlencode({'q':q,'hl':'zh-CN','gl':'CN','ceid':'CN:zh-Hans'})
data=urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0 Hermes direct news check'}), timeout=20).read()
root=ET.fromstring(data)
for i,it in enumerate(root.findall('.//item')[:10],1):
    print(f"[{i}] {it.findtext('title')}\n    {it.findtext('source')} | {it.findtext('pubDate')}\n    {it.findtext('link')}")
PY
```

When the user asks for screenshots/images of search results or a news item, use browser-harness screenshots and send them as native QQ media with `MEDIA:/absolute/path/to/file`. After `browser_take_screenshot(filename='name.png')`, locate the file if needed; on this setup screenshots commonly land under `C:\Users\Pans0020\AppData\Local\Temp` (WSL path `/mnt/c/Users/Pans0020/AppData/Local/Temp`). Example final format:

```text
1. Google 搜索结果截图
MEDIA:/mnt/c/Users/Pans0020/AppData/Local/Temp/chengdu_accident_google_results.png

2. 权威报道页面截图
MEDIA:/mnt/c/Users/Pans0020/AppData/Local/Temp/chengdu_accident_xinhua_article.png
```

When a browser/tool turn succeeds, never leave an empty assistant response. Immediately process the last tool output into the user-requested summary. If interrupted after a tool call, resume from the latest successful result rather than repeating the whole workflow.

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
