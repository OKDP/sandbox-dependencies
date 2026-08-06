[![ci](https://github.com/okdp/sandbox-dependencies/actions/workflows/ci.yml/badge.svg)](https://github.com/okdp/sandbox-dependencies/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/okdp/sandbox-dependencies)](https://github.com/okdp/sandbox-dependencies/releases/latest)&ensp;&ensp;
[![KuboCD](https://img.shields.io/badge/kubocd-v0.2.2-green.svg)](https://github.com/kubocd/kubocd)&ensp;&ensp;
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.28+-blue.svg)](https://kubernetes.io/)&ensp;&ensp;
[![License Apache2](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)
<a href="https://okdp.io">
<img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>

## Overview

This repository builds and publishes the OKDP platform packages requirements used to operate platform services with [KuboCD](https://www.kubocd.io/).

These packages are not part of the OKDP distribution itself. They are the prerequisites the sandbox depends on: cluster foundations (ingress, DNS, certificates, database operator, identity) and the object storage backing the platform services.

It is **packages-only**: it owns the package definitions under `packages/` and the CI that builds and publishes them as OCI artifacts. It does **not** own the deployment layer (releases, contexts, Flux/KuboCD bootstrap). Deployment lives in [`OKDP/okdp-sandbox`](https://github.com/OKDP/okdp-sandbox), which consumes the packages published here.

## KuboCD Concepts

- **Package**: a versioned OCI artifact that bundles a KuboCD application descriptor and one or more Helm charts. The manifests under `packages/` define the packages published by this repository.

Packages are deployed through KuboCD **Releases** that reference layered **Contexts**. Those deployment resources are maintained in [`OKDP/okdp-sandbox`](https://github.com/OKDP/okdp-sandbox), not here.

## Structure

```
packages/
├── system/             # Infrastructure & system packages
│   ├── cert-manager/
│   ├── cloudnative-pg/
│   ├── cnpg-postgresql/
│   ├── coredns-patch/
│   ├── dns-server/
│   ├── ingress-nginx/
│   ├── keycloak/
│   ├── kubocd-webhooks/
│   ├── local-secrets-provider/
│   └── tools/
└── services/           # Services
    └── seaweedfs/
sandbox-dependencies-values.yaml   # OCI publish target (packageRepository), the source of truth used by CI
```

Key paths:

- [`packages/system`](./packages/system): infrastructure and platform foundation packages.
- [`packages/services`](./packages/services): data and application service packages.
- [`sandbox-dependencies-values.yaml`](./sandbox-dependencies-values.yaml): the OCI repository packages are published to.

## Packages

Each package is a single KuboCD manifest under `packages/<layer>/<name>/`, and the `tag` field of that manifest is the published package version. Adding a package means adding a manifest there and a row in the tables below.

### System

| Package | Tag | Description |
| --- | --- | --- |
| [`cert-manager`](./packages/system/cert-manager) | `1.17.1-p06` | cert-manager, with the optional trust-manager bundle and cluster certificate issuers |
| [`cloudnative-pg`](./packages/system/cloudnative-pg) | `1.29.1-p01` | CloudNativePG operator covering the PostgreSQL cluster lifecycle |
| [`cnpg-postgresql`](./packages/system/cnpg-postgresql) | `18.3-p01` | Logical PostgreSQL databases, owners and credentials managed by CloudNativePG |
| [`coredns-patch`](./packages/system/coredns-patch) | `1.0.0-p04` | CoreDNS patch resolving the ingress suffix to the ingress controller |
| [`dns-server`](./packages/system/dns-server) | `1.0.0-p03` | Lightweight DNS server resolving the sandbox domain for local development |
| [`ingress-nginx`](./packages/system/ingress-nginx) | `4.12.1-p03` | NGINX ingress controller, in `nodePort`, `hostPort` or `metallb` mode |
| [`keycloak`](./packages/system/keycloak) | `24.4.11-p09` | Keycloak identity and access management |
| [`kubocd-webhooks`](./packages/system/kubocd-webhooks) | `v0.2.1-p01` | Second stage of the KuboCD deployment |
| [`local-secrets-provider`](./packages/system/local-secrets-provider) | `1.0.0-p04` | Shared local testing secrets, configuration, services and environment values |
| [`tools`](./packages/system/tools) | `1.0.0-p01` | Reloader, replicator and secret-generator utilities |

### Services

| Package | Tag | Description |
| --- | --- | --- |
| [`seaweedfs`](./packages/services/seaweedfs) | `4.17.0-p3` | Distributed file system exposing the S3, IAM and STS endpoints used as default object storage |

## Building Packages

The target OCI repository is defined once in [`sandbox-dependencies-values.yaml`](./sandbox-dependencies-values.yaml) (`packageRepository`). Use the same value for local builds.

### Basic Build Command

```bash
# Build a system package
kubocd package ./packages/system/cert-manager/cert-manager.yaml --ociRepoPrefix quay.io/okdp/sandbox-dependencies

# Build a service package
kubocd package ./packages/services/seaweedfs/seaweedfs.yaml --ociRepoPrefix quay.io/okdp/sandbox-dependencies
```

### Custom OCI Repository

```bash
# Using a different OCI registry
kubocd package ./packages/system/cert-manager/cert-manager.yaml --ociRepoPrefix myregistry.io/my-org/packages

# Using a different prefix for packages
kubocd package ./packages/services/seaweedfs/seaweedfs.yaml --ociRepoPrefix harbor.company.com/okdp-prod
```

### Examples

```bash
# Build all system packages
for pkg in packages/system/*/; do
  kubocd package "$pkg"*.yaml --ociRepoPrefix quay.io/okdp/sandbox-dependencies
done

# Build a specific package
kubocd package ./packages/system/keycloak/keycloak.yaml --ociRepoPrefix quay.io/okdp/sandbox-dependencies
```

### Build Output

Packages are pushed to: `{ociRepoPrefix}/{package-name}:{tag}`

Example: `quay.io/okdp/sandbox-dependencies/seaweedfs:4.17.0-p3`

## GitHub CI and Publishing

The GitHub workflows share the reusable [`kubocd-package-template.yml`](./.github/workflows/kubocd-package-template.yml) workflow for both CI validation and publishing.

### CI Workflow

[`ci.yml`](./.github/workflows/ci.yml) runs on pushes, pull requests, and manual dispatch. It:

- reads the OCI package prefix from [`sandbox-dependencies-values.yaml`](./sandbox-dependencies-values.yaml);
- builds **every** package manifest under `packages/` that contains `modules:`;
- pushes CI test packages to the repository-scoped GitHub Container Registry path.

Building covers every package, so packaging errors are caught repo-wide. Deployment of the published packages (Flux/KuboCD bootstrap, contexts, releases) and its end-to-end validation live in [`OKDP/okdp-sandbox`](https://github.com/OKDP/okdp-sandbox), not here.

The KuboCD package CI job is skipped for fork pull requests because GitHub intentionally gives those runs a read-only token, which cannot push to GHCR.

### CI Registry

The `ci` workflow builds packages for CI validation and pushes them to the repository-scoped GitHub Container Registry path:

```text
ghcr.io/okdp/sandbox-dependencies/sandbox-dependencies/{package-name}:{tag}
```

### Release Publishing

Published release packages use the public repository from [`sandbox-dependencies-values.yaml`](./sandbox-dependencies-values.yaml):

```text
quay.io/okdp/sandbox-dependencies/{package-name}:{tag}
```

[`publish.yml`](./.github/workflows/publish.yml) can be dispatched manually and publishes packages to Quay using `REGISTRY_USERNAME` and `REGISTRY_ROBOT_TOKEN`. [`publish-on-merge.yml`](./.github/workflows/publish-on-merge.yml) triggers that publish workflow after a successful `ci` run on `main`, and [`release-please.yml`](./.github/workflows/release-please.yml) triggers it when Release Please creates a new release after a merged pull request.

---

## Contributing & License

Contributions follow the [OKDP contribution guide](https://github.com/OKDP/.github/blob/main/CONTRIBUTING.md). Released under the [Apache License 2.0](LICENSE).

---

**Built 🚀 for the OKDP Community**
<a href="https://okdp.io">
  <img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>
