Name:      liblab
Version:   1.0
Release:   1
Summary:   small shell library for lab programs
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch

%description
labapp reads this file. It provides one shell function, lab_greet.

%install
mkdir -p %{buildroot}/usr/lib/liblab
printf '%%s\n' '# liblab 1.0 - labapp が読み込む小さなライブラリ' "lab_greet() { printf 'liblab: %%s\\n' \"\$*\"; }" > %{buildroot}/usr/lib/liblab/liblab.sh

%files
/usr/lib/liblab/liblab.sh
