# Unexpected Chrome Spawn from Browser Harness

Session learning: when Browser Harness is unreachable/stale on this Windows setup, calling MCP browser tools can cause `browser-harness-mcp` to fall back to local Chrome mode and launch the user's Google Chrome with remote debugging, even though the intended workflow is native Edge.

Observed process chain:

```text
Hermes QQ gateway
  -> C:\Users\Pans0020\.hermes\run-hermes-gateway-direct.py
    -> C:\Users\Pans0020\browser-harness-mcp\mcp_server.py
      -> C:\Users\Pans0020\browser-harness-mcp\daemon.py
        -> C:\Users\Pans0020\AppData\Local\Google\Chrome\Application\chrome.exe --remote-debugging-port=9222 --remote-allow-origins=*
```

Observed Chrome used the normal Chrome user data directory:

```text
C:\Users\Pans0020\AppData\Local\Google\Chrome\User Data
```

Probe used to identify it:

```powershell
$procs = Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'chrome|msedge|browser|python|node|hermes' }
$procs | Select-Object ProcessId,ParentProcessId,Name,CommandLine | Format-List
```

Important quoting pitfall from WSL/bash: inline PowerShell commands containing `$_.Name` can be mangled into `/bin/bash.Name`. Prefer writing the probe to a Windows `.ps1` file under `C:\Users\Pans0020\AppData\Local\Temp\...` and executing it with `powershell.exe -File`.

Interpretation: if the root Chrome process has parent `python.exe` under `browser-harness-mcp` and command line includes `--remote-debugging-port=9222`, it was almost certainly Browser Harness, not the user.

Response style: tell the user directly if our browser-harness action caused it; do not deflect. Offer to stop the Chrome/browser-harness fallback and reconnect native Edge, but avoid killing the user's browser without confirming/scope.
