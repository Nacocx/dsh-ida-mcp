# Hex-Rays IDA MCP · DeepSeek Harness 插件

把本仓库的 Hex-Rays IDA MCP 服务（stdio）接入 DeepSeek Harness（下称 dsh），注册为
`mcp__ida__<tool>`。**安装插件即可，不需要另外 clone 仓库，也不需要手动
`uv tool install`**：没有现成运行时时，插件第一次启动会在私有缓存中安装运行时；之后直接使用本地运行时。

仅支持 macOS/Linux。

## 组成

| 文件 | 作用 |
| --- | --- |
| `package.json` | bundle 清单：`dsh.bundle.patch` 指向本目录的 patch，并导出 locale 与图标 |
| `cordis.patch.yml` | 插入一条 `mcp-client` 配置行：`serverName: ida`、stdio，以及自举启动脚本 |
| `locale/*.json` | bundle 卡片的标题、说明与详情文档路径（中英双语） |
| `docs/` | 详情页的一句话说明与配图 |
| `icon.svg` | bundle 图标（36×36，原创） |
| `../demo/` | 端到端测试用的 C 程序与编译产物，不在 bundle 包内 |

卡片下的插件行由 `@deepseek-ai/dsh-mcp-client` 提供，标题沿用上游的 `MCP client`，图标是面板默认图形；
bundle 的标题与图标只出现在 bundle 卡片上。

## 它是怎么自举的

启动脚本按顺序选择运行时：

1. `IDA_MCP_EXECUTABLE` 指定的可执行文件
2. `<IDA_MCP_RUNTIME_DIR>/runtime/bin/ida-mcp`（插件自己的私有运行时，已安装且版本匹配时）
3. PATH 中的 `ida-mcp`、`~/.local/bin/ida-mcp`、uv tool 环境中的 `ida-mcp`
4. `IDA_MCP_HOME` 指向的本地 checkout（`.venv/bin/ida-mcp`，或 `uvx --from <checkout>`）
5. 以上都没有：用 `uv tool install` 把 `IDA_MCP_SOURCE` 安装到私有运行时目录，然后执行

私有运行时默认在 `${XDG_CACHE_HOME:-~/.cache}/ida-mcp-dsh/runtime`，不会写全局 `uv tool`
目录；第一次启动需要网络（或完整的 uv 缓存），之后完全本地运行。

## 前置条件

- IDA 9.4 或更高版本，且许可证可用。ida-nexus 通过 `IDADIR` 或
  `~/.idapro/ida-config.json` 的 `Paths.ida-install-dir` 找到 IDA；本机为
  `/Applications/IDA Professional 9.4.app`。
