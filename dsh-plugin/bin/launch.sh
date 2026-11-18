#!/bin/sh
# Launcher for the Hex-Rays IDA MCP server, spawned by
# @deepseek-ai/dsh-mcp-client.
#
# Prefer an already installed `ida-mcp` executable: after one
# `uv tool install`, the server starts with no network access, no package
# index lookup, and no uv cache. Fall back to `uvx --from` for a checkout that
# has not been installed yet.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$script_dir/../.." && pwd)

if [ ! -f "$root/pyproject.toml" ] || [ ! -d "$root/ida_mcp" ]; then
    printf 'ida-mcp: %s is not the ida-mcp checkout; install the bundle from the repository or set IDA_MCP_HOME\n' "$root" >&2
    exit 1
fi

# The ida-nexus plugin installed for IDA may be older than the ida-nexus used
# in this checkout's Python environment. In that case an `idat` worker exits
# with "ida_nexus is missing or too old", so default to a headless idalib
# worker, which runs in this Python environment. Set IDA_NEXUS_IDALIB_ONLY=0
# explicitly to use idat/GUI after upgrading the IDA plugin.
if [ -z "${IDA_NEXUS_IDALIB_ONLY+x}" ]; then
    export IDA_NEXUS_IDALIB_ONLY=1
fi

# Explicit override: fail loudly instead of silently picking another runtime.
if [ -n "${IDA_MCP_EXECUTABLE:-}" ]; then
    if [ ! -x "$IDA_MCP_EXECUTABLE" ]; then
        printf 'ida-mcp: IDA_MCP_EXECUTABLE is not executable: %s\n' "$IDA_MCP_EXECUTABLE" >&2
        exit 1
    fi
    exec "$IDA_MCP_EXECUTABLE" stdio --agent=dsh
fi

# A checkout-local virtualenv is offline-ready and follows source edits.
if [ -x "$root/.venv/bin/ida-mcp" ]; then
    exec "$root/.venv/bin/ida-mcp" stdio --agent=dsh
fi

# `uv tool install` (optionally --editable) is the recommended offline setup.
find_installed() {
    if command -v uv >/dev/null 2>&1; then
        tool_bin=$(uv tool dir --bin 2>/dev/null || true)
        if [ -n "$tool_bin" ] && [ -x "$tool_bin/ida-mcp" ]; then
            printf '%s\n' "$tool_bin/ida-mcp"
            return 0
        fi
    fi
    for candidate in \
        "$HOME/.local/bin/ida-mcp" \
        "$HOME/.local/share/uv/tools/ida-mcp/bin/ida-mcp"
    do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    if command -v ida-mcp >/dev/null 2>&1; then
        command -v ida-mcp
        return 0
    fi
    return 1
}

if ida_mcp=$(find_installed); then
    exec "$ida_mcp" stdio --agent=dsh
fi

# Last resort: let uvx build/run this checkout. This path uses the uv cache
# when offline, so it needs either a warm cache or network on first run.
find_uvx() {
    if [ -n "${IDA_MCP_UVX:-}" ]; then
        printf '%s\n' "$IDA_MCP_UVX"
        return 0
    fi
    if command -v uvx >/dev/null 2>&1; then
        command -v uvx
        return 0
    fi
    for candidate in \
        "$HOME/.local/bin/uvx" \
        /opt/homebrew/bin/uvx \
        /usr/local/bin/uvx
    do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

uvx=$(find_uvx) || {
    printf 'ida-mcp: no installed ida-mcp and uvx not found; run "uv tool install --force --editable %s" while online, or install uv and set IDA_MCP_UVX\n' "$root" >&2
    exit 1
}

# `--from` builds this checkout (rather than PyPI), so edits to ida_mcp/ are
# picked up after uv rebuilds the cached environment.
exec "$uvx" --from "$root" ida-mcp stdio --agent=dsh
