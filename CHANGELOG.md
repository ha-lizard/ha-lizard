# Changelog

<!-- markdownlint-disable line-length no-duplicate-heading -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.4.0] - 2024-12-01

- Initial release for GitHub.

## [2.3.3] - 2024-11-01

- Code preparation for moving project to GitHub.
- No logic changes, only comments added/removed.

## [2.3.2] - 2024-02-01

- Updated email handler for `vm_backup` and exports to better handle SSL.

## [2.3.1] - 2021-09-01

- Addressed issue with Citrix Hotfix XS82E031, which removed HTTP access to the management network static webpage.
  Fix maintains backward compatibility and switches to HTTPS when HTTP fails.
- Added `<version>` parameter to `ha-cfg` CLI tool to display the version number.

## [2.3.0] - 2021-02-01

- Verified interoperability with XCP-ng/Citrix Hypervisor version 8.2.
- Updated `vm_backup` script to skip processing a VM that fails to snapshot.
- Bug fix #2210: Resolved broken home pool UUID validation for VM migrations.
- Improved regex string validation in `vm_backup` script for backup retention.
- Added detailed cluster service status to `ha-cfg` CLI tool.
- Significant changes for hyperconverged 2-host pools using HA-Lizard + iSCSI-HA:
  - Additional checks to prevent fencing a peer in two-node pools if the replication network is active while the management network is unreachable.

## [2.2.3] - 2019-10-01

- Suppressed non-critical errors from `smartctl` in disk SMART error checks.

## [2.2.2] - 2019-09-01

- Verified interoperability with XCP-ng/Citrix version 8.
- Fixed email handler issue with SSL connections to SMTP servers.
- Resolved XenAPI SSL error introduced in XCP/XS version 8 by switching to HTTP for self-signed certificates.

## [2.2.1] - 2019-05-01

- Improved tracking of scenarios where no slaves are available for pool recovery.
- `autoselect_slave` now functions regardless of HA state.

## [2.2.0] - 2018-10-01

- Introduced VM locking mechanism to prevent duplicate starts during migration across pools.
- Changed behavior for newly created VMs under default settings (`global_vm_ha=1`), allowing manual starts before HA activation.
- Updated peer network connectivity checks for XCP-ng 7.6+.
- Added alert generation for pool-level HA actions and warnings.
- Updated VM backup logic to hide CIFS passwords in logs.
- Added CLI options for managing HA-Lizard alerts.
- Introduced hourly disk SMART checks with alerts.
- Improved debug logs with main PID for better readability.
- Verified compatibility with XenServer 7.x, XCP-ng 7.5, and earlier versions.

## [2.1.4] - 2017-08-01

- Bug fix: Updated init to wait for XAPI to fully initialize before starting HA-Lizard.

## [2.1.3] - 2016-12-01

- Added new CLI actions: `ha-status`, `ha-enable`, and `ha-disable`.
- Improved tab completion and restricted snapshot listing in commands.
- Enhanced CLI speed for `get-vm-ha`.
- Unified codebase for compatibility with XenServer 6.x environments.
- Improved host selection logic and legacy XenOps support.

## [2.1.2] - 2016-11-01

- Improved VM recovery time by skipping responses from failed slaves.
- Added dynamic timeout handling for API calls.
- Enhanced handling of suspended HA mode for slaves.
- Fixed rare issues with missing or corrupted host UUIDs and hung VMs.

## [2.1.1] - 2016-11-01

- Bug fixes for timed-out API calls and CLI handling.
- Improved slave validation and dynamic master recovery timing.
- Added CLI option `restore-default` to reset configurations.

## [2.1.0] - 2016-11-01

- Enhanced UUID detection and master tracking logic.
- Prevented master maintenance mode under HA-Lizard.
- Improved VM evacuation from masters losing their management link.
- Addressed XenServer bug XSO-586.
- Updated CLI displays and email alerts.

## [2.0] - 2016-07-01

- Updated for compatibility with XenServer 7.
- Enhanced error capturing, logging, and systemd support for CentOS 7-style dom0.
- Updated init scripts to always start watchdog.

## [1.9.1.1] - 2016-11-01

- Updated various functions to remove dependency on `name-label=hostname`.

