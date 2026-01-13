# **gu**（git-user）

[English](#english) | [中文](#中文)

## English

`gu` is a command-line tool for managing multiple Git user profiles on a single machine, facilitating the switching of user information between personal and work projects.

Profiles are stored at `~/.gu/profiles`; helper executable `/usr/local/bin/gutemp` is used for SSH forced-command bindings.

### Installation

Run the following commands to install `gu`:

```bash
curl -sSL https://raw.githubusercontent.com/hnrobert/gu/main/install.sh | bash
```

> To install from the development branch, use the `develop` branch and add the `-d` flag during installation:
>
> ```bash
> curl -sSL https://raw.githubusercontent.com/hnrobert/gu/develop/install.sh | bash -s -- -d
> ```

#### Windows (PowerShell)

Download and run the PowerShell installer (recommended):

```powershell
irm https://raw.githubusercontent.com/hnrobert/gu/main/install.ps1 -OutFile install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

> Install from the development branch:
>
> ```powershell
> irm https://raw.githubusercontent.com/hnrobert/gu/develop/install.ps1 -OutFile install.ps1
> powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Develop
> ```

After installation, it is recommended to restart your terminal (to apply PATH changes) and run `gu version`.

### Usage

#### Commands (English)

- `gu show` — Show the current Git user name and email.
- `gu list` — List all profiles and highlight the current one.
- `gu add [-u|--user ALIAS | ALIAS]` — Add a profile with the given alias (prompts for details).
- `gu set [-g|--global] [-u|--user ALIAS | ALIAS]` — Switch to an existing profile and apply it; if missing, optionally create a new one. Interactive mode lists profiles with an "Add another profile" option.
- `gu delete [-u|--user ALIAS | ALIAS]` — Delete an existing profile (interactive selection supported).
- `gu update [-u|--user ALIAS | ALIAS]` — Update a profile's alias/name/email in the config file (creates on request).
- `gu config -k|--auth-key [ALIAS]` — Bind an SSH authorized_keys entry to a `gu` alias via forced command.
- `gu config -r|--remote-host [ALIAS]` — Setup git user using forced command binding for a remote host.
- `gu upgrade` — Download and install the latest version of `gu`.
- `gu help` — Show help.
- `gu version` — Show current version.

#### Examples

```bash
gu list
gu show
gu add work
gu set -g                # set globally (interactive if no alias provided)
gu set -u hnrobert       # switch to an existing profile (or create if missing)
gu update -u workuser    # update alias/name/email for an existing profile
gu config -k workuser    # bind an SSH public key to the workuser alias,
                         # switching to this user when logging into this machine with that key
gu config -r workuser    # set up git user for a remote host,
                         # switching to this user in the ssh terminal
                         # when logging into that remote host via SSH
gu delete prev           # delete a profile
gu upgrade               # self-update the tool
```

### Remote (VS Code Remote-SSH) notes

- If you're using `gu` through **VS Code Remote-SSH**, you may need to enable `remote.SSH.enableRemoteCommand` in VS Code settings and use `gu config -r` for forced-command bindings to take effect.
- When using `gu config -r`, ensure `gu` is installed and the necessary aliases are configured on the remote host so the forced command works properly.
- If you're connecting via a normal SSH terminal, either `gu config -k` (bind key) or `gu config -r` (remote config) will work.

### Windows notes

- `install.ps1` installs to `%LOCALAPPDATA%\gu\bin` by default, and creates `gu.cmd` / `gutemp.cmd` shims so you can run `gu` as a normal command.
- Profiles are still stored in `$HOME\.gu\profiles`.
- SSH forced-command bindings rely on OpenSSH on Windows. The `gu config -k` command edits `$HOME\.ssh\authorized_keys`.

### Contributors

- Forked from: [YOUNGmaxer/git-user](https://github.com/YOUNGmaxer/git-user)
- [hnrobert](https://github.com/hnrobert)

## 中文

`gu` 是一个命令行工具，用于在单个机器上管理多个 Git 用户配置文件，便于在个人和工作项目之间切换用户信息。

配置文件存放于 `~/.gu/profiles`，SSH 绑定会使用 `/usr/local/bin/gutemp` 作为强制命令脚本。

### 安装

运行以下命令安装 `gu`：

```bash
curl -sSL https://raw.githubusercontent.com/hnrobert/gu/main/install.sh | bash
```

> 若要在安装时使用开发分支，可使用 `develop` 分支并添加 `-d` 参数：
>
> ```bash
> curl -sSL https://raw.githubusercontent.com/hnrobert/gu/develop/install.sh | bash -s -- -d
> ```

#### Windows（PowerShell）

推荐下载后执行安装脚本：

```powershell
irm https://raw.githubusercontent.com/hnrobert/gu/main/install.ps1 -OutFile install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

> 安装开发分支版本：
>
> ```powershell
> irm https://raw.githubusercontent.com/hnrobert/gu/develop/install.ps1 -OutFile install.ps1
> powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Develop
> ```

安装完成后建议重开一个终端（PATH 生效），然后运行 `gu version`。

### 使用

#### 命令（中文）

- `gu show` — 显示当前 Git 用户名和邮箱。
- `gu list` — 列出所有配置文件并高亮当前配置。
- `gu add [-u|--user ALIAS | ALIAS]` — 添加指定别名的配置文件（交互式输入信息）。
- `gu set [-g|--global] [-u|--user ALIAS | ALIAS]` — 切换到已有配置并应用；若不存在可选择创建。无别名时会先列出配置并提供“Add another profile”选项。
- `gu delete [-u|--user ALIAS | ALIAS]` — 删除已有配置（支持交互选择）。
- `gu update [-u|--user ALIAS | ALIAS]` — 更新配置文件中的别名/姓名/邮箱（按需创建）。
- `gu config -k|--auth-key [ALIAS]` — 在本地将 SSH authorized_keys 条目与 gu 别名绑定（强制命令）。
- `gu config -r|--remote-host [ALIAS]` — 为一个远程主机配置设置 git 用户（强制命令绑定）。
- `gu upgrade` — 下载并安装最新版本。
- `gu help` — 查看帮助。
- `gu version` — 查看当前版本。

#### 示例

```bash
gu list
gu show
gu add work
gu set -g                # 全局设置（无别名时交互选择或创建）
gu set -u hnrobert       # 切换到已有配置（不存在时可创建）
gu update -u workuser    # 更新已有配置的别名/姓名/邮箱
gu config -k workuser    # 将 SSH 公钥绑定到 workuser 别名，
                         # 当前用户使用该密钥登录本机时会自动切换
gu config -r workuser    # 为远程主机设置 git 用户，
                         # 当前用户通过 SSH 登录该远程主机时，
                         # 会在远程主机的终端中自动切换
gu delete prev           # 删除配置
gu upgrade               # 升级工具
```

### 远程（VS Code Remote-SSH）注意事项

- 如果通过 **VS Code 的 Remote-SSH** 使用 `gu`，可能需要在 VS Code 设置中启用 `remote.SSH.enableRemoteCommand`，并使用 `gu config -r` 来使强制命令绑定生效。
- 使用 `gu config -r` 时，需要在被连接的远端主机上安装并配置好 `gu`，并创建好相应的 alias，才能让远端强制命令正常工作。
- 如果是通过常规 SSH 终端直接连接，则 `gu config -k`（绑定密钥）和 `gu config -r`（远端配置）任意一个即可发挥作用。

### Windows 注意事项

- `install.ps1` 默认安装到 `%LOCALAPPDATA%\gu\bin`，并生成 `gu.cmd` / `gutemp.cmd`，方便像普通命令一样直接运行 `gu`。
- 配置文件仍然存放在 `$HOME\.gu\profiles`。
- SSH 强制命令绑定依赖 Windows 的 OpenSSH；`gu config -k` 会修改 `$HOME\.ssh\authorized_keys`。

### 贡献者名单

- Fork 自: [YOUNGmaxer/git-user](https://github.com/YOUNGmaxer/git-user)
- [hnrobert](https://github.com/hnrobert)
