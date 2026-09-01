#!/bin/zsh
# Spawn a KPS-office agent whose claude process runs on the Windows laptop.
# Usage (as the agent's Custom command in Munder Difflin):
#   remote-agent.sh "<Agent Name>" <windows-session-id> [model]
# The agent must already exist in the KPS hive registry (add it in the UI with
# this script as its command; the registry entry is written before spawn).
set -u
NAME="$1"; SESSION="$2"; MODEL="${3:-claude-opus-4-8}"
HIVE=/Users/bhrat.sankar/md-home-kps/hive
WIN=bharat.sankar@100.126.249.40
MAC=bhrat.sankar@100.64.3.11
CLAUDE='C:\Users\Bharat.Sankar\.local\bin\claude.exe'
WORKDIR='C:\Users\Bharat.Sankar'

# Resolve the agent id from the registry by display name (wait for registration).
ID=""
for i in {1..20}; do
  ID=$(python3 -c "
import json,sys
try:
    r=json.load(open('$HIVE/registry.json'))
    hits=[k for k,v in r.get('agents',{}).items()
          if (v.get('name') or '').strip().lower()=='$NAME'.strip().lower()]
    if hits: print(hits[-1])  # last match = newest registration wins over stale duplicates
except Exception: pass")
  [[ -n "$ID" ]] && break
  sleep 1
done
if [[ -z "$ID" ]]; then
  echo "remote-agent: no agent named '$NAME' in $HIVE/registry.json" >&2
  exit 1
fi

# Windows-side Claude settings: every hook pipes its payload over SSH back to
# the Mac's hive shim (hooks.sock is a unix socket - unreachable from Windows).
SHIM_BASE="ssh -o BatchMode=yes -o ConnectTimeout=5 $MAC \"AGENT_ID=$ID HIVE_SOCK=$HIVE/hooks.sock $HIVE/bin/hive-node /Users/bhrat.sankar/Documents/Claude/munder-difflin/remote-hook.cjs"
python3 - "$ID" "$SHIM_BASE" > "$HIVE/agents/$ID/settings-win.json" <<'PYEOF'
import json, sys
aid, shim_base = sys.argv[1], sys.argv[2]
cmd = shim_base + '"'
status_cmd = shim_base + ' --status"'
entry = lambda m=None: ({**({'matcher': m} if m else {}), 'hooks': [{'type': 'command', 'command': cmd}]})
print(json.dumps({
    'statusLine': {'type': 'command', 'command': status_cmd, 'padding': 0},
    'hooks': {
        'Stop': [entry()], 'SubagentStop': [entry()],
        'PreToolUse': [entry('*')], 'PostToolUse': [entry('*')],
        'UserPromptSubmit': [entry()], 'Notification': [entry()],
        'SessionStart': [entry()], 'PreCompact': [entry()], 'PostCompact': [entry()],
    },
}, indent=1))
PYEOF

PROMPT="You are $NAME, a worker agent in the Munder Difflin KPS office. The hive lives on the orchestrator Mac and is mounted on this machine as H:. Your agent folder is H:\\agents\\$ID - read identity.md and memory.md there at session start, and append durable learnings to memory.md as you work. Follow H:\\PROTOCOL.md for hive messaging: incoming messages arrive as JSON files in your inbox folder, and you send messages by writing JSON files into your outbox folder (the router delivers them). Never run git inside H:."

# Mapped drives are per-logon-session on Windows, and Win32-OpenSSH network
# logons cannot use the credential vault (cmdkey) at all - so mount H: with
# inline credentials read from a 600-perm file on the Mac.
SMBPASS=$(cat ~/.hive-smb-pass 2>/dev/null)
if [[ -z "$SMBPASS" ]]; then
  echo "remote-agent: missing ~/.hive-smb-pass (Mac login password for the SMB share)" >&2
  exit 1
fi
exec ssh -t $WIN "net use H: \\\\100.64.3.11\\hive /user:bhrat.sankar $SMBPASS /persistent:no && cd /d $WORKDIR && $CLAUDE --resume $SESSION --model $MODEL --permission-mode acceptEdits --settings H:\\agents\\$ID\\settings-win.json --append-system-prompt \"$PROMPT\""
