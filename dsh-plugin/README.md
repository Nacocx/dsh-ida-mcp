# Hex-Rays IDA MCP · DeepSeek Harness 插件

把本仓库的 Hex-Rays IDA MCP 服务（stdio）接入 DeepSeek Harness（下称 dsh）。插件本身不实现工具，
只声明一条 `@deepseek-ai/dsh-mcp-client` 连接：dsh 启动后拉起本仓库的
`dsh-plugin/bin/launch.sh`，把 MCP 服务的 6 个工具注册为 `mcp__ida__<tool>`，与内置工具一样
可直接调用。仅支持 macOS/Linux（启动器使用 `/bin/sh`）。

## 组成

| 文件 | 作用 |
| --- | --- |
| `package.json` | bundle 清单：`dsh.bundle.patch` 指向本目录的 patch，并导出 locale 与图标 |
| `cordis.patch.yml` | 插入一条 `mcp-client` 配置行：`serverName: ida`、stdio、内联启动脚本（优先已安装的 `ida-mcp`，回退 `launch.sh`/uvx） |
| `bin/launch.sh` | 本地 checkout 的回退启动器；插件行内联脚本会优先直接使用已安装的 `ida-mcp` |
| `locale/*.json` | bundle 卡片显示的标题、说明与详情文档路径（中英双语） |
| `docs/` | 详情页的一句话说明与配图 |
| `icon.svg` | bundle 图标（36×36，原创） |
| `../demo/` | 端到端测试用的 C 程序与编译产物，不在 bundle 包内 |

卡片下的插件行由 `@deepseek-ai/dsh-mcp-client` 提供，标题沿用上游的 `MCP client`，图标是面板默认图形；
bundle 的标题与图标只出现在 bundle 卡片上。

## 前置条件

- IDA 9.4 或更高版本，且许可证可用。ida-nexus 通过 `IDADIR` 或
  `~/.idapro/ida-config.json` 的 `Paths.ida-install-dir` 找到 IDA；本机为
  `/Applications/IDA Professional 9.4.app`。
