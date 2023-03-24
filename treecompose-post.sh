#!/usr/bin/env bash

set -xeuo pipefail

# From https://github.com/coreos/fedora-coreos-config/blob/testing-devel/overlay.d/05core/usr/lib/systemd/journald.conf.d/10-coreos-persistent.conf
install -dm0755 /usr/lib/systemd/journald.conf.d/
echo -e "[Journal]\nStorage=persistent" > /usr/lib/systemd/journald.conf.d/10-persistent.conf

# See: https://src.fedoraproject.org/rpms/glibc/pull-request/4
# Basically that program handles deleting old shared library directories
# mid-transaction, which never applies to rpm-ostree. This is structured as a
# loop/glob to avoid hardcoding (or trying to match) the architecture.
for x in /usr/sbin/glibc_post_upgrade.*; do
    if test -f ${x}; then
        ln -srf /usr/bin/true ${x}
    fi
done

# Remove loader directory causing issues in Anaconda in unified core mode
# Will be obsolete once we start using bootupd
# See - https://pagure.io/workstation-ostree-config/pull-request/344
rm -rf /usr/lib/ostree-boot/loader
