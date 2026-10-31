#!/bin/bash
set -euo pipefail
shopt -s nullglob
R=${1:?usage: strip.sh ROOTFS}

rm -rf "$R"/var/lib/apt/lists/* "$R"/var/cache/apt/* "$R"/var/cache/ldconfig/* \
       "$R"/var/log/* "$R"/tmp/* "$R"/usr/share/{man,info,lintian,bug,doc-base,i18n,bash-completion} \
       "$R"/var/lib/dpkg/*-old "$R"/var/cache/debconf/*-old "$R"/var/cache/debconf/templates.dat* \
       "$R"/var/lib/dpkg/info/*.symbols "$R"/usr/share/common-licenses/*

find "$R"/usr/share/doc -type f ! -name copyright -exec rm -f {} +
find "$R"/usr/share/doc -mindepth 1 -type d -empty -exec rmdir {} +
find "$R"/usr/share/locale -mindepth 1 -maxdepth 1 ! -name locale.alias -exec rm -rf {} +

for g in "$R"/usr/lib/*-linux-gnu/gconv; do
  find "$g" -type f ! -name 'gconv-modules*' ! -name 'UTF-*' ! -name 'UNICODE*' \
       ! -name 'ISO8859-1.so' ! -name 'ANSI_X3.4*' -exec rm -f {} +
  rm -rf "$g"/gconv-modules.d/*
done

rm -rf "$R"/usr/lib/*-linux-gnu/perl-base/unicore \
       "$R"/usr/share/zoneinfo/{right,posix,Antarctica,Arctic}

find "$R"/usr/bin "$R"/usr/sbin "$R"/usr/lib -type f -exec sh -c '
  for f; do
    head -c4 "$f" | grep -q "^.ELF" || continue
    strip --strip-unneeded "$f" || echo "strip failed: $f" >&2
  done' sh {} +
