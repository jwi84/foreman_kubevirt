# foreman_kubevirt, patched for live migratable UEFI VMs

A fork of [theforeman/foreman_kubevirt](https://github.com/theforeman/foreman_kubevirt) 0.6.0, the plugin that
manages [KubeVirt](https://kubevirt.io) / OpenShift Virtualization as a compute resource in Foreman.

This version changes how the plugin creates VMs, so that a VM installed by network boot (PXE and kickstart) on
OpenShift Virtualization boots from its disk after the installation, uses UEFI, and can be live migrated.
It is built for Foreman 5.0 on EL9 and was tested on OpenShift 4.22 with OpenShift Virtualization 4.22.

The packages are in [`rpm/out`](rpm/out). For everything else (what the plugin does, how to configure a compute
resource) see the upstream project.

## What changed

### 1. Disk access mode and volume mode

Upstream always creates the disk claim of a VM as `ReadWriteOnce` and sends no volume mode
([upstream issue #206](https://github.com/theforeman/foreman_kubevirt/issues/206)). On a storage class that needs
`ReadWriteMany` with `Block` volumes (iSCSI, Ceph RBD), the VM can then never be live migrated.

Volume attributes accept two more keys:

| Attribute | Values | Default |
| --------- | ------ | ------- |
| `access_mode` | `ReadWriteOnce`, `ReadWriteMany`, `ReadOnlyMany`, `ReadWriteOncePod` | `ReadWriteOnce` (as before) |
| `volume_mode` | `Filesystem`, `Block`, `FromStorageProfile` | cluster default (as before) |

`FromStorageProfile` lets CDI choose both modes from the StorageProfile of the storage class
(`ReadWriteMany` + `Block` on a storage class that declares it), which gives a live migratable VM without writing
the modes in Foreman. It needs the CDI feature gate `WebhookPvcRendering`. Other values are refused with an error
before anything is created. Without the new attributes nothing changes.

The two attributes are also selects in the volume form (disabled once the VM exists), are read back from the claims
of existing VMs, and appear in `GET /api/hosts/:id/vm_compute_attributes`. Example, in the compute attributes of a
host or of a compute profile:

```json
"volumes_attributes": {
  "0": { "storage_class": "my-storage-class", "capacity": "40", "bootable": "true", "volume_mode": "FromStorageProfile" }
}
```

### 2. Boot order of a network install

Taken from [upstream pull request #202](https://github.com/theforeman/foreman_kubevirt/pull/202) by
Pablo Méndez Hernández (commit kept with its author). With a bootable volume and a provisioning NIC, the NIC gets
boot order 1 and the disk boot order 2: the VM boots from the network for the installation, and boots its disk once
Foreman serves the local boot entry. No patch of the VM is needed after its creation.

### 3. UEFI

VMs are created with UEFI firmware (OVMF), Secure Boot off, so unsigned boot loaders such as `grub2/grubx64.efi`
(PXE loader `Grub2 UEFI`) start. This is not configurable: every VM created by the plugin boots with UEFI. The
machine type is not changed and existing VMs keep their firmware. It uses `extra_domain` of fog-kubevirt, so the gem
requires `fog-kubevirt >= 1.8.0`.

If you need to choose the firmware per VM (or add a virtual TPM), follow
[upstream pull request #203](https://github.com/theforeman/foreman_kubevirt/pull/203), which does that.

## Install

```sh
sudo dnf install ./rubygem-foreman_kubevirt-0.6.0-2.2.fm5_0.el9.noarch.rpm
sudo systemctl restart foreman
```

The plugin stays enabled in the Foreman installer answers, no installer run is needed. The release `2.2` is newer
than the official `0.6.0-2`. To keep the package when the official repository gets a newer one, add
`exclude=rubygem-foreman_kubevirt*` to the `foreman-plugins` repository (or use `dnf versionlock`).

Rollback:

```sh
sudo dnf downgrade rubygem-foreman_kubevirt-0.6.0-2.fm5_0.el9
sudo systemctl restart foreman
```

## Build the RPM

```sh
rpm/build.sh
```

Needs `podman` and network access. It downloads the official source package, applies
`rpm/rubygem-foreman_kubevirt.spec` and `rpm/foreman_kubevirt-pvc-modes.patch`, and builds in a Rocky Linux 9
container with the Foreman 5.0 repositories. The packages end up in `rpm/out`.

## From source

The branch `patched` holds the changes as commits on top of upstream `master`
(`4b89174`). Build the gem as upstream does:

```sh
gem build foreman_kubevirt.gemspec
```

## License

[GPL-3.0](LICENSE), the license of the upstream project: this is a derivative work, so it keeps the same license.
The changes of this fork are released under it too, copyright (C) 2026 jwi84.

You can use, modify and redistribute the code and the packages for any purpose, commercial use included, free of
charge. If you distribute a modified version, you must give its source under the GPL-3.0 as well. There is no
warranty.
