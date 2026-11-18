#!/usr/bin/env zsh
# Initialize a Workmux-created worktree from its base checkout.
# corp-project.nix substitutes project paths, tool paths, and setup command.

set -eu
setupPath="@coreutils@/bin:@direnv@/bin:/usr/bin:/bin:$PATH"
base="$HOME/git/@projectId@"

link_from_base() {
  local relative_path="$1" source_path target_path
  source_path="$base/$relative_path"
  target_path="$PWD/$relative_path"
  [ -e "$source_path" ] || [ -L "$source_path" ] || return 0
  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    echo "workmux bootstrap: preserving existing $relative_path" >&2
    return 0
  fi
  @coreutils@/bin/mkdir -p "$( @coreutils@/bin/dirname "$target_path" )"
  @coreutils@/bin/ln -sfn "$source_path" "$target_path"
}

link_from_base .opencode
link_from_base .claude/settings.local.json
link_from_base .envrc
link_from_base .env.local
for devkitPath in @devkitShared@; do
  link_from_base ".devkit/$devkitPath"
done

@coreutils@/bin/env PATH="$setupPath" @bash@/bin/bash -c @projectSetup@
