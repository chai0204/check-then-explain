Name:      labmotd
Version:   1.0
Release:   1
Summary:   prints a message of the day
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch

%description
Prints /usr/share/labmotd/motd.txt. Used to practice rpm -V.

%install
mkdir -p %{buildroot}/usr/bin %{buildroot}/usr/share/labmotd
printf '%%s\n' '#!/bin/sh' 'cat /usr/share/labmotd/motd.txt' > %{buildroot}/usr/bin/labmotd
chmod 0755 %{buildroot}/usr/bin/labmotd
printf '%%s\n' '今日のひとこと: 台帳と照らし合わせれば、変わったファイルが分かる。' > %{buildroot}/usr/share/labmotd/motd.txt

%files
/usr/bin/labmotd
/usr/share/labmotd/motd.txt
