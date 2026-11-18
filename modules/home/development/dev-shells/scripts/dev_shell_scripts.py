"""Shared runtime helpers for generated dev-shell maintenance scripts."""

import pathlib
import re
import shutil
import tempfile


CORP_REFERENCE = re.compile(r"^\$CORP_[A-Z_]+$")


def is_corp_reference(value: object) -> bool:
    """Return whether value is an exact `$CORP_*` reference."""
    return isinstance(value, str) and CORP_REFERENCE.fullmatch(value) is not None


def copy_if_changed(source: pathlib.Path, destination: pathlib.Path, mode: int, parent_mode: int = 0o755) -> None:
    """Atomically copy source only when content changed, enforcing destination mode."""
    if not destination.is_symlink() and destination.is_file() and source.read_bytes() == destination.read_bytes():
        destination.chmod(mode)
        return
    destination.parent.mkdir(mode=parent_mode, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as output:
        temporary = pathlib.Path(output.name)
    try:
        shutil.copyfile(source, temporary)
        temporary.chmod(mode)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def write_text_if_changed(destination: pathlib.Path, content: str, mode: int, parent_mode: int = 0o700) -> None:
    """Atomically write text only when it differs, enforcing destination mode."""
    if not destination.is_symlink() and destination.is_file() and destination.read_text() == content:
        destination.chmod(mode)
        return
    destination.parent.mkdir(mode=parent_mode, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as output:
        output.write(content)
        temporary = pathlib.Path(output.name)
    try:
        temporary.chmod(mode)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)
