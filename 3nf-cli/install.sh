#!/bin/sh
# Requires GitHub CLI (https://cli.github.com) authenticated with repo read access.
set -eu

main() {
    for command in gh curl tar; do
        if ! command -v "$command" >/dev/null 2>&1; then
            printf 'Missing %s. Install it before running this installer.\n' "$command" >&2
            exit 1
        fi
    done
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        printf 'Authenticate first with: gh auth login --hostname github.com\n' >&2
        exit 1
    fi

    commit=$(gh api --hostname github.com repos/mporenta/3nf-cli/git/ref/heads/main --jq '.object.sha' </dev/null)
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT
    trap 'exit 1' HUP INT TERM

    if ! command -v uv >/dev/null 2>&1; then
        if [ -x "$HOME/.local/bin/uv" ]; then
            PATH="$HOME/.local/bin:$PATH"
            export PATH
        else
            printf 'Installing uv...\n'
            curl -LsSf https://astral.sh/uv/install.sh -o "$temporary/uv-install.sh"
            UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 sh "$temporary/uv-install.sh" </dev/null
            PATH="$HOME/.local/bin:$PATH"
            export PATH
        fi
    fi

    printf 'Downloading mporenta/3nf-cli at %s...\n' "$commit"
    gh api --hostname github.com "repos/mporenta/3nf-cli/tarball/$commit" > "$temporary/source.tar.gz" </dev/null
    mkdir "$temporary/source"
    tar -xzf "$temporary/source.tar.gz" -C "$temporary/source" --strip-components=1

    # uv installs Python 3.12 if needed and resolves dependencies from pyproject.toml.
    uv tool install --python 3.12 --force "$temporary/source" </dev/null
    bin=$(uv tool dir --bin)
    "$bin/nf3" --version
    "$bin/nf3" skills list --json >/dev/null
    printf 'Installed nf3 and fdprofiler in %s.\n' "$bin"
    case ":$PATH:" in
        *":$bin:"*) ;;
        *) printf 'Add this directory to your shell PATH: export PATH="%s:$PATH"\n' "$bin" ;;
    esac
    printf 'Run: nf3 --help\n'
}

main "$@"
