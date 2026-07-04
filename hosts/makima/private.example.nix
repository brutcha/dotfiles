# Template — copy to ~/.config/dotfiles/private.nix and fill in real values.
# Consumed by flake.nix via `import` under --impure. Non-secret personal
# metadata only — no passwords here. The Exchange account authenticates
# interactively via OAuth2 (browser + MFA) on first connect.
{
  user = {
    name  = "Full Name";
    email = "mailbox@corp.example"; # primary mailbox address (From:)
    login = "login@corp.example"; # Microsoft sign-in UPN (server username)
  };
}
