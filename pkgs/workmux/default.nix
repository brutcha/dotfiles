{ helpers }:
#
# Workmux — Git worktree and tmux workflow tool for macOS.
#
# Installed via Homebrew formula because the pinned nixpkgs revision does not
# provide it.
#
helpers.darwin.mkBrewPkg { formulaName = "workmux"; }
