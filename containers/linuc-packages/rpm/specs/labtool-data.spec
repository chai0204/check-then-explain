Name:      labtool-data
Version:   1.0
Release:   1
Summary:   data file for labtool
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch

%description
labtool prints this file.

%install
mkdir -p %{buildroot}/usr/share/labtool
printf '%%s\n' 'labtool: labtool-data から読んだ1行です' > %{buildroot}/usr/share/labtool/data.txt

%files
/usr/share/labtool/data.txt
