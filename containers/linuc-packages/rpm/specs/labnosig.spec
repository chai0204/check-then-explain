Name:      labnosig
Version:   1.0
Release:   1
Summary:   package distributed without a signature
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch

%description
A stand-alone rpm file that nobody signed. Used to practice rpm -K.

%install
mkdir -p %{buildroot}/usr/bin
printf '%%s\n' '#!/bin/sh' 'echo "labnosig 1.0 (誰も署名していない)"' > %{buildroot}/usr/bin/labnosig
chmod 0755 %{buildroot}/usr/bin/labnosig

%files
/usr/bin/labnosig
