# Cursor Worker Onboarding

An open-source Cursor Agent Plugin for setting up the official **My Machines**
worker on Windows.

The bundled skill guides a user through:

- installing and signing in to the Cursor Agent CLI;
- registering one or more concrete project checkouts;
- writing workspace roots to
  `~/.cursor/memory-graphs/WORKSPACE-ROOTS.md`;
- optionally registering a per-user Windows logon task;
- starting one worker immediately;
- collecting startup diagnostics and logs;
- using the worker from [Cursor Agents](https://cursor.com/agents);
- removing the task and generated local files safely.

The logon task starts after the Windows user signs in. It does not run before
login as a system service because My Machines uses the signed-in user's Cursor
credential.

## Install

Install this repository as an Agent Plugin from Cursor's Customize / Plugins
flow, or clone it for local plugin development. The root `plugin.json` declares
the plugin and `skills/cursor-worker-onboarding/SKILL.md` contains the skill.

Invoke the skill explicitly:

```text
/cursor-worker-onboarding
```

The skill asks for the worker name and concrete project checkout directories.
It requires explicit confirmation before enabling logon startup or starting a
worker.

## Official setup model

The setup uses the official Cursor CLI:

```powershell
irm 'https://cursor.com/install?win32=true' | iex
agent --version
agent login
```

After setup, open [https://cursor.com/agents](https://cursor.com/agents) and
choose the registered machine in the environment picker. The worker makes an
outbound HTTPS connection to Cursor, so this project does not create a public
`localhost` URL, expose the `.cursor` directory, open an inbound firewall port,
or create a reverse tunnel.

See the skill documentation for routing, privacy, and troubleshooting details:

- [`skills/cursor-worker-onboarding/SKILL.md`](skills/cursor-worker-onboarding/SKILL.md)
- [`skills/cursor-worker-onboarding/references/WEB-USE.md`](skills/cursor-worker-onboarding/references/WEB-USE.md)
- [Cursor My Machines documentation](https://cursor.com/docs/cloud-agent/self-hosted/my-machines.md)

## License

MIT
