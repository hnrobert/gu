# **gu**（git-user）

[English](#english) | [中文](#中文)

## English

`gu` is a command-line tool for managing multiple Git user profiles on a single machine, facilitating the switching of user information between personal and work projects.

### Installation

Run the following commands to install `gu`:

```bash
curl -sSL https://raw.githubusercontent.com/hnrobert/gu/main/install.sh | bash
```

### Usage

#### Set User Information

- For the current directory: `gu set`
- Globally: `gu set --global`

#### Show Current User

```bash
gu show
```

#### Add/Delete User Profiles

- To add: `gu add` and follow the prompts.
- To delete: `gu delete` and select the profile to be deleted.

#### Switch/List User Profiles

- To switch: `gu switch` and select a profile.
- To list: `gu list`

### Contributors

- Forked from: [YOUNGmaxer/git-user](https://github.com/YOUNGmaxer/git-user)
- [hnrobert](https://github.com/hnrobert)

## 中文

`gu` 是一个命令行工具，用于在单个机器上管理多个 Git 用户配置文件，便于在个人和工作项目之间切换用户信息。

### 安装

运行以下命令安装 `gu`：

```bash
curl -sSL https://raw.githubusercontent.com/hnrobert/gu/main/install.sh | bash
```

### 使用

#### 设置用户信息

- 当前目录：`gu set`
- 全局：`gu set --global`

#### 显示当前用户

```bash
gu show
```

#### 添加/删除用户配置文件

- 添加：`gu add` 并按提示操作。
- 删除：`gu delete` 并选择要删除的配置文件。

#### 切换/列出用户配置文件

- 切换：`gu switch` 并选择配置文件。
- 列出：`gu list`

### 贡献者名单

- Fork 自: [YOUNGmaxer/git-user](https://github.com/YOUNGmaxer/git-user)
- [hnrobert](https://github.com/hnrobert)
