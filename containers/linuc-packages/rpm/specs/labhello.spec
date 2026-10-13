%{!?ver:%global ver 1.0}
Name:      labhello
Version:   %{ver}
Release:   1
Summary:   prints its own version
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch

%description
A tiny package used to practice upgrades.

%install
mkdir -p %{buildroot}/usr/bin
printf '%%s\n' '#!/bin/sh' 'echo "labhello %{version}"' > %{buildroot}/usr/bin/labhello
chmod 0755 %{buildroot}/usr/bin/labhello

%files
/usr/bin/labhello
