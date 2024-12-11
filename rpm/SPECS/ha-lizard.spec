%define version      __VERSION__
%define release      __RELEASE__
%define docdir        %{_datadir}/doc/%{name}

Name:           ha-lizard
Version:        %{version}
Release:        %{release}
Summary:        High Availability for XenServer and Xen Cloud Platform XAPI based dom0s
Packager:       ha-lizard
Group:          Productivity/Clustering/HA
BuildArch:      x86_64
License:        GPLv3
URL:            https://www.ha-lizard.com
Source0:        ha-lizard.tar.gz

%description
HA-lizard provides complete automation for managing Xen server pools utilizing
the XAPI management interface and toolstack (as in Xen Cloud Platform and
XenServer). This hyper-converged software suite delivers full HA features
within a given pool. The design is lightweight with no compromise to system
stability, eliminating the need for traditional cluster management suites. HA
logic includes detection and recovery of failed services and hosts.

Key features:
* Auto-start of failed VMs or any VMs on host boot
* Detection of failed hosts with automated VM recovery
* Orphaned resource cleanup after host removal
* Host removal from pool with service takeover
* Fencing support for HP ILO, XVM, and POOL fencing
* Split-brain prevention using external heuristics and quorum
* HA support for two-host pools
* Simple "bolt-on" support for custom fencing scripts
* Modes for HA on appliances or individual VMs
* Exclusion of selected appliances and VMs from HA logic
* Auto detection of host status for safe maintenance
* Centralized pool configuration stored in XAPI database
* Command-line management for global and host-specific settings
* Enable/disable HA via CLI or GUI (e.g., XenCenter)
* Extensive logging capabilities
* Email alerting on configurable triggers
* Dynamic cluster management for role selection and recovery
* No dependencies - lightweight and stable for XenServer/XCP hosts

This package is designed to enhance the HA capabilities of XenServer/XCP pools
without introducing complexity or compromising system stability.

%prep
echo "Preparing build environment."
%setup -q -c

%build
# No build steps required, placeholder section
echo "Building skipped."

%install
# Install files into the buildroot
mkdir -p %{buildroot}%{_sysconfdir}/ha-lizard
# fence directories
mkdir -p %{buildroot}%{_sysconfdir}/ha-lizard/fence/ILO
mkdir -p %{buildroot}%{_sysconfdir}/ha-lizard/fence/IRMC
mkdir -p %{buildroot}%{_sysconfdir}/ha-lizard/fence/XVM
mkdir -p %{buildroot}%{_libexecdir}/ha-lizard/fence/ILO
mkdir -p %{buildroot}%{_libexecdir}/ha-lizard/fence/IRMC
mkdir -p %{buildroot}%{_libexecdir}/ha-lizard/fence/XVM
# states and logs
mkdir -p %{buildroot}%{_localstatedir}/lib/ha-lizard/state
mkdir -p %{buildroot}%{_localstatedir}/log/ha-lizard
# documentation
mkdir -p %{buildroot}%{docdir}

