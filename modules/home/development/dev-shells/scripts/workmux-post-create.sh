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
  local relative_path="$1" source_path
  source_path="$base/$relative_path"
  [ -e "$source_path" ] || [ -L "$source_path" ] || return 0
  @python@ @safeLink@ "$worktree_root" "$relative_path" "$source_path"
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
  @direnv@/bin/direnv allow "$managed_envrc"
  @coreutils@/bin/env PATH="$setupPath" @direnv@/bin/direnv exec "${managed_envrc:h}" @bash@/bin/bash -c @projectSetup@
else
  echo "workmux bootstrap: .envrc is not the managed file; skipping direnv approval and project setup" >&2
fi