## [1.9.1] - 2016-10-01

- Improved logic for determining a host's UUID, allowing hostname modifications.
- Added master management link state tracking for clean re-entry into pools.
- Prevented masters from entering maintenance mode while HA-Lizard is enabled.
- Enhanced management link state checks during slave status evaluations.
- Fixed HA disablement caused by stale database entries after master fencing.
- Improved handling of VMs on masters that lose their management link.
- Enhanced CLI status displays and email alerts.

## [1.8.9] - 2016-06-01

- Added self-fencing logic for two-node pools to handle management network failures.
- Fixed erroneous email alerts triggered by appliance descriptions.

## [1.8.8] - 2015-09-01

- Improved pool state caching during HA-disabled scenarios.
- Reduced recovery time by optimizing host failure checks.
- Fixed `get-vm-ha` output for VMs with name labels containing spaces.
- Enhanced global settings updates on all pool members, regardless of HA status.

## [1.8.7] - 2015-05-01

- Added Fujitsu iRMC fencing support.
- Introduced tab-completion for the `ha-cfg` CLI with dynamic context-aware functionality.
- Resolved display bug in `get-vm-ha` when the VM name contained spaces.
- Fixed installer permissions issue for fencing methods.

## [1.8.5] - 2015-02-01

- Preliminary validation for XenServer 6.5 completed.
- Improved CLI insert functionality for automated installation.
- Simplified installation script requiring less user input.
- Added `--nostart` argument to the installer.
- Fixed improper command substitution.
- Enhanced email handler and added new debug/test options for email troubleshooting.
- Added new email configuration parameters (`smtp_server`, `smtp_port`, `smtp_user`, `smtp_pass`).

## [1.7.8] - 2014-07-01

- Made CLI arguments for `set` case-insensitive.
- Added validation to detect and warn if XenServer HA is enabled, disabling HA-Lizard when detected.

## [1.7.7] - 2014-05-01

- Optimized default installation parameters for typical two-node setups.

## [1.7.6] - 2013-12-01 (Patch Release)

- Fixed improperly handled exit statuses during fencing.
- Updated fencing logic to ensure proper quorum and fencing behavior.
- Added self-fencing for slaves that fail to achieve quorum.
- Improved handling of dangling logger processes.
- Updated init scripts to manage logger processes effectively.
- Introduced HA suspension for self-fenced slaves.
- Enhanced CLI warnings and email alerts for HA suspension events.
- Added tools and documentation for re-enabling HA after suspension.

## [1.7.2] - 2013-10-01

- Replaced email alert logic to prevent hangs when the network or DNS is down.
- Suppressed unnecessary email alerts during HA-Lizard initialization.
- Introduced a Python-based MTA, removing the dependency on `mailx`.
- Resolved a UUID array parsing issue when using `OP_MODE=1` to manage appliances.

## [1.6.42.3] - 2013-08-06

- Validated support for XenServer 6.2.
- Updated the `ha-cfg` tool with warnings for required resets when monitor timers are updated.
- Warned users of the deprecation of `FENCE_HOST_FORGET`.
- Enhanced email alert handling to prevent duplicate messages with a configurable timeout (default: 60 minutes).
- Email alerts now include the VM name-label and UUID.
- Improved recovery from system crashes that could erase the configuration cache.
- Resolved a file descriptor leak causing interrupted system calls that closed TCP sockets.

## [1.6.41.4] - 2013-07-10

- Fixed an issue in two-node pools where fencing failed due to a safety mechanism preventing fencing when a master couldn't reach any slaves.

## [1.6.41] - 2013-06-27

- Enhanced host failure handling. It is no longer mandatory to "forget host" to recover the pool. A failed host is disabled automatically, preventing attempts to start VMs on it.
- Added an optional installation counter to track project success.
- Improved installer handles upgrades better and resolves its relative path more reliably.

## [1.6.40.4] - 2013-05-23

- Resolved minor cosmetic issues.
- Fixed incorrect version number display in init script status.
- Updated default settings to more common values.
- Improved installation instructions.
- Corrected a missing variable in the XVM Expect/TCL script.

## [1.6.40.2] - 2013-05-01

Initial public release.