- [uv](https://docs.astral.sh/uv/)：用于一次性安装 `ida-mcp`，或作为未安装时的
  `uvx` 回退。Finder/launchd 启动的 dsh 可能没有 shell 的 `PATH`，启动器会检查
  `command -v uvx`、`~/.local/bin/uvx`、`/opt/homebrew/bin/uvx`、`/usr/local/bin/uvx`。
- 仅 macOS/Linux。

先验证服务本身可用：

```bash
uvx --from /Users/nax/Code/dsh-ida-mcp ida-mcp --help
```

离线使用要求先完成一次 `uv tool install`，见[离线使用](#离线使用)。

## 安装

1. 在 dsh「插件」页点 **Add plugin**，在输入框粘贴本目录的**绝对路径**（例如
   `/Users/nax/Code/dsh-ida-mcp/dsh-plugin`）；用内置管理能力等价于 `install_bundle` + 该路径。
2. 安装返回 applied 后，调用 `mcp__ida__list_databases` 确认服务已连接；再调用
   `mcp__ida__open_database` 打开一个二进制。工具通常直接出现在当前会话；没有出现时新开会话或重启 dsh。

bundle 以 `link:` 指向本目录，**移动仓库后必须从新路径重新安装**；`IDA_MCP_HOME` 只影响启动器路径，
修不好失效的链接。离线使用前先按下一节安装一次 `ida-mcp`；bundle 本身是本地链接，不依赖注册表。

`cordis.patch.yml` 里的 `IDA_MCP_HOME` 只作为未安装 `ida-mcp` 时的回退路径；已安装 `ida-mcp` 时
不会用到它。仓库换了位置时，bundle 的 `link:` 本身需要从新路径重新安装；未安装 `ida-mcp`、想走
uvx 回退时，才需要改默认路径或在启动 dsh 前设置 `IDA_MCP_HOME`。

## 从 Git 安装

### 推荐：clone 后安装本地目录

bundle 与仓库里的 `ida_mcp/` 是同一套 checkout，直接安装 `dsh-plugin` 目录最省事：

```bash
git clone https://github.com/Nacocx/dsh-ida-mcp.git
cd dsh-ida-mcp
uv tool install --force --editable .
```

然后在 Plugins 页 **Add plugin** 填 `<clone>/dsh-plugin` 的绝对路径。只要先执行了上面的
`uv tool install`，clone 不在 `/Users/nax/Code/dsh-ida-mcp` 也不影响启动；只有未安装 `ida-mcp`、
想走 uvx 回退时，才需要启动 dsh 前设置 `IDA_MCP_HOME=<clone>`，或改 `cordis.patch.yml` 的默认路径。

### 直接安装 git 子目录

如果已经有 `ida-mcp` 命令（上一步的 `uv tool install`），也可以让 DSH 直接安装 bundle 子目录：

```text
git+https://github.com/Nacocx/dsh-ida-mcp.git#<40位commit>&path:dsh-plugin
```

`path:` 只安装 `dsh-plugin` 子目录，不包含 `ida_mcp/` 源码；插件行会先找已安装的 `ida-mcp`，
所以这条路径要求先完成一次：

```bash
uv tool install --force "git+https://github.com/Nacocx/dsh-ida-mcp.git#<40位commit>"
```

两处使用同一个完整 commit SHA。没有安装 `ida-mcp` 时，子目录安装需要把 `IDA_MCP_HOME` 指向一份
checkout；否则启动会报找不到运行时。更新时重新 clone / 重新 `uv tool install` 并换用新的 SHA。

## 离线使用

离线运行的前提是 `ida-mcp` 已经作为独立命令安装过一次（首次安装需要网络，或完整的 uv 缓存）：

```bash
# 推荐：可编辑安装，继续跟随本仓库源码
uv tool install --force --editable /Users/nax/Code/dsh-ida-mcp

# 或：冻结当前源码
uv tool install --force /Users/nax/Code/dsh-ida-mcp
```

`--editable` 会让工具指向本仓库路径；仓库移动后需要重新执行该命令。非 editable 安装则需要在修改
`ida_mcp/` 源码后重新安装。

安装后启动器按以下顺序选择运行时：

1. `IDA_MCP_EXECUTABLE` 指定的可执行文件
2. `<仓库>/.venv/bin/ida-mcp`
3. `uv tool` 的 bin 目录、`~/.local/bin/ida-mcp`、uv tool 环境内的 `ida-mcp`、PATH 中的 `ida-mcp`
4. `uvx --from <仓库> ida-mcp`（需要网络或完整的 uv 缓存）

前三种路径不需要 `uvx`，也不需要网络。验证时用 `--editable` 安装，并在空缓存、最小 PATH 下实测
启动器仍能完成 MCP 握手：

```bash
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"offline-test","version":"1"}}}' \
  | UV_CACHE_DIR=/tmp/empty-uv-cache UV_OFFLINE=1 PATH=/usr/bin:/bin \
    /Users/nax/Code/dsh-ida-mcp/dsh-plugin/bin/launch.sh
```

验证安装本身可独立运行：

```bash
UV_OFFLINE=1 ~/.local/bin/ida-mcp --help
```

如果安装到了自定义 `UV_TOOL_BIN_DIR` 且不在 PATH，设置 `IDA_MCP_EXECUTABLE` 指向该可执行文件。
`uv tool uninstall ida-mcp` 可移除。注意：`uvx --from` 在 uv 缓存完整时也能离线运行；缓存为空时会报
`No solution found ... network was disabled`，所以不要把“未安装 + 空缓存”的 uvx 当作离线方案。

## 工具

| 工具 | 用途 |
| --- | --- |
| `mcp__ida__open_database` | 打开二进制或 `.i64`/`.idb`；`gui: true` 才打开 IDA GUI（需新版 IDA 插件并设 `IDA_NEXUS_IDALIB_ONLY=0`） |
| `mcp__ida__execute_python` | 在已打开的数据库上运行 IDAPython / ida-domain，反编译、反汇编、查交叉引用、改类型等 |
| `mcp__ida__reference` | 查询 ida-domain API 的准确签名与示例；不确定 API 时先用它 |
| `mcp__ida__list_databases` | 列出当前打开的数据库与实例 id |
| `mcp__ida__save_database` | 保存 `.i64`，保留重命名、注释、类型和补丁 |
| `mcp__ida__close_database` | 释放本会话的数据库租约；最后一个租约关闭时 worker 会保存并退出 |

典型流程：`open_database` → `reference` → `execute_python` → `save_database` / `close_database`。

## 启动链路

```text
dsh (mcp-client, stdio)
  └─ /bin/sh -c "内联启动脚本"
       ├─ 已安装 ida-mcp（uv tool / .venv / PATH）→ exec ida-mcp stdio（离线）
       ├─ IDA_MCP_HOME 指向 checkout → exec dsh-plugin/bin/launch.sh
       └─ checkout 存在且 uvx 可用 → uvx --from <checkout> ida-mcp stdio（缓存或网络）
```

`mcp-client` 为服务建立一个 stdio 连接，`startupTimeoutMs: 180000` 为连接与首次工具同步留出 3 分钟。
已安装 `ida-mcp` 时启动不会触发 uv 构建；只有在回退到 `uvx --from` 时才可能首次构建，可先手动执行
`uvx --from /Users/nax/Code/dsh-ida-mcp ida-mcp --help` 预热缓存。

## 配置

以下变量由 **dsh 进程的环境**提供（写进 shell 配置对 GUI 启动的 dsh 不一定生效）：

| 变量 | 说明 |
| --- | --- |
| `IDA_MCP_HOME` | 回退 checkout 的根目录；默认 `/Users/nax/Code/dsh-ida-mcp`，用于 `launch.sh` / uvx 回退 |
| `IDA_MCP_EXECUTABLE` | 指定已安装的 `ida-mcp` 可执行文件；优先级最高，离线时不会调用 uvx |
| `IDA_MCP_UVX` | 未安装 `ida-mcp` 时指定 `uvx`，覆盖 PATH 与常见路径探测 |
| `IDA_NEXUS_IDALIB_ONLY` | 默认置为 `1`，强制使用 idalib worker；设为 `0` 才允许 `idat`/GUI |
| `IDADIR` | IDA 安装目录；未设置时读 `~/.idapro/ida-config.json` |
| `IDAUSR` | IDA 用户目录；默认 `~/.idapro` |
| `IDA_MCP_STATE_DIR` | MCP 会话日志目录；默认 `~/.idapro/mcp` |

启动器默认 `IDA_NEXUS_IDALIB_ONLY=1` 的原因：IDA 内已安装的 ida-nexus 插件可能比本仓库 MCP 使用的
版本旧，`idat` worker 会以 `ida_nexus is missing or too old` 退出。需要 GUI 或 `idat` 时，先用
`uvx ida-hcli plugin upgrade ida-nexus`（或 `ida-mcp`）升级 IDA 内插件，再把
`IDA_NEXUS_IDALIB_ONLY=0` 放进 dsh 进程环境。

## 使用示例

打开测试二进制（首次打开会生成同目录下的 `reverse_demo.i64`）：

```text
mcp__ida__open_database(path="/Users/nax/Code/dsh-ida-mcp/demo/reverse_demo")
```

把下面的代码交给 `mcp__ida__execute_python`：

```python
func = db.functions.get_by_name("verify")
print(db.functions.get_signature(func))
print("\n".join(db.functions.get_pseudocode(func).to_text()))
print("\n".join(db.functions.get_disassembly(func)))
```

返回的 `result` 是代码的值，`stdout` 是 `print` 输出；`stderr` 单独返回。

## 已验证

本目录交付时做了端到端验证：

1. 用 `clang -O1 -g` 编译 [`demo/reverse_demo.c`](../demo/reverse_demo.c) 为 arm64 Mach-O。
2. 通过本插件打开该二进制，`execute_python` 返回 `main` 与 `verify` 的 Hex-Rays 伪代码和
   反汇编；`transform` 被内联进 `verify`，因此函数列表中没有它——这是优化后的正常结果。
3. `close_database` 返回 `final_lease: true`，并生成 `demo/reverse_demo.i64`。
4. 用 `uv tool install --force --editable` 安装后，在 `UV_CACHE_DIR` 指向空目录、`UV_OFFLINE=1`、
   `PATH=/usr/bin:/bin` 的最小环境下，启动器仍完成 MCP 握手；强制重启运行中的 MCP 服务后，
   新进程直接是 `~/.local/bin/ida-mcp stdio --agent=dsh`，工具重新注册并能调用。
5. 用 pnpm 拉取 `git+...#<sha>&path:dsh-plugin` 验证子目录安装，并从安装后的
   `cordis.patch.yml` 提取内联脚本，在空缓存、最小 PATH 下同样完成 MCP 握手。

## 限制

- 6 个工具的名称、说明与输入 schema 会进入每次请求，token 占用明显；不用时请停用。
- 单次工具调用超时 7 分钟（`toolCallTimeoutMs: 420000`）；服务自身的 `open_database` 分析上限
  300 秒、`execute_python` 上限 360 秒。超大二进制或很重的 Python 仍可能先超时，超时后重新
  `open_database` 会复用已生成的 `.i64`。
- 离线运行要求先 `uv tool install` 一次（或保留完整的 uv 缓存）；未安装且缓存为空时，`uvx` 首次
  启动需要网络。已安装 `ida-mcp` 时启动器不会调用 uvx，见[离线使用](#离线使用)。
- 未安装 `ida-mcp` 时，首次 `uvx` 构建受 `startupTimeoutMs: 180000` 的 3 分钟启动预算限制，
  超时会让插件行 `failed`；可先手动执行 `uvx --from /Users/nax/Code/dsh-ida-mcp ida-mcp --help`
  预热缓存。
- 默认无头 idalib，不会自动打开 IDA GUI；`gui: true` 只在用户明确要求时使用，且需要 IDA 内新版
  ida-nexus 插件，并把 `IDA_NEXUS_IDALIB_ONLY=0` 放进 dsh 进程环境。
- `open_database` 会在二进制旁创建 `.i64`；`save_database` 可随时显式保存，关闭最后一个租约时
  worker 也会保存并退出。
- 打开新数据库会占用一个 idalib worker 和一个租约；不用时调用 `close_database` 释放。
- 启动失败时（`failOnStartupError: true`）插件行显示 `failed`：修好 `ida-mcp`/uv/IDA 后重载或
  重启，必要时停用再启用；失败原因在 Host 日志里。
- 二进制、IDB 与反编译输出都按不可信输入处理；不要在未隔离环境里分析不受信任的样本。

## 停用与卸载

停用 bundle 卡片（`IDA MCP bridge`）或它下面的 `MCP client` 行都会移除全部 `mcp__ida__*` 工具；
卸载 bundle 会一并删除该行。行状态只显示阶段，失败原因在 Host 日志里。

## 许可

插件清单与启动器沿用本仓库的 MIT 许可；IDA、Hex-Rays、ida-nexus 与 uv 的许可归各自权利人。