# Use rsync to copy all files except the 'etc' directory
# TODO: remove scripts folder later
rsync -a scripts/  %{buildroot}%{_sysconfdir}/ha-lizard/scripts/
# Specifically install the bash completion file
install -D -m 644 etc/bash_completion.d/ha-cfg %{buildroot}%{_sysconfdir}/bash_completion.d/ha-cfg
install -D -m 644 etc/ha-lizard/install.params %{buildroot}%{_sysconfdir}/ha-lizard/install.params
install -D -m 644 etc/ha-lizard/ha-lizard.conf %{buildroot}%{_sysconfdir}/ha-lizard/ha-lizard.conf
install -D -m 644 etc/ha-lizard/ha-lizard.init %{buildroot}%{_sysconfdir}/ha-lizard/ha-lizard.init
install -D -m 644 etc/ha-lizard/install.params %{buildroot}%{_sysconfdir}/ha-lizard/ha-lizard.pool.conf
install -D -m 755 etc/init.d/ha-lizard %{buildroot}%{_sysconfdir}/init.d/ha-lizard
install -D -m 755 etc/init.d/ha-lizard-watchdog %{buildroot}%{_sysconfdir}/init.d/ha-lizard-watchdog
install -D -m 755 usr/lib64/ha-lizard/ha-lizard.func %{buildroot}%{_libdir}/ha-lizard/ha-lizard.func
install -D -m 755 usr/bin/check_disk_smart_status %{buildroot}%{_bindir}/check_disk_smart_status
install -D -m 755 usr/bin/email_alert.py %{buildroot}%{_bindir}/email_alert.py
install -D -m 755 usr/bin/ha-cfg %{buildroot}%{_bindir}/ha-cfg
install -D -m 755 usr/bin/ha-lizard.mon %{buildroot}%{_bindir}/ha-lizard.mon
install -D -m 755 usr/bin/ha-lizard.sh %{buildroot}%{_bindir}/ha-lizard.sh
install -D -m 755 usr/bin/host_is_slave %{buildroot}%{_bindir}/host_is_slave
install -D -m 755 usr/bin/initialize_cluster_services %{buildroot}%{_bindir}/initialize_cluster_services
install -D -m 755 usr/bin/recover_fenced_host %{buildroot}%{_bindir}/recover_fenced_host
install -D -m 755 usr/bin/recover_forgotten_host %{buildroot}%{_bindir}/recover_forgotten_host
install -D -m 755 usr/bin/watcher %{buildroot}%{_bindir}/watcher
# fence files
install -D -m 755 usr/libexec/ha-lizard/fence/ILO/ilo_fence.sh %{buildroot}%{_libexecdir}/ha-lizard/fence/ILO/
install -D -m 755 usr/libexec/ha-lizard/fence/ILO/ilo_fence.tcl %{buildroot}%{_libexecdir}/ha-lizard/fence/ILO/
touch %{buildroot}%{_sysconfdir}/ha-lizard/fence/ILO/ILO.hosts
install -D -m 755 usr/libexec/ha-lizard/fence/IRMC/IRMC.sh %{buildroot}%{_libexecdir}/ha-lizard/fence/IRMC/
install -D -m 755 usr/libexec/ha-lizard/fence/IRMC/irmc_*.tcl %{buildroot}%{_libexecdir}/ha-lizard/fence/IRMC/
touch %{buildroot}%{_sysconfdir}/ha-lizard/fence/IRMC/IRMC.hosts
install -D -m 755 usr/libexec/ha-lizard/fence/XVM/xvm_fence.sh %{buildroot}%{_libexecdir}/ha-lizard/fence/XVM/
install -D -m 755 usr/libexec/ha-lizard/fence/XVM/xvm_fence.tcl %{buildroot}%{_libexecdir}/ha-lizard/fence/XVM/
touch %{buildroot}%{_sysconfdir}/ha-lizard/fence/XVM/XVM.hosts
# documentation
install -D -m 644 LICENSE %{buildroot}%{docdir}/
install -D -m 644 CHANGELOG.md %{buildroot}%{docdir}/
install -D -m 644 usr/share/doc/ha-lizard/INSTALL %{buildroot}%{docdir}/
install -D -m 644 usr/share/doc/ha-lizard/HELPFILE %{buildroot}%{docdir}/
install -D -m 644 usr/share/man/man1/ha-cfg.1 %{buildroot}%{_mandir}/man1/ha-cfg.1

%pre
# Placeholder for pre-install actions
exit 0

%post
#!/bin/bash
set -e
echo "Setting up ha-lizard..."

# Set executable permissions
# TODO: remove scripts folder later
find %{_sysconfdir}/ha-lizard/scripts -type f -exec chmod +x {} \;

# TODO: migrate to systemctl
# Enable the services to start on boot
if command -v systemctl &> /dev/null; then
    systemctl daemon-reload
    systemctl enable ha-lizard ha-lizard-watchdog
else
    chkconfig ha-lizard on
    chkconfig ha-lizard-watchdog on
fi

# Create DB Keys
POOL_UUID=`xe pool-list --minimal`
xe pool-param-add uuid=$POOL_UUID param-name=other-config XenCenter.CustomFields.ha-lizard-enabled=false &>/dev/null || true
xe pool-param-add uuid=$POOL_UUID param-name=other-config autopromote_uuid="" &>/dev/null || true
%{_bindir}/ha-cfg insert &>/dev/null

# TODO: Update installation version
#%{_sysconfdir}/ha-lizard/scripts/post_version.py HAL-__VERSION__-__RELEASE__

# Create empty files as ghost files, which will be created during runtime
touch %{_localstatedir}/lib/ha-lizard/state/autopromote_uuid
touch %{_localstatedir}/lib/ha-lizard/state/ha_lizard_enabled
touch %{_localstatedir}/lib/ha-lizard/state/local_host_uuid

