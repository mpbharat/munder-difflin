#!/bin/bash
# Forced-command shim for the Windows laptop's SSH key
# (comment: bharat.sankar@DXB-3W7Z1T3) in /Users/bhrat.sankar/.ssh/authorized_keys.
#
# LIVE COPY: /Users/bhrat.sankar/.ssh/hive-hook-only.sh (chmod 700)
# This file is a reference copy only - editing it here has no effect until
# the change is copied to the live path above. Not part of the app build.
#
# Restricts that key's authorized_keys entry (via command="...") to running
# ONLY the hive hook shim (remote-hook.cjs, via hive-node, optionally with
# --status), instead of a full shell. Anything else is logged and denied.
set -u
LOG=~/.ssh/hive-hook-denied.log
CMD="${SSH_ORIGINAL_COMMAND:-}"

deny() {
  printf '%s denied: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CMD" >> "$LOG"
  exit 1
}

[[ -n "$CMD" ]] || deny

# Allowed shape: optional AGENT_ID=... and/or HIVE_SOCK=... env assignments
# (in that order), then the hive-node runner on either the kps or personal
# hive, invoking remote-hook.cjs, with an optional trailing --status.
PATTERN='^(AGENT_ID=[^ ]+ )?(HIVE_SOCK=[^ ]+ )?(/Users/bhrat\.sankar/md-home-kps/hive/bin/hive-node|/Users/bhrat\.sankar/md-home-personal/hive/bin/hive-node) /Users/bhrat\.sankar/Documents/Claude/munder-difflin/remote-hook\.cjs( --status)?$'

[[ "$CMD" =~ $PATTERN ]] || deny

exec bash -c "$CMD"
