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
mkdir -p %{buildroot}/usr/bin %{buildroot}%{_docdir}/labhello %{buildroot}%{_mandir}/man1
printf '%%s\n' '#!/bin/sh' 'echo "labhello %{version}"' > %{buildroot}/usr/bin/labhello
chmod 0755 %{buildroot}/usr/bin/labhello
printf '%%s\n' 'labhello %{version} - 確かめて説明する LinuC 主題1.04 の練習用パッケージ' '自分の版を1行表示するだけのコマンドです。' > %{buildroot}%{_docdir}/labhello/README
printf '%%s\n' '.TH LABHELLO 1 "2026-10-01" "labhello %{version}" "LinuC 1.04 practice"' '.SH NAME' 'labhello \- print its own version' '.SH SYNOPSIS' '.B labhello' '.SH DESCRIPTION' '.B labhello' 'prints its own version (labhello %{version}) and exits.' 'It is a practice package for LinuC 1.04 (check-then-explain).' > %{buildroot}%{_mandir}/man1/labhello.1

%files
/usr/bin/labhello
%doc %{_docdir}/labhello/README
%{_mandir}/man1/labhello.1*
