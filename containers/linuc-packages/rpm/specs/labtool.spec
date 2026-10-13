Name:      labtool
Version:   1.0
Release:   1
Summary:   tool that needs labtool-data
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch
Requires:  labtool-data >= 1.0

%description
Prints a line shipped in labtool-data.

%install
mkdir -p %{buildroot}/usr/bin
printf '%%s\n' '#!/bin/sh' '# labtool 1.0 - labtool-data の1行を表示する' 'cat /usr/share/labtool/data.txt' > %{buildroot}/usr/bin/labtool
chmod 0755 %{buildroot}/usr/bin/labtool

%files
/usr/bin/labtool
