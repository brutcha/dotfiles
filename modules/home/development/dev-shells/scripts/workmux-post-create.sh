#!/usr/bin/env zsh
# Initialize a Workmux-created worktree from its base checkout.
# corp-project.nix substitutes project paths, tool paths, and setup command.

set -eu
setupPath="@coreutils@/bin:@direnv@/bin:/usr/bin:/bin:$PATH"
base="$HOME/git/@projectId@"
if ! IFS= read -r -d '' worktree_root < <(@coreutils@/bin/realpath -m -z -- "$PWD"); then
  echo "workmux bootstrap: unable to resolve worktree root" >&2
  exit 1
fi

link_from_base() {
  local relative_path="$1" source_path target_path
  source_path="$base/$relative_path"
  target_path="$PWD/$relative_path"
  [ -e "$source_path" ] || [ -L "$source_path" ] || return 0
  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    echo "workmux bootstrap: preserving existing $relative_path" >&2
    return 0
  fi
  local target_parent target_parent_real
  target_parent="$( @coreutils@/bin/dirname "$target_path" )"
  if ! IFS= read -r -d '' target_parent_real < <(@coreutils@/bin/realpath -m -z -- "$target_parent"); then
    echo "workmux bootstrap: unable to resolve parent for $relative_path" >&2
    return 0
  fi
  case "$target_parent_real/" in
    "$worktree_root/"*) ;;
    *)
      echo "workmux bootstrap: refusing to create $relative_path outside the worktree" >&2
      return 0
      ;;
  esac
  @coreutils@/bin/mkdir -p "$target_parent"
  @coreutils@/bin/ln -sfn "$source_path" "$target_path"
}

link_from_base .opencode
link_from_base .claude/settings.local.json
link_from_base .envrc
link_from_base .env.local
for devkitPath in @devkitShared@; do
  link_from_base ".devkit/$devkitPath"
done

managed_envrc="$HOME/.local/share/dev-shells/@projectId@/.envrc"
if [ -f .envrc ] && @coreutils@/bin/cmp -s .envrc "$managed_envrc"; then
  @coreutils@/bin/env PATH="$setupPath" @bash@/bin/bash -c @projectSetup@
else
  echo "workmux bootstrap: .envrc is not the managed file; skipping direnv approval and project setup" >&2
fi
