Packer templates for creating Amazon EC2 images (HVM only), Proxmox templates (KVM) and Vagrant boxes.

Currently supported images:

**WARNING**: Ubuntu 12.04 (Precise Pangolin) is past its **End of Life** (EOL).

**WARNING**: Ubuntu 14.04 (Trusty Tahr) is currently approaching its **End of Life** (EOL) and has entered into the [Extended Security Maintenance][0] cycle.

- Ubuntu 12.04 "Precise Pangolin" (version: 12.04.5)
- Ubuntu 14.04 "Trusty Tahr" (version: 14.04.6)
- Ubuntu 16.04 "Xenial Xerus" (version: 16.04.6)
- Ubuntu 18.04 "Bionic Beaver" (version: 18.04.4)
- Ubuntu 20.04 "Focal Fossa" (version: 20.04)

Up to date Vagrant boxes can be found at https://app.vagrantup.com/kwilczynski.

Some of the features that the images include:

- Docker and Docker Compose
- AWS Command Line Interface
- CloudFormation Helper Scripts
- Stable drivers for SR-IOV and Elastic Network Adapter (ENA)
- Backported version of Apt for 12.04
- More recent version of OpenSSL
- Native ZFS support (only 14.04 and 16.04)
- Snapcraft support has been removed from 20.04

Every Vagrant box includes an up-to-date version of VirtualBox Guest Additions, and a very basic system tuning (e.g.
network stack, virtual memory, etc.), plus sensible hardening (e.g. Kernel, OpenSSH, etc.).

[0]: https://ubuntu.com/esm
