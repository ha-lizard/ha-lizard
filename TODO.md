# TODO

## Legacy Scripts

The scripts previously located in `/etc/ha-lizard/scripts` have been moved to `/usr/libexec/ha-lizard/scripts`. These include older, potentially outdated scripts that may no longer be necessary:

- [**install**](src/usr/libexec/ha-lizard/scripts/install): Installation is now managed through RPM packages.
- [**post_version.py**](src/usr/libexec/ha-lizard/scripts/post_version.py): Needs refactoring, and user consent should be checked for sending anonymous data.
- [**timeout**](src/usr/libexec/ha-lizard/scripts/timeout): Bash provides a built-in `timeout` that should be used instead.
- [**uninstall**](src/usr/libexec/ha-lizard/scripts/uninstall): Uninstallation is handled via RPM packages.
- [**vm_backup.sh**](src/usr/libexec/ha-lizard/scripts/vm_backup.sh): This script may belong to a different project, as it covers a separate topic.

For now, these will remain unchanged until the new version development begins.
