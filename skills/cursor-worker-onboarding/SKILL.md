---
name: cursor-worker-onboarding
description: Set up and operate a Windows Cursor My Machines worker, including workspace registration, opt-in logon startup, startup diagnostics, and web access. Use when the user asks to install, start, autostart, connect, switch, or troubleshoot a Cursor Agent Worker.
disable-model-invocation: true
icon: rocket
color: cyan
---

# Cursor Worker Onboarding

This skill configures the official Cursor **My Machines** worker. It does not
expose `localhost` or the user's `.cursor` directory to the public internet.

## Safety gate

Before changing anything, explain that setup will:

1. create `~/.cursor/agent-worker/` for worker configuration and logs;
2. write the selected workspace paths to
   `~/.cursor/memory-graphs/WORKSPACE-ROOTS.md`;
3. optionally register a per-user Windows Scheduled Task that starts the worker
   at logon;
4. optionally start one worker process immediately.

Ask for explicit confirmation before enabling startup or starting a worker. A
declined confirmation means inspection and documentation only.

Never put a Cursor API key, login token, cookie, or secret in the generated JSON,
Markdown, scheduled-task arguments, or logs. `agent login` owns the credential
flow.

## Setup workflow

### 1. Collect the machine and workspace inputs

Ask for:

- a worker display name, for example `my-windows`;
- one or more concrete project checkout directories;
- whether to start the worker now;
- whether to start it automatically at Windows logon.

Prefer concrete Git checkout directories such as
`C:\Users\me\Projects\app`. A parent folder such as
`C:\Users\me\Projects` is allowed, but Cursor routing metadata is most reliable
when every registered directory is itself the intended checkout and has its Git
remote.

### 2. Check the Cursor CLI

Run `agent --version`. If it is missing, show the official Windows installer and
wait for the user to approve or complete it:

```powershell
irm 'https://cursor.com/install?win32=true' | iex
agent --version
agent login
```

Do not automate browser login, copy credentials, or substitute a service-account
key for a personal My Machines login.

### 3. Configure the worker

Run the packaged setup script with the paths collected from the user. The script
validates every directory, writes the worker config and memory file, and only
registers startup when `-EnableStartup` is present:

```powershell
$dirs = @(
  'C:\Users\me\Projects\first-repo',
  'C:\Users\me\Projects\second-repo'
)

& '<skill-root>\scripts\setup-worker.ps1' `
  -WorkerDir $dirs `
  -MachineName 'my-windows' `
  -EnableStartup `
  -StartNow
```

Omit `-EnableStartup` or `-StartNow` when the user did not approve that action.
The script is idempotent: running it again replaces only the worker-owned task
and files.

### 4. Verify and diagnose

Run:

```powershell
& '<skill-root>\scripts\preflight-worker.ps1'
Get-ScheduledTask -TaskName 'Cursor Agent Worker' -ErrorAction SilentlyContinue
Get-Content "$env:USERPROFILE\.cursor\agent-worker\worker.log" -Tail 100 -ErrorAction SilentlyContinue
```

`preflight-worker.ps1` checks the CLI, configured directories, scheduled task,
and `agent worker debug`. If the worker is not visible in the web picker, use
the debug output before changing configuration.

### 5. Explain Web and chat usage

Give the user the official direct link:

`https://cursor.com/agents`

In Cursor Web, choose the registered machine in the environment picker, then
choose the repository/workspace that Cursor matched to one of the registered
directories. The worker keeps an outbound HTTPS connection to Cursor, so no
inbound port, public IP, port-forwarding rule, or public `localhost` URL is
needed.

For Slack, GitHub, or Linear surfaces that support worker targeting, use the
machine name, for example:

```text
worker=my-windows
```

If the user asks to work in a particular checkout, include its repository or
workspace name in the request. If that checkout is not registered, rerun the
setup script with its concrete path. Natural language cannot grant a worker
access to an unregistered directory.

## Troubleshooting branches

- **CLI missing:** install from the official URL, open a new shell, then rerun
  `agent --version`.
- **Login or visibility failure:** run `agent login`, then
  `agent worker debug`. Confirm the CLI and browser use the same Cursor account.
- **Worker starts and exits:** inspect `worker.log`; check outbound HTTPS access
  to `api2.cursor.sh`, `api2direct.cursor.sh`, and
  `cloud-agent-artifacts.s3.us-east-1.amazonaws.com`.
- **No task at logon:** run the setup script with `-EnableStartup` after
  confirmation, then query `Get-ScheduledTask`.
- **Wrong workspace:** verify each `-WorkerDir` path is the intended checkout
  and has the expected Git remote. Update the configuration rather than
  inventing a public tunnel.
- **Need to remove startup:** run
  `scripts/uninstall-worker.ps1`. It removes the worker task and local worker
  files; it does not remove Cursor CLI login state or user project directories.

For the complete Web routing model and its limits, read
[references/WEB-USE.md](references/WEB-USE.md).
