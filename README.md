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

### Usage

#### Commands (English)

- `gu show` — Show the current Git user name and email.
- `gu list` — List all profiles and highlight the current one.
- `gu add [-u|--user ALIAS | ALIAS]` — Add a profile with the given alias (prompts for details).
- `gu set [-g|--global] [-u|--user ALIAS | ALIAS]` — Switch to an existing profile and apply it; if missing, optionally create a new one. Interactive mode lists profiles with an "Add another profile" option.
- `gu delete [-u|--user ALIAS | ALIAS]` — Delete an existing profile (interactive selection supported).
- `gu update [-u|--user ALIAS | ALIAS]` — Update a profile's alias/name/email in the config file (creates on request).
- `gu config -k|--auth-key [ALIAS]` — Bind an SSH authorized_keys entry to a `gu` alias via forced command.
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
gu config -k workuser    # bind an SSH key to the workuser alias
gu delete prev           # delete a profile
gu upgrade               # self-update the tool
```

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

### 使用

#### 命令（中文）

- `gu show` — 显示当前 Git 用户名和邮箱。
- `gu list` — 列出所有配置文件并高亮当前配置。
- `gu add [-u|--user ALIAS | ALIAS]` — 添加指定别名的配置文件（交互式输入信息）。
- `gu set [-g|--global] [-u|--user ALIAS | ALIAS]` — 切换到已有配置并应用；若不存在可选择创建。无别名时会先列出配置并提供“Add another profile”选项。
- `gu delete [-u|--user ALIAS | ALIAS]` — 删除已有配置（支持交互选择）。
- `gu update [-u|--user ALIAS | ALIAS]` — 更新配置文件中的别名/姓名/邮箱（按需创建）。
- `gu config -k|--auth-key [ALIAS]` — 将 SSH authorized_keys 条目与 gu 别名绑定（强制命令）。
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
gu config -k workuser    # 将 SSH 密钥绑定到 workuser 别名
gu delete prev           # 删除配置
gu upgrade               # 升级工具
```

### 贡献者名单

- Fork 自: [YOUNGmaxer/git-user](https://github.com/YOUNGmaxer/git-user)
- [hnrobert](https://github.com/hnrobert)
