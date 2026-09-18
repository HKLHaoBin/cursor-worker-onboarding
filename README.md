# Cursor Worker Onboarding / Cursor Worker 初始化

一个用于在 Windows 上配置官方 **My Machines** Worker 的开源 Cursor Agent
Plugin。

An open-source Cursor Agent Plugin for setting up the official **My Machines**
worker on Windows.

## 功能 / Features

中文：

- 安装并登录 Cursor Agent CLI；
- 注册一个或多个具体的项目工作区；
- 将工作区路径写入
  `~/.cursor/memory-graphs/WORKSPACE-ROOTS.md`；
- 可选注册 Windows 用户登录时启动的任务；
- 立即启动一个 Worker；
- 收集启动诊断和日志；
- 从 [Cursor Agents](https://cursor.com/agents) 使用 Worker；
- 安全移除启动任务和生成的本地文件。

English:

- install and sign in to the Cursor Agent CLI;
- register one or more concrete project checkouts;
- write workspace roots to
  `~/.cursor/memory-graphs/WORKSPACE-ROOTS.md`;
- optionally register a per-user Windows logon task;
- start one worker immediately;
- collect startup diagnostics and logs;
- use the worker from [Cursor Agents](https://cursor.com/agents);
- remove the task and generated local files safely.

启动任务会在 Windows 用户登录后运行，不会在登录前作为系统服务运行，因为
My Machines 使用当前用户的 Cursor 登录凭据。

The logon task starts after the Windows user signs in. It does not run before
login as a system service because My Machines uses the signed-in user's Cursor
credential.

## 安装 / Install

在 Cursor 的 Customize / Plugins 流程中安装此仓库，或将其克隆到本地进行
Plugin 开发。根目录的 `plugin.json` 声明 Plugin，具体 skill 位于
`skills/cursor-worker-onboarding/SKILL.md`。

Install this repository as an Agent Plugin from Cursor's Customize / Plugins
flow, or clone it for local plugin development. The root `plugin.json` declares
the plugin and `skills/cursor-worker-onboarding/SKILL.md` contains the skill.

显式调用 skill：

Invoke the skill explicitly:

```text
/cursor-worker-onboarding
```

skill 会询问 Worker 名称和具体项目工作区路径。启用登录自启动或立即启动
Worker 前，必须获得用户明确确认。

The skill asks for the worker name and concrete project checkout directories.
It requires explicit confirmation before enabling logon startup or starting a
worker.

## 官方运行方式 / Official setup model

本项目使用官方 Cursor CLI：

This project uses the official Cursor CLI:

```powershell
irm 'https://cursor.com/install?win32=true' | iex
agent --version
agent login
```

配置完成后，打开
[https://cursor.com/agents](https://cursor.com/agents)，在环境选择器中选择
已注册的机器。

After setup, open [https://cursor.com/agents](https://cursor.com/agents) and
choose the registered machine in the environment picker.

Worker 通过出站 HTTPS 连接到 Cursor。因此，本项目不会创建公网
`localhost` 链接，不会暴露 `.cursor` 目录，不会开放入站防火墙端口，也不会
创建反向隧道。

The worker makes an outbound HTTPS connection to Cursor, so this project does
not create a public `localhost` URL, expose the `.cursor` directory, open an
inbound firewall port, or create a reverse tunnel.

## 文档 / Documentation

- [Skill 使用说明 / Skill guide](skills/cursor-worker-onboarding/SKILL.md)
- [Web 使用与工作区路由 / Web use and routing](skills/cursor-worker-onboarding/references/WEB-USE.md)
- [Cursor My Machines 官方文档 / Official documentation](https://cursor.com/docs/cloud-agent/self-hosted/my-machines.md)

## License / 许可证

MIT
