---
name: fix-hermes-notion-mcp-oauth-callback-race-windows
description: Use when Hermes Notion MCP OAuth on Windows appears successful in the browser but Hermes times out, fails to persist tokens, or keeps requiring authorization; documents the callback listener race and code-level repair.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes, mcp, oauth, notion, windows, debugging, callback-race]
---

# Fix Hermes Notion MCP OAuth Callback Race on Windows

Use this skill when Notion MCP OAuth appears to complete in Edge/Notion but Hermes still reports authorization required, times out, or does not persist the OAuth token.

## Symptom pattern

- `hermes mcp test notion` prints an authorization URL or opens a Notion OAuth/install-integration page.
- The browser redirects to a local callback URL, often `http://127.0.0.1:<random-port>/callback`.
- The browser may show “Authorization Successful”.
- Hermes CLI still times out or later reports that Notion authorization is required again.
- The expected token under `C:\Users\Pans0020\.hermes\mcp-tokens\` is missing or not updated.

## Root cause to check

A race can occur if Hermes/MCP SDK opens the browser before the local callback server is actually listening on `127.0.0.1:<port>/callback`. Notion can redirect back quickly enough that the callback is missed. A separate CLI timeout around OAuth can also kill the command while the user/agent is still authorizing.

## Investigation steps

1. Confirm Notion MCP config:

   ```bat
   C:\Users\Pans0020\hermes.cmd mcp list
   C:\Users\Pans0020\hermes.cmd mcp test notion
   ```

2. Close stale browser tabs before each run:
   - `notion.so/install-integration`
   - `127.0.0.1:* /callback`

3. Watch the active callback port. Each run creates a new port. Do not operate an old consent tab.

4. Check whether a token file is written or updated:

   ```bat
   dir C:\Users\Pans0020\.hermes\mcp-tokens
   ```

5. Inspect relevant code in the Hermes repo, especially OAuth helper and MCP config/test paths, e.g.:

   ```bat
   cd /d C:\Users\Pans0020\hermes-agent-local
   git status --short
   ```

   Search for the OAuth callback server, browser open call, timeout wrappers, and token persistence paths.

## Code-level repair pattern

Implement the fix so the callback listener is started before the browser is opened.

1. Allocate/bind callback server first.
2. Build the redirect URI from the actual bound address/port.
3. Register or pass that redirect URI into the OAuth authorization request.
4. Only then open the browser or print the authorization URL.
5. Keep the callback server alive until one of these happens:
   - callback received and token persisted
   - explicit cancellation
   - a generous timeout expires
6. Avoid wrapping the entire OAuth flow in a short 30–40 second CLI probe timeout.
7. Ensure stale pending OAuth attempts are cleaned up between runs.

Pseudo-flow:

```python
server = OAuthCallbackServer(host='127.0.0.1', port=0)
server.start()                         # must bind before browser opens
redirect_uri = server.callback_url

auth_url = oauth_client.build_authorize_url(redirect_uri=redirect_uri)
open_browser(auth_url)

code = server.wait_for_callback(timeout=300)
tokens = oauth_client.exchange_code(code, redirect_uri=redirect_uri)
token_store.save(server_name='notion', tokens=tokens)
```

## Windows-specific operational repair

If the code is not fixed yet, reduce the failure rate while testing:

1. Start `hermes mcp test notion` or `hermes mcp login notion` and keep it alive.
2. Immediately operate the single newest Notion authorization tab through Edge Browser Harness/CDP.
3. Use DOM operations when possible:

   ```js
   const box = document.querySelector('#trusted-url-checkbox');
   if (box && !box.checked) box.click();
   ```

4. Click Continue/Authorize.
5. Verify from Hermes, not just the browser.

## Verification after code change

Run:

```bat
C:\Users\Pans0020\hermes.cmd mcp test notion
```

Success criteria:

- The command does not keep re-requesting authorization.
- It reports connected/discovered tools.
- Notion MCP search/fetch works from Hermes.
- Token persistence survives a new process run.

## Regression test ideas

- Unit-test that callback server/listener starts before the browser opener is called.
- Mock a fast redirect immediately after `open_browser()` and assert the callback is accepted.
- Test that a successful callback writes token data to the configured Hermes profile token path.
- Test that the OAuth flow timeout is long enough and does not kill the callback server prematurely.

## Pitfalls

- Do not treat “Authorization Successful” in an old browser tab as proof for the current CLI run.
- Do not overwrite unrelated local modifications in the Hermes repository; inspect `git status` before editing.
- Do not print OAuth tokens or `.env` secrets while debugging.
- Do not ask the user to repeat manual OAuth if the agent can operate Edge and the only blocker is the callback race.
