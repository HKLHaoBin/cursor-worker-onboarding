# Web use and workspace routing

## The supported entry point

Open [Cursor Agents](https://cursor.com/agents), then choose the registered
My Machines worker in the environment picker. The worker maintains an outbound
HTTPS connection to Cursor. Cursor sends agent tool calls over that connection.

There is intentionally no public URL for `C:\Users\<name>\.cursor`, no
`http://localhost` URL that Cursor Web can use to reach the Windows host, and no
need to open an inbound firewall port. A reverse tunnel would be a separate
product with a separate authentication boundary; this skill does not create one.

## How a workspace is selected

The worker is registered with one or more `--worker-dir` values. For a Git
checkout with a remote, Cursor uses the checkout's repository metadata to route
the request to the matching worker directory.

Use one concrete checkout per `--worker-dir` when possible:

```powershell
agent worker `
  --name my-windows `
  --worker-dir 'C:\Users\me\Projects\first-repo' `
  --worker-dir 'C:\Users\me\Projects\second-repo' `
  start
```

If a new checkout is added later, rerun `setup-worker.ps1` with the complete
list. Do not treat a chat prompt as permission to access an unregistered local
path.

For supported Slack, GitHub, and Linear triggers, target the named machine:

```text
worker=my-windows
```

The repository on the triggering surface still needs to match a repository
registered by the worker. A machine name alone does not select an arbitrary
directory.

## Privacy and security

The worker sends the content needed for the Cloud Agent run, including relevant
files, terminal output, diffs, screenshots, local MCP results, and routing
metadata. Local credentials and the checkout remain on the machine, but users
should keep secrets out of tool output and artifacts. Use Cursor Privacy Mode
when appropriate.

The worker needs outbound HTTPS access to:

- `api2.cursor.sh`
- `api2direct.cursor.sh`
- `cloud-agent-artifacts.s3.us-east-1.amazonaws.com`

For current authentication, networking, and troubleshooting details, see the
official [My Machines documentation](https://cursor.com/docs/cloud-agent/self-hosted/my-machines.md).
