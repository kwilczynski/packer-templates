Packer templates for creating Amazon EC2 images (HVM only) and Vagrant boxes.

Currently supported images:

**WARNING**: Ubuntu 12.04 (Precise Pangolin) is past its **End of Life.**

- Ubuntu 12.04 "Precise Pangolin" (version: 12.04.5)
- Ubuntu 14.04 "Trusty Tahr" (version: 14.04.4)
- Ubuntu 16.04 "Xenial Xerus" (version: 16.04.3)

Up to date Vagrant boxes can be found at https://app.vagrantup.com/kwilczynski

At the moment, the Amazon EC2 images include:

- Docker and Docker Compose
- AWS Command Line Interface
- CloudFormation Helper Scripts
- Stable drivers for SR-IOV and Elastic Network Adapter (ENA)
- More recent version of OpenSSL
- Native ZFS support (only 14.04 and 16.04)

Every box includes an up-to-date version of VirtualBox Guest Additions,
and a very basic system tuning (e.g. network stack, virtual memory, etc.),
plus sensible hardening (e.g. Kernel, OpenSSH, etc.).
