{ lib, stdenv, runCommand, codex, ripgrep, bubblewrap }:
# Adds the on-disk package layout `features.daemon_auto_start` requires (codex-rs/install-context/src/lib.rs), post-processing the cached build so nothing recompiles.
runCommand "codex-${codex.version}"
  {
    pname = "codex";
    inherit (codex) version meta passthru;
  }
  (''
    mkdir -p "$out"
    cp -r ${codex}/. "$out"/
    chmod -R u+w "$out"

    if [ -e "$out/bin/.codex-wrapped" ]; then
      rm -f "$out/bin/codex"
      cp "$out/bin/.codex-wrapped" "$out/bin/codex"
      rm -f "$out/bin/.codex-wrapped"
      chmod 0555 "$out/bin/codex"
    fi

    cat > "$out/codex-package.json" <<EOF
    {"version": "${codex.version}", "target": "${stdenv.hostPlatform.rust.rustcTarget}", "entrypoint": "bin/codex"}
    EOF

    install -d -m 0755 "$out/codex-path"
    install -m 0555 ${ripgrep}/bin/rg "$out/codex-path/rg"
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    install -d -m 0755 "$out/codex-resources"
    install -m 0555 ${bubblewrap}/bin/bwrap "$out/codex-resources/bwrap"
  '')
