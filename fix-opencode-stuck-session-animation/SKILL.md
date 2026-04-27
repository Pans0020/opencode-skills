---
name: fix-opencode-stuck-session-animation
description: Use when OpenCode Desktop shows a session as still generating, working, spinning, pulsing, busy, or animated even though the last answer stopped and no command is running.
---

# Fix OpenCode Stuck Session Animation

## Overview

OpenCode Desktop's sidebar working animation is not caused only by running tools. In the current desktop bundle, a session item is considered working when either:

- there is a pending permission/question, or
- any assistant message in that session lacks numeric `time.completed`, or
- `session_status[sessionID]` is non-idle.

The common stale-state bug is an old assistant message with `time.created` but no `time.completed`. Fix that record; do **not** archive or delete the session.

## When to Use

Use this when the user says things like:

- "这个 session 结束了但还有动画"
- "OpenCode 一直显示正在活动/生成"
- "session 列表里有 spinner / pulse / busy animation"
- "最后一条消息已经 `finish: stop`，但侧边栏还动"

Do not use this merely because a session is under the "Active / 活动中" group. Active can mean unarchived. This skill is for the **animated working indicator**.

## Safety Rules

1. Never fix this by archiving the session unless the user explicitly wants it hidden.
2. Never delete the session.
3. Always back up `opencode.db` before edits.
4. Only edit the target session.
5. Prefer adding missing completion metadata to stale assistant messages; avoid changing historical content.

## Quick Diagnosis

Target database:

```text
C:\Users\<user>\.local\share\opencode\opencode.db
```

Find unfinished assistant messages for a session:

```powershell
$sid = 'ses_xxx'
$code = @'
import sqlite3, json
sid = r''' + $sid + r'''
db = r''' + $env:USERPROFILE + r''' + r'\.local\share\opencode\opencode.db'
con = sqlite3.connect('file:' + db + '?mode=ro', uri=True)
con.row_factory = sqlite3.Row
unfinished = []
for r in con.execute('select id,time_created,time_updated,data from message where session_id=? order by time_created', (sid,)):
    d = json.loads(r['data'])
    if d.get('role') == 'assistant' and not isinstance((d.get('time') or {}).get('completed'), (int, float)):
        unfinished.append({'id': r['id'], 'time_created': r['time_created'], 'time_updated': r['time_updated'], 'finish': d.get('finish'), 'error': d.get('error'), 'time': d.get('time')})
print(json.dumps(unfinished, ensure_ascii=False, indent=2))
'@
$code | python -
```

If this returns any rows, those rows can trigger the sidebar animation.

Also check tool parts:

```powershell
$sid = 'ses_xxx'
$code = @'
import sqlite3, json
sid = r''' + $sid + r'''
db = r''' + $env:USERPROFILE + r''' + r'\.local\share\opencode\opencode.db'
con = sqlite3.connect('file:' + db + '?mode=ro', uri=True)
con.row_factory = sqlite3.Row
running = []
for r in con.execute('select id,message_id,data from part where session_id=?', (sid,)):
    d = json.loads(r['data'])
    if d.get('type') == 'tool' and (d.get('state') or {}).get('status') == 'running':
        running.append({'id': r['id'], 'message_id': r['message_id'], 'tool': d.get('tool')})
print(json.dumps(running, ensure_ascii=False, indent=2))
'@
$code | python -
```

## Manual Fix

Back up and mark stale assistant messages as completed:

```powershell
$sid = 'ses_xxx'
$code = @'
import sqlite3, json, pathlib, time
sid = r''' + $sid + r'''
db = pathlib.Path(r''' + $env:USERPROFILE + r''' + r'\.local\share\opencode\opencode.db')
backup = db.with_name('opencode.db.backup_before_fix_stuck_animation_' + sid + '_' + time.strftime('%Y%m%d_%H%M%S'))
src = sqlite3.connect(str(db)); dst = sqlite3.connect(str(backup)); src.backup(dst); dst.close(); src.close()

con = sqlite3.connect(str(db)); con.row_factory = sqlite3.Row
cur = con.cursor()
changed = []
for r in cur.execute('select id,time_updated,time_created,data from message where session_id=? order by time_created', (sid,)).fetchall():
    d = json.loads(r['data'])
    if d.get('role') != 'assistant':
        continue
    t = d.setdefault('time', {})
    if isinstance(t.get('completed'), (int, float)):
        continue
    completed = r['time_updated'] or r['time_created'] or t.get('created')
    t['completed'] = completed
    d.setdefault('finish', 'stop')
    cur.execute('update message set data=? where id=? and session_id=?', (json.dumps(d, ensure_ascii=False, separators=(',', ':')), r['id'], sid))
    changed.append(r['id'])
con.commit(); con.close()
print(json.dumps({'backup': str(backup), 'changed': changed}, ensure_ascii=False, indent=2))
'@
$code | python -
```

## Verification

Run both checks after editing:

```powershell
$sid = 'ses_xxx'
$code = @'
import sqlite3, json, sys
sid = r''' + $sid + r'''
db = r''' + $env:USERPROFILE + r''' + r'\.local\share\opencode\opencode.db'
con = sqlite3.connect('file:' + db + '?mode=ro', uri=True)
con.row_factory = sqlite3.Row
unfinished = []
for r in con.execute('select id,data from message where session_id=?', (sid,)):
    d = json.loads(r['data'])
    if d.get('role') == 'assistant' and not isinstance((d.get('time') or {}).get('completed'), (int, float)):
        unfinished.append(r['id'])
running = []
for r in con.execute('select id,message_id,data from part where session_id=?', (sid,)):
    d = json.loads(r['data'])
    if d.get('type') == 'tool' and (d.get('state') or {}).get('status') == 'running':
        running.append(r['id'])
print(json.dumps({'unfinished_assistant_messages': unfinished, 'running_tools': running}, ensure_ascii=False, indent=2))
if unfinished or running:
    sys.exit(2)
'@
$code | python -
```

If OpenCode Desktop is already open, refresh or restart it after the database edit so the UI reloads the state.

## Common Mistakes

| Mistake | Why it is wrong |
|---|---|
| Archiving the session | It hides the session from the normal list; it does not fix the animation root cause. |
| Only checking the last message | One old unfinished assistant message anywhere in the session can trigger the animation. |
| Only checking tool parts | The sidebar logic also checks assistant messages without `time.completed`. |
| Editing all sessions | This can corrupt unrelated history; only edit the requested session. |
| No backup | `opencode.db` is user state; always create a backup first. |