echo "ha-lizard setup complete."

%preun
#!/bin/bash
if [ $1 -eq 0 ]; then
    systemctl stop ha-lizard || true
    systemctl stop ha-lizard-watchdog || true
    systemctl disable ha-lizard || true
    systemctl disable ha-lizard-watchdog || true
fi

%postun
#!/bin/bash
if [ $1 -eq 0 ]; then
    rm -f /usr/bin/ha-cfg
    rm -f %{_sysconfdir}/bash_completion.d/ha-cfg
    rm -f %{_sysconfdir}/systemd/system/ha-lizard.service
    rm -f %{_sysconfdir}/systemd/system/ha-lizard-watchdog.service
    rm -f %{_sysconfdir}/init.d/ha-lizard-watchdog
    rm -f %{_sysconfdir}/init.d/ha-lizard-watchdog
    systemctl daemon-reload || true
fi

%files
%defattr(-,root,root,-)

# Configuration files (this will NOT be replaced during upgrades)
%config(noreplace) %{_sysconfdir}/ha-lizard/ha-lizard.conf
%config(noreplace) %{_sysconfdir}/ha-lizard/ha-lizard.init
%config(noreplace) %{_sysconfdir}/ha-lizard/ha-lizard.pool.conf
# fence config files
# TODO: rpmlint complain about the zero-length, but change should be on the scripts
%config(noreplace) %{_sysconfdir}/ha-lizard/fence/ILO/ILO.hosts
%config(noreplace) %{_sysconfdir}/ha-lizard/fence/IRMC/IRMC.hosts
%config(noreplace) %{_sysconfdir}/ha-lizard/fence/XVM/XVM.hosts
# Configuration files (this WILL be replaced during upgrades)
%config %{_sysconfdir}/ha-lizard/install.params
# bash completion
%config %{_sysconfdir}/bash_completion.d/ha-cfg

# Scripts and binaries
%{_sysconfdir}/ha-lizard/scripts

# Libraries
%{_libdir}/ha-lizard/ha-lizard.func


# Init and systemd service files
%{_sysconfdir}/init.d/ha-lizard
%{_sysconfdir}/init.d/ha-lizard-watchdog

# Documentation
%doc %{docdir}/LICENSE
%doc %{docdir}/HELPFILE
%doc %{docdir}/INSTALL
%doc %{docdir}/CHANGELOG.md
%{_mandir}/man1/ha-cfg.1.gz

# State files
# Create the necessary directories
%dir %{_localstatedir}/lib/ha-lizard/state
%ghost %attr(644,root,root) %{_localstatedir}/lib/ha-lizard/state/autopromote_uuid
%ghost %attr(644,root,root) %{_localstatedir}/lib/ha-lizard/state/ha_lizard_enabled
%ghost %attr(644,root,root) %{_localstatedir}/lib/ha-lizard/state/local_host_uuid

# Include the python and bash script in /usr/bin/
%{_bindir}/check_disk_smart_status
%{_bindir}/email_alert.py
%{_bindir}/ha-cfg
%{_bindir}/ha-lizard.mon
%{_bindir}/ha-lizard.sh
%{_bindir}/host_is_slave
%{_bindir}/initialize_cluster_services
%{_bindir}/recover_fenced_host
%{_bindir}/recover_forgotten_host
%{_bindir}/watcher

# Application-specific executable files
%{_libexecdir}/ha-lizard/fence/ILO/ilo_fence.sh
%{_libexecdir}/ha-lizard/fence/ILO/ilo_fence.tcl
%{_libexecdir}/ha-lizard/fence/IRMC/IRMC.sh
%{_libexecdir}/ha-lizard/fence/IRMC/irmc_powerstate.tcl
%{_libexecdir}/ha-lizard/fence/IRMC/irmc_reset.tcl
%{_libexecdir}/ha-lizard/fence/IRMC/irmc_start.tcl
%{_libexecdir}/ha-lizard/fence/IRMC/irmc_stop.tcl
%{_libexecdir}/ha-lizard/fence/XVM/xvm_fence.sh
%{_libexecdir}/ha-lizard/fence/XVM/xvm_fence.tcl

# TODO: add a logrotate
# Create /var/log/ha-lizard directory
%dir %{_localstatedir}/log/ha-lizard

# INFO: Do not put anything after the changelog macro. github actions will add the changelog there.
%changelog