- [uv](https://docs.astral.sh/uv/) 和 `git`：第一次启动时用它们从本仓库安装私有运行时。
  已预装 `ida-mcp` 或已有本地 checkout 时，运行时不再需要网络。
- 仅 macOS/Linux。

## 安装

在 dsh 的 **Plugins → Add plugin** 中填入 bundle 的绝对路径或 git spec，安装返回 applied 后调用
`mcp__ida__list_databases` 验证。第一次启动会比较慢（下载/构建运行时），之后启动很快。

本机从现有 checkout 安装：

```text
/Users/nax/Code/dsh-ida-mcp/dsh-plugin
```

从 Git 安装（推荐用于新机器）：

```text
git+https://github.com/Nacocx/dsh-ida-mcp.git#<40位commit>&path:dsh-plugin
```

Git spec 只安装 `dsh-plugin` 子目录；运行时由插件自己从本仓库安装，不需要先 clone，也不需要先
`uv tool install`。bundle 的 git spec 用完整 commit SHA；运行时默认从
`git+https://github.com/Nacocx/dsh-ida-mcp.git@main` 安装，如需固定版本，把 `IDA_MCP_SOURCE`
设为同一个 commit。

bundle 以 `link:` 指向本地目录时，**移动仓库后需要从新路径重新安装**；Git 安装不受影响。

## 离线使用

第一次启动时，自举步骤需要网络或完整的 uv 缓存。自举完成后，私有运行时已在磁盘上：

```text
${XDG_CACHE_HOME:-~/.cache}/ida-mcp-dsh/runtime/bin/ida-mcp
```

之后的启动不访问网络。可以用下面的命令确认私有运行时存在：

```bash
UV_OFFLINE=1 "${XDG_CACHE_HOME:-$HOME/.cache}/ida-mcp-dsh/runtime/bin/ida-mcp" --help
```

如果目标机器要求**第一次启动也不能联网**，二选一：

```bash
# 1. 预先在全局 uv tool 中安装运行时；插件会优先使用它
uv tool install --force "git+https://github.com/Nacocx/dsh-ida-mcp.git"

# 2. 或用 IDA_MCP_EXECUTABLE 指向任何可用的 ida-mcp 可执行文件
```

在已经装好运行时的机器上，之后即使断网、`uv` 不在 PATH，插件也能启动。清理
`~/.cache/ida-mcp-dsh` 后，下一次启动会重新自举。

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
  └─ /bin/sh -c "内联自举脚本"
       ├─ 已安装 ida-mcp / 私有运行时 / .venv → exec（离线）
       ├─ 本地 checkout → uvx --from <checkout>
       └─ 都没有 → uv tool install <IDA_MCP_SOURCE> 到私有缓存 → exec
            └─ idalib worker
```

`mcp-client` 为服务建立一个 stdio 连接，`startupTimeoutMs: 600000` 为首次启动的运行时安装留出
10 分钟；之后的连接在几秒内完成。`failOnStartupError: true` 让自举失败直接显示为插件行 `failed`，
原因在 Host 日志里。

## 配置

以下变量由 **dsh 进程的环境**提供（写进 shell 配置对 GUI 启动的 dsh 不一定生效）：

| 变量 | 说明 |
| --- | --- |
| `IDA_MCP_EXECUTABLE` | 指定任意 `ida-mcp` 可执行文件；优先级最高 |
| `IDA_MCP_SOURCE` | 自举来源；默认 `git+https://github.com/Nacocx/dsh-ida-mcp.git@main`，可设为固定 commit、镜像 URL 或本地 checkout |
| `IDA_MCP_RUNTIME_DIR` | 私有缓存根目录；默认 `${XDG_CACHE_HOME:-~/.cache}/ida-mcp-dsh`，运行时装在 `<该目录>/runtime` |
| `IDA_MCP_HOME` | 本地 checkout 的根目录，仅供本地开发回退；默认 `/Users/nax/Code/dsh-ida-mcp` |
| `IDA_NEXUS_IDALIB_ONLY` | 默认置为 `1`，强制使用 idalib worker；设为 `0` 才允许 `idat`/GUI |
| `IDADIR` | IDA 安装目录；未设置时读 `~/.idapro/ida-config.json` |
| `IDAUSR` | IDA 用户目录；默认 `~/.idapro` |
| `IDA_MCP_STATE_DIR` | MCP 会话日志目录；默认 `~/.idapro/mcp` |

启动脚本默认 `IDA_NEXUS_IDALIB_ONLY=1` 的原因：IDA 内已安装的 ida-nexus 插件可能比本仓库 MCP
使用的版本旧，`idat` worker 会以 `ida_nexus is missing or too old` 退出。需要 GUI 或 `idat` 时，
先用 `uvx ida-hcli plugin upgrade ida-nexus`（或 `ida-mcp`）升级 IDA 内插件，再把
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

1. 用 `clang -O1 -g` 编译 [`demo/reverse_demo.c`](../demo/reverse_demo.c) 为 arm64 Mach-O。
2. 通过本插件打开该二进制，`execute_python` 返回 `main` 与 `verify` 的 Hex-Rays 伪代码和
   反汇编；`transform` 被内联进 `verify`，因此函数列表中没有它——这是优化后的正常结果。
3. `close_database` 返回 `final_lease: true`，并生成 `demo/reverse_demo.i64`。
4. 在一个没有 `ida-mcp`、没有本地 checkout 的空 `HOME` 中，用空 uv 缓存启动内联脚本：它自动从
   Git 安装私有运行时并完成 MCP 握手；第二次启动在 `UV_OFFLINE=1`、`PATH=/usr/bin:/bin`（没有
   `uv`）下仍完成握手。
5. 用 pnpm 拉取 `git+...#<sha>&path:dsh-plugin` 验证子目录安装，并从安装后的
   `cordis.patch.yml` 提取内联脚本，在空缓存、最小 PATH 下完成握手。
6. 用临时 DSH bundle 走真实的 `mcp-client` 首次启动：`HOME` 为空、`PATH` 无 `ida-mcp`、
   `IDA_MCP_HOME=/nonexistent`，插件行自动安装私有运行时并注册 `mcp__idaboot__*`；
   `list_databases` 调用成功。测试后已移除临时 bundle。

## 限制

- 第一次启动需要网络或完整的 uv 缓存来安装运行时；之后离线。首次安装受
  `startupTimeoutMs: 600000` 的 10 分钟预算限制，超时插件行会 `failed`。
- 自举默认从 GitHub 的 `main` 拉取运行时。生产环境建议把 `IDA_MCP_SOURCE` 固定到完整 commit
  或内部镜像；已预装 `ida-mcp` 时不会自举。
- 6 个工具的名称、说明与输入 schema 会进入每次请求，token 占用明显；不用时请停用。
- 单次工具调用超时 7 分钟（`toolCallTimeoutMs: 420000`）；服务自身的 `open_database` 分析上限
  300 秒、`execute_python` 上限 360 秒。超大二进制或很重的 Python 仍可能先超时，超时后重新
  `open_database` 会复用已生成的 `.i64`。
- 默认无头 idalib，不会自动打开 IDA GUI；`gui: true` 只在用户明确要求时使用，且需要 IDA 内新版
  ida-nexus 插件，并把 `IDA_NEXUS_IDALIB_ONLY=0` 放进 dsh 进程环境。
- `open_database` 会在二进制旁创建 `.i64`；`save_database` 可随时显式保存，关闭最后一个租约时
  worker 也会保存并退出。
- 打开新数据库会占用一个 idalib worker 和一个租约；不用时调用 `close_database` 释放。
- 启动失败时（`failOnStartupError: true`）插件行显示 `failed`：检查网络/uv/Git/IDA 后重载或
  重启，必要时停用再启用；失败原因在 Host 日志里。
- 二进制、IDB 与反编译输出都按不可信输入处理；不要在未隔离环境里分析不受信任的样本。

## 停用与卸载

停用 bundle 卡片（`IDA MCP bridge`）或它下面的 `MCP client` 行都会移除全部 `mcp__ida__*` 工具；
卸载 bundle 会一并删除该行。私有运行时不会被自动删除，需要时手动移除
`${XDG_CACHE_HOME:-~/.cache}/ida-mcp-dsh`。

## 许可

插件清单与内联启动脚本沿用本仓库的 MIT 许可；IDA、Hex-Rays、ida-nexus 与 uv 的许可归各自权利人。
