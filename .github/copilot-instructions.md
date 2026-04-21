# Copilot Instructions for `capo-image-elements`

## Build, test, and lint commands

### Environment setup
```bash
uv sync
sudo apt-get install -y $(uv run bindep -b)
```

### Build a single image (local)
Use one OS/Kubernetes combination (equivalent to one CI matrix entry):
```bash
export ELEMENTS_PATH=$PWD/elements
export DIB_RELEASE=jammy
export DIB_KUBERNETES_VERSION=1.35.4
export DIB_CLOUD_INIT_GROWPART_DEVICES='["/"]'
export DIB_SKIP_BASE_PACKAGE_INSTALL=1
export DIB_IMAGE_SIZE=3
uv run disk-image-create -o ubuntu-22.04-v1.35.4.qcow2 vm ubuntu-minimal block-device-kubernetes kubernetes
```

### Full validation path used by the project
- CI workflow: `.github/workflows/ci.yaml`
- Flow: build qcow2 (matrix) -> boot/test in DevStack with CAPO -> release artifacts on non-PR runs.

### Single-test guidance
There is no standalone unit/integration test command in this repository; the closest local equivalent of a single CI matrix case is running one `disk-image-create` invocation as shown above.

### Linting
No repository lint target or lint workflow is currently defined.

## High-level architecture

This repository is a set of `diskimage-builder` elements for Cluster API Provider OpenStack images. Image builds are composed from DIB elements, not Packer templates.

The primary composition used by CI is:
- `vm <distro-base-element> block-device-kubernetes kubernetes`

The `kubernetes` meta element is the core orchestrator and pulls in:
- `cloud-init`, `cni-plugins`, `containerd`, `cri-tools`, `elrepo-kernel`, `epel`, `kubeadm`, `kubectl`, `kubelet`, `openssh-server`, `runc`

Execution model is DIB phase-driven:
- `pre-install.d/` for early host/package config
- `install.d/` for runtime binary installation/configuration
- `post-install.d/` for OS/runtime adjustments (sshd hardening, kubeadm image pre-pull, manifests dir)
- `finalise.d/` for distro-specific final tweaks (network renderer defaults, cloud-init backport on trixie, Rocky defaults)
- `static/` for files dropped directly into the image
- `environment.d/` for default `DIB_*` values

CI architecture in `.github/workflows/ci.yaml`:
- **build job**: builds qcow2 artifacts for OS x Kubernetes matrix
- **devstack job**: loads each artifact into OpenStack (DevStack), deploys CAPO-managed cluster, waits for node readiness
- **release job**: publishes qcow2 artifacts as GitHub release assets on non-PR events

## Key conventions in this codebase

- Shell scripts consistently use:
  - `#!/bin/bash`
  - `if [ ${DIB_DEBUG_TRACE:-1} -gt 0 ]; then set -x; fi`
  - `set -eu` and `set -o pipefail`
  - SPDX header (`# SPDX-License-Identifier: Apache-2.0`) for project-owned scripts

- Kubernetes component versions are centrally tied to `DIB_KUBERNETES_VERSION` in `elements/kubernetes/environment.d/10-kubernetes`, then propagated to kubeadm/kubelet/kubectl defaults.

- Component installers download release artifacts directly (Kubernetes, containerd, runc, CNI, cri-tools), verify checksums, and install binaries into system paths (`/usr/bin`, `/opt/cni/bin`).

- Cross-distro package differences are handled by:
  - `package-installs.yaml` with `when: DISTRO_NAME = ...` conditions
  - `pkg-map` files to remap package names (especially for Red Hat family)

- `block-device-kubernetes` provides a custom `block-device` configuration with a reduced EFI partition size. Keep using this element in build commands unless intentionally changing partitioning behavior.

- CI matrix OS identifiers use slash-delimited strings (`os/version/base-element/dib-release`) and are split in workflow steps; keep this format if extending matrix entries.
