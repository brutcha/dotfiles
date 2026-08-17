import subprocess

from menu_common import menu_guard

menu_guard("network")
subprocess.run(["networkmanager_dmenu"], check=False)
