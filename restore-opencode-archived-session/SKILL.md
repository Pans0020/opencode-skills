---
name: restore-opencode-archived-session
description: Use when an OpenCode session, conversation, chat, or archived thread is hidden from the normal list and the user wants it brought back, unarchived, restored, or found in the current folder.
---

# Restore OpenCode Archived Session

## Overview

OpenCode archived sessions are normally still present in `opencode.db`; they are hidden because `session.time_archived` is set. Restoring a session means identifying the exact row and setting `time_archived` to `NULL`.

## Safety Rules

1. Do not delete or recreate the session.
2. Do not edit messages or parts for an archive-only restore.
3. Only update the selected session ID.
4. If the user explicitly says not to back up the database, do not create a backup.
5. Treat mojibake Chinese titles and directories as normal; search by multiple clues, not just exact Unicode text.

## Quick Search

Target database:

```text
C:\Users\<user>\.local\share\opencode\opencode.db
```

List recent archived sessions:

```powershell
$code = @'
import sqlite3, json, pathlib, datetime
db = pathlib.Path.home() / '.local' / 'share' / 'opencode' / 'opencode.db'
con = sqlite3.connect('file:' + str(db) + '?mode=ro', uri=True)
con.row_factory = sqlite3.Row
rows = []
for r in con.execute('''
  select id, slug, title, directory, time_created, time_updated, time_archived
  from session
  where time_archived is not null
  order by time_archived desc
  limit 50
'''):
    d = dict(r)
    for k in ('time_created', 'time_updated', 'time_archived'):
        if d.get(k):
            d[k + '_iso'] = datetime.datetime.fromtimestamp(d[k] / 1000).isoformat(sep=' ')
    rows.append(d)
print(json.dumps(rows, ensure_ascii=False, indent=2))
'@
$code | python -
```

Search archived sessions by title, slug, directory, or message text:

```powershell
$needle = '牛客'
$code = @'
import sqlite3, json, pathlib
needle = r''' + $needle + r'''
db = pathlib.Path.home() / '.local' / 'share' / 'opencode' / 'opencode.db'
con = sqlite3.connect('file:' + str(db) + '?mode=ro', uri=True)
con.row_factory = sqlite3.Row
hits = {}
for r in con.execute('''
  select id, slug, title, directory, time_archived
  from session
  where time_archived is not null
    and (coalesce(title,'') like ? or coalesce(slug,'') like ? or coalesce(directory,'') like ?)
  order by time_archived desc
''', (f'%{needle}%', f'%{needle}%', f'%{needle}%')):
    hits[r['id']] = dict(r)
for r in con.execute('''
  select distinct s.id, s.slug, s.title, s.directory, s.time_archived
  from session s
  join message m on m.session_id = s.id
  where s.time_archived is not null and coalesce(m.data,'') like ?
  order by s.time_archived desc
''', (f'%{needle}%',)):
    hits.setdefault(r['id'], dict(r))
print(json.dumps(list(hits.values()), ensure_ascii=False, indent=2))
'@
$code | python -
```

If exact Chinese search returns no hits, list recent archived sessions and look for mojibake title/path clues, nearby timestamps, or matching current folder. For example, `新建文件夹` may appear as `�½��ļ���`, and `牛客` may appear as `ţ��`.

## Restore

Use the chosen session ID:

```powershell
$sid = 'ses_xxx'
$code = @'
import sqlite3, json, pathlib
sid = r''' + $sid + r'''
db = pathlib.Path.home() / '.local' / 'share' / 'opencode' / 'opencode.db'
con = sqlite3.connect(str(db))
con.row_factory = sqlite3.Row
before = con.execute('select id, slug, title, directory, time_archived from session where id=?', (sid,)).fetchone()
if before is None:
    raise SystemExit('session not found: ' + sid)
cur = con.execute('update session set time_archived=NULL where id=? and time_archived is not NULL', (sid,))
con.commit()
after = con.execute('select id, slug, title, directory, time_archived from session where id=?', (sid,)).fetchone()
con.close()
print(json.dumps({'changed': cur.rowcount, 'before': dict(before), 'after': dict(after)}, ensure_ascii=False, indent=2))
'@
$code | python -
```

## Verification

```powershell
$sid = 'ses_xxx'
$code = @'
import sqlite3, json, pathlib
sid = r''' + $sid + r'''
db = pathlib.Path.home() / '.local' / 'share' / 'opencode' / 'opencode.db'
con = sqlite3.connect('file:' + str(db) + '?mode=ro', uri=True)
con.row_factory = sqlite3.Row
row = con.execute('select id, slug, title, directory, time_archived from session where id=?', (sid,)).fetchone()
visible = con.execute('select count(*) from session where id=? and time_archived is NULL', (sid,)).fetchone()[0]
con.close()
print(json.dumps({'visible_unarchived_count': visible, 'session': dict(row) if row else None}, ensure_ascii=False, indent=2))
if visible != 1:
    raise SystemExit(2)
'@
$code | python -
```

If OpenCode Desktop is already open, refresh or restart it so the session list reloads.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Exact Chinese search returns nothing | Search recent archives and inspect mojibake titles/directories. |
| Restoring the wrong similarly named session | Compare directory, timestamps, slug, and message snippets before updating. |
| Updating `time_updated` unnecessarily | Leave it alone unless the UI requires resorting; restore only needs `time_archived=NULL`. |
| Editing message JSON | Not needed for archive restore; only session visibility changes. |
| Assuming no backup is always okay | Follow the user's instruction; if they did not forbid backup, consider normal DB safety practice. |
