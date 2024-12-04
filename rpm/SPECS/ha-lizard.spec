%define version      __VERSION__
%define release      __RELEASE__
%define buildarch    noarch
%define name         ha-lizard

Name:           %{name}
Version:        %{version}
Release:        %{release}
Summary:        High Availability for XenServer and Xen Cloud Platform XAPI based dom0s
Packager:       ha-lizard
Group:          Productivity/Clustering/HA
BuildArch:      noarch
License:        GPLv3+
URL:            https://www.ha-lizard.com
Source0:        ha-lizard.tar.gz

%description
HA-lizard provides complete automation for managing Xen server pools utilizing the XAPI management interface and toolstack (as in Xen Cloud Platform and XenServer). This hyper-converged software suite delivers full HA features within a given pool. The design is lightweight with no compromise to system stability, eliminating the need for traditional cluster management suites. HA logic includes detection and recovery of failed services and hosts.

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

This package is designed to enhance the HA capabilities of XenServer/XCP pools without introducing complexity or compromising system stability.

%prep
echo "Preparing build environment."
%setup -q -c

%build
# No build steps required, placeholder section
echo "Building skipped."

%install
# Install files into the buildroot
mkdir -p %{buildroot}%{_sysconfdir}/ha-lizard
cp -Par * %{buildroot}%{_sysconfdir}/ha-lizard
rm -rf %{buildroot}%{_sysconfdir}/ha-lizard/rpm

%pre
# Placeholder for pre-install actions
exit 0

%post
#!/bin/bash
set -e
echo "Setting up ha-lizard..."

# Set executable permissions
find %{_sysconfdir}/ha-lizard -type f -name "*.sh" -exec chmod +x {} \;
find %{_sysconfdir}/ha-lizard -type f -name "*.tcl" -exec chmod +x {} \;
find %{_sysconfdir}/ha-lizard/scripts -type f -exec chmod +x {} \;

# Add CLI link
ln -sf %{_sysconfdir}/ha-lizard/scripts/ha-cfg /usr/bin/ha-cfg || true

# Tab completion for CLI
cp %{_sysconfdir}/ha-lizard/scripts/ha-cfg.completion /etc/bash_completion.d/ha-cfg || true
chmod +x /etc/bash_completion.d/ha-cfg || true

# Enable init scripts for systemd
# TODO: migrate to systemctl
cp %{_sysconfdir}/ha-lizard/init/ha-lizard /etc/init.d/
cp %{_sysconfdir}/ha-lizard/init/ha-lizard-watchdog /etc/init.d/

# Enable the services to start on boot
if command -v systemctl &> /dev/null; then
    systemctl daemon-reload
    systemctl enable ha-lizard ha-lizard-watchdog
else
    chkconfig ha-lizard on
    chkconfig ha-lizard-watchdog on
fi

# Bootstrap initial start
cp %{_sysconfdir}/ha-lizard/scripts/install.params %{_sysconfdir}/ha-lizard/ha-lizard.pool.conf


# Create DB Keys
POOL_UUID=`xe pool-list --minimal`
xe pool-param-add uuid=$POOL_UUID param-name=other-config XenCenter.CustomFields.ha-lizard-enabled=false &>/dev/null || true
xe pool-param-add uuid=$POOL_UUID param-name=other-config autopromote_uuid="" &>/dev/null || true
%{_sysconfdir}/ha-lizard/scripts/ha-cfg insert &>/dev/null

# TODO: Update installation version
#%{_sysconfdir}/ha-lizard/scripts/post_version.py HAL-__VERSION__-__RELEASE__

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

# Root directory files
%{_sysconfdir}/ha-lizard/ha-lizard.init
%{_sysconfdir}/ha-lizard/ha-lizard.sh

# Configuration files
%config(noreplace) %{_sysconfdir}/ha-lizard/ha-lizard.conf
%config(noreplace) %{_sysconfdir}/ha-lizard/ha-lizard.pool.conf

# Scripts and binaries
%{_sysconfdir}/ha-lizard/scripts
%{_sysconfdir}/ha-lizard/ha-lizard.func

# Init and systemd service files
%{_sysconfdir}/ha-lizard/init/ha-lizard
%{_sysconfdir}/ha-lizard/init/ha-lizard.mon
%{_sysconfdir}/ha-lizard/init/ha-lizard-watchdog

# Fencing scripts
%{_sysconfdir}/ha-lizard/fence/ILO
%{_sysconfdir}/ha-lizard/fence/IRMC
%{_sysconfdir}/ha-lizard/fence/XVM

# Documentation
# TODO: use doc macro to handle the documentation files
%doc README.md LICENSE doc/COPYING doc/HELPFILE doc/INSTALL doc/RELEASE
%doc %{_sysconfdir}/ha-lizard/LICENSE
%doc %{_sysconfdir}/ha-lizard/README.md
%doc %{_sysconfdir}/ha-lizard/doc/COPYING
%doc %{_sysconfdir}/ha-lizard/doc/HELPFILE
%doc %{_sysconfdir}/ha-lizard/doc/INSTALL
%doc %{_sysconfdir}/ha-lizard/doc/RELEASE

# State files
# TODO: change it to {_localstatedir}/lib/ to manage the state files
%{_sysconfdir}/ha-lizard/state/autopromote_uuid
%{_sysconfdir}/ha-lizard/state/ha_lizard_enabled
%{_sysconfdir}/ha-lizard/state/local_host_uuid

# TODO: Add the CHANGELOG file following the RPM spec format
#%changelog
