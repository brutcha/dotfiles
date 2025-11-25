{ utils }:
#
# Docker Desktop for macOS
#
# Complete Docker environment with GUI and daemon.
# Installed via Homebrew cask for easier updates. VM configuration managed by Docker Desktop.
#
utils.darwin.mkBrewCask { caskName = "docker-desktop"; }
