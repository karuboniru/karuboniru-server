# Fedora IoT ostree/rpm-ostree treefiles

This is the repo for the ostree compose configs for Fedora IoT.

NVIDIA support is enabled by including `manifests/features/nvidia.yaml` in
`server.yaml`. Comment out or remove that include to disable the NVIDIA driver,
container toolkit, GPU monitoring, and in-image kernel module build. The feature
uses the repository definitions in `nvidia.repo`, `ctk.repo`, and `dummy.repo`.
