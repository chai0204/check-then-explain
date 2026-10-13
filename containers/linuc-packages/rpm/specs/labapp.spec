Name:      labapp
Version:   1.0
Release:   1
Summary:   sample application that needs liblab
License:   MIT
URL:       https://github.com/chai0204/check-then-explain
Vendor:    check-then-explain
Packager:  check-then-explain <lab@example.invalid>
BuildArch: noarch
Requires:  liblab >= 1.0

%description
Prints a greeting. The greeting is read from /etc/labapp.conf.

%install
mkdir -p %{buildroot}/usr/bin %{buildroot}/etc %{buildroot}%{_docdir}/labapp
printf '%%s\n' '#!/bin/sh' '# labapp 1.0 - /etc/labapp.conf を読んで挨拶する' '. /usr/lib/liblab/liblab.sh' '[ -r /etc/labapp.conf ] && . /etc/labapp.conf' 'lab_greet "${greeting:-hello} from labapp 1.0"' > %{buildroot}/usr/bin/labapp
chmod 0755 %{buildroot}/usr/bin/labapp
printf '%%s\n' '# labapp の設定ファイル（rpm が %%config として管理する）' 'greeting="hello"' > %{buildroot}/etc/labapp.conf
printf '%%s\n' 'labapp - 確かめて説明する LinuC 主題1.04 の練習用パッケージ' '依存: liblab >= 1.0' '設定: /etc/labapp.conf' > %{buildroot}%{_docdir}/labapp/README

%files
/usr/bin/labapp
%config(noreplace) /etc/labapp.conf
%doc %{_docdir}/labapp/README
