Name:      labextra
Version:   1.0
Release:   1
Summary:   package that lives only in /srv/lab-extra-rpm
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch

%description
Used to practice adding a repository to yum.

%install
mkdir -p %{buildroot}/usr/bin
printf '%%s\n' '#!/bin/sh' 'echo "labextra 1.0 (/srv/lab-extra-rpm から入った)"' > %{buildroot}/usr/bin/labextra
chmod 0755 %{buildroot}/usr/bin/labextra

%files
/usr/bin/labextra
