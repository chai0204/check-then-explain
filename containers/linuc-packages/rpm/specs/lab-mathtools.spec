Name:      lab-mathtools
Version:   1.0
Release:   1
Summary:   small number utilities for the lab
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch

%description
Adds integers given on the command line.

%install
mkdir -p %{buildroot}/usr/bin
printf '%%s\n' '#!/bin/sh' '# 引数の整数を足すだけの道具（lab-mathtools パッケージ）' '[ $# -ge 1 ] || { echo "使い方: labcalc 数 [数 ...]" >&2; exit 2; }' 's=0; for n in "$@"; do s=$((s + n)); done; echo "$s"' > %{buildroot}/usr/bin/labcalc
chmod 0755 %{buildroot}/usr/bin/labcalc

%files
/usr/bin/labcalc
