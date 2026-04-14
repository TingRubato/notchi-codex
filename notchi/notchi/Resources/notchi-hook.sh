#!/bin/bash
# Notchi Hook - forwards CLI events to Notchi app via Unix socket

SOCKET_PATH="/tmp/notchi.sock"

# Exit silently if socket doesn't exist (app not running)
[ -S "$SOCKET_PATH" ] || exit 0

# Detect source provider and non-interactive sessions
IS_INTERACTIVE=true
PROVIDER="${NOTCHI_PROVIDER:-claude}"
for CHECK_PID in $PPID $(ps -o ppid= -p $PPID 2>/dev/null | tr -d ' '); do
    ARGS="$(ps -o args= -p "$CHECK_PID" 2>/dev/null)"
    LOWER_ARGS="$(printf '%s' "$ARGS" | tr '[:upper:]' '[:lower:]')"
    case "$LOWER_ARGS" in
        *" gemini-cli "*|*" gemini "*|*/gemini-cli\ *|*/gemini\ *)
            PROVIDER="gemini-cli"
            ;;
        *" codex "*|*/codex\ *)
            PROVIDER="codex"
            ;;
        *" claude "*|*/claude\ *)
            PROVIDER="claude"
            ;;
    esac

    if printf '%s' "$LOWER_ARGS" | grep -qE '(^| )(-p|--print|--non-interactive)( |$)'; then
        IS_INTERACTIVE=false
        break
    fi
done
export NOTCHI_INTERACTIVE=$IS_INTERACTIVE
export NOTCHI_PROVIDER=$PROVIDER

# Parse input and send to socket using Python
/usr/bin/python3 -c "
import json
import os
import socket
import sys

try:
    input_data = json.load(sys.stdin)
except:
    sys.exit(0)

# Claude uses hook_event_name, Codex uses event_name, gemini-cli may send event.
hook_event = (
    input_data.get('hook_event_name')
    or input_data.get('event_name')
    or input_data.get('event')
    or ''
)

status_map = {
    'UserPromptSubmit': 'processing',
    'PreCompact': 'compacting',
    'SessionStart': 'waiting_for_input',
    'SessionEnd': 'ended',
    'PreToolUse': 'running_tool',
    'PostToolUse': 'processing',
    'PermissionRequest': 'waiting_for_input',
    'Stop': 'waiting_for_input',
    'SubagentStop': 'waiting_for_input'
}

output = {
    'session_id': input_data.get('session_id') or input_data.get('sessionId') or '',
    'transcript_path': input_data.get('transcript_path') or input_data.get('transcriptPath') or '',
    'cwd': input_data.get('cwd') or input_data.get('working_directory') or input_data.get('workspace') or '',
    'event': hook_event,
    'status': input_data.get('status', status_map.get(hook_event, 'unknown')),
    'pid': None,
    'tty': None,
    'interactive': os.environ.get('NOTCHI_INTERACTIVE', 'true') == 'true',
    'permission_mode': input_data.get('permission_mode') or input_data.get('mode') or 'default',
    'provider': os.environ.get('NOTCHI_PROVIDER', 'claude')
}

# Pass user prompt directly for UserPromptSubmit
if hook_event == 'UserPromptSubmit':
    prompt = input_data.get('prompt') or input_data.get('user_prompt') or input_data.get('input') or ''
    if prompt:
        output['user_prompt'] = prompt

tool = input_data.get('tool_name') or input_data.get('tool') or ''
if tool:
    output['tool'] = tool

tool_id = input_data.get('tool_use_id') or input_data.get('toolUseId') or ''
if tool_id:
    output['tool_use_id'] = tool_id

tool_input = input_data.get('tool_input') or input_data.get('toolInput') or {}
if tool_input:
    output['tool_input'] = tool_input

try:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect('$SOCKET_PATH')
    sock.sendall(json.dumps(output).encode())
    sock.close()
except:
    pass
"
