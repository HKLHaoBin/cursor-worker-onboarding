# Memory Graph - Cursor Worker Onboarding

- slug: cursor-worker-onboarding
- path: `C:/Users/We3q/Projects/cursor-worker-onboarding`
- updated: 2026-09-18

## Summary

Standalone Agent Plugin that guides Windows users through the official Cursor
My Machines worker lifecycle: CLI installation, workspace registration, opt-in
logon startup, diagnostics, and Cursor Web usage.

## Entities

- Cursor Worker Onboarding (Project): standalone worker setup repository
- Cursor Agent CLI (Service): installs, authenticates, and runs the worker
- My Machines Worker (Service): outbound worker connection for local execution
- Workspace Roots Memory (Store): `~/.cursor/memory-graphs/WORKSPACE-ROOTS.md`
- Windows Logon Task (Service): optional per-user startup task
- Cursor Agents Web (Service): `https://cursor.com/agents`

## Relations

- Cursor Worker Onboarding --configures--> My Machines Worker
- Cursor Worker Onboarding --writes--> Workspace Roots Memory
- Windows Logon Task --starts--> My Machines Worker
- Cursor Agents Web --selects--> My Machines Worker

## Facts

- Windows-focused PowerShell scripts are packaged under the skill.
- Startup is opt-in and begins after user logon.
- Generated configuration does not store Cursor credentials.
- The worker uses an outbound Cursor connection; no inbound local URL is created.

## Decisions

- Keep this repository independent from any IDE bridge or desktop automation
  application.
- Use the official `agent worker` CLI and `agent worker debug` commands.
