{ config, lib, ... }:
#
# Karabiner-Elements service path fix
#
# This module fixes the LaunchAgent plist paths in nix-darwin's karabiner-elements service.
# The upstream nix-darwin service module expects plist files at incorrect paths.
#
# Issue: The service looks for plists at:
#   ${cfg.package}/Library/LaunchAgents/org.pqrs.karabiner.agent.*.plist
#
# But actual files are located at:
#   ${cfg.package}/Library/Application Support/org.pqrs/Karabiner-Elements/
#   Karabiner-Elements Non-Privileged Agents.app/Contents/Library/LaunchAgents/
#   org.pqrs.service.agent.*.plist
#
# This fix uses mkForce to override the incorrect paths with the correct ones,
# allowing the service to properly install and start all Karabiner components
# including the driver and permissions setup.
#
with lib;

let
  cfg = config.services.karabiner-elements;
  
  # Helper to construct correct plist path
  plistPath = name: "${cfg.package}/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Elements Non-Privileged Agents.app/Contents/Library/LaunchAgents/${name}.plist";
in

{
  config = mkIf cfg.enable {
    # Override the incorrect paths from the original service module
    environment.userLaunchAgents = {
      "org.pqrs.karabiner.agent.karabiner_grabber.plist".source = mkForce (plistPath "org.pqrs.service.agent.karabiner_grabber");
      "org.pqrs.karabiner.agent.karabiner_observer.plist".source = mkForce (plistPath "org.pqrs.service.agent.karabiner_session_monitor");
      "org.pqrs.karabiner.karabiner_console_user_server.plist".source = mkForce (plistPath "org.pqrs.service.agent.karabiner_console_user_server");
    };
  };
}
