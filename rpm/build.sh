#!/bin/sh
# Builds the RPM of this repository (rubygem-foreman_kubevirt 0.6.0, release 2.2) for Foreman 5.0 on EL9.
#
# Everything runs in a Rocky Linux 9 container with the Foreman 5.0 repositories: the gem is built from the
# source tree of this repository, then rpmbuild packages it with rpm/rubygem-foreman_kubevirt.spec.
# Needs only podman (or docker) and network access. Nothing is installed on the host.
#
# Output: rpm/out/*.rpm (binary and source package).
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")
ENGINE=${ENGINE:-$(command -v podman || command -v docker || true)}
IMAGE=${IMAGE:-docker.io/rockylinux/rockylinux:9}

if [ -z "$ENGINE" ]; then
  echo "podman or docker is required to build the RPM (set ENGINE to use another container engine)" >&2
  exit 1
fi

mkdir -p "$HERE/out"
rm -f "$HERE"/out/*.rpm

"$ENGINE" run --rm --security-opt label=disable \
  -v "$ROOT:/src:ro" -v "$HERE/out:/out" \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -e ENGINE_NAME="$(basename "$ENGINE")" \
  "$IMAGE" sh -euc '
    dnf -y -q install https://yum.theforeman.org/releases/5.0/el9/x86_64/foreman-release.rpm
    dnf -y -q install rpm-build rubygems-devel ruby foreman-assets foreman-plugin "rubygem(fog-kubevirt)"

    top=/root/rpmbuild
    mkdir -p "$top/SOURCES" "$top/SPECS"
    cp -a /src /tmp/build
    cd /tmp/build
    gem build foreman_kubevirt.gemspec
    mv foreman_kubevirt-*.gem "$top/SOURCES/"
    cp rpm/rubygem-foreman_kubevirt.spec "$top/SPECS/"

    rpmbuild -ba --define "foremandist .fm5_0" "$top/SPECS/rubygem-foreman_kubevirt.spec"

    # The -doc package (README, tests) is not needed on the server.
    cp "$top"/RPMS/noarch/rubygem-foreman_kubevirt-[0-9]*.noarch.rpm "$top"/SRPMS/*.src.rpm /out/
    # Rootless podman already maps root of the container to the user; docker would leave the files owned by root.
    if [ "$ENGINE_NAME" = docker ]; then chown "$HOST_UID:$HOST_GID" /out/*.rpm; fi
  '

ls -l "$HERE/out"
