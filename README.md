Packer templates for creating Amazon EC2 images (HVM only) and Vagrant boxes.

Currently supported images:

- Ubuntu 12.04 "Precise Pangolin" (version: 12.04.5)
- Ubuntu 14.04 "Trusty Tahr" (version: 14.04.4)
- Ubuntu 16.04 "Xenial Xerus" (version: 16.04.2)

Up to date Vagrant boxes can be found at https://atlas.hashicorp.com/kwilczynski

At the moment, the Amazon EC2 images include:

- Docker and Docker Compose
- AWS Command Line Interface
- CloudFormation Helper Scripts

Every box includes an up-to-date version of VirtualBox Guest Additions,
and a very basic system tunning (e.g. network stack, virtual memory, etc.),
plus sensible hardening (e.g. Kernel, OpenSSH, etc.).
