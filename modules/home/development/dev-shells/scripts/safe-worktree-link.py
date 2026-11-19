"""Create a base-checkout symlink without following worktree path components."""

import os
import pathlib
import stat
import sys
from typing import NoReturn


def fail(message: str) -> NoReturn:
    print(f"workmux bootstrap: {message}", file=sys.stderr)
    raise SystemExit(0)


if len(sys.argv) != 4:
    raise SystemExit("usage: safe-worktree-link ROOT RELATIVE_PATH SOURCE")

root, relative_path, source = map(pathlib.Path, sys.argv[1:])
parts = relative_path.parts
if relative_path.is_absolute() or not parts or any(part in {"", ".", ".."} for part in parts):
    fail(f"refusing unsafe path {relative_path}")

flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
try:
    directory_fd = os.open(root, flags)
except OSError as error:
    fail(f"unable to open worktree root: {error}")

try:
    for component in parts[:-1]:
        try:
            os.mkdir(component, mode=0o755, dir_fd=directory_fd)
        except FileExistsError:
            pass
        try:
            child_fd = os.open(component, flags, dir_fd=directory_fd)
        except OSError as error:
            fail(f"refusing to create {relative_path}: {error}")
        os.close(directory_fd)
        directory_fd = child_fd

    target = parts[-1]
    try:
        status = os.stat(target, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        status = None
    if status is not None and not stat.S_ISLNK(status.st_mode):
        fail(f"preserving existing {relative_path}")
    if status is not None:
        os.unlink(target, dir_fd=directory_fd)
    os.symlink(source, target, dir_fd=directory_fd)
finally:
    os.close(directory_fd)
