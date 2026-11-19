#!/bin/sh

api_key_file="$HOME/.local/share/opencode-nix/secrets/context7-api-key"

if [ ! -s "$api_key_file" ]; then
  echo "Context7 API key is unavailable at $api_key_file" >&2
  exit 1
fi

printf '{"Authorization":"Bearer %s"}\n' "$(cat "$api_key_file")"
