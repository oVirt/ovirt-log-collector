#!/bin/bash -xe
autoreconf -ivf
./configure
make distcheck

./automation/build-artifacts.sh

echo -e "\n\n =====  Testing RPM Dependencies =====\n"
# Restoring sane yum environment screwed up by mock-runner
rm -f /etc/yum.conf
dnf reinstall -y system-release dnf dnf-conf
sed -i -re 's#^(reposdir *= *).*$#\1/etc/yum.repos.d#' '/etc/dnf/dnf.conf'
echo "deltarpm=False" >> /etc/dnf/dnf.conf
rm -f /etc/yum/yum.conf

dnf install -y https://resources.ovirt.org/pub/yum-repo/ovirt-release-master-tested.rpm
if [[ "$(rpm --eval "%dist")" == ".el8" ]]; then
dnf --downloadonly install ./exported-artifacts/*noarch.rpm
else
# we are still missing ovirt-engine on el9
dnf --downloadonly install ./exported-artifacts/*noarch.rpm || true
fi