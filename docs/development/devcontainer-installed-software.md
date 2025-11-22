# Devcontainer Installed Software

This document tracks all software that has been manually installed within the devcontainer environment by the AI agent to support the Tilt + Kind development setup. This helps in understanding the environment's dependencies and makes it easier to add them to the devcontainer configuration later.

## Command-Line Tools

| Tool | Version | Installation Method |
|---|---|---|
| Kind | `v0.30.0` | Downloaded binary from GitHub releases |
| kubectl | latest stable | Downloaded binary from Kubernetes release artifacts|
| Helm | `v4.0.0` | Downloaded binary from get.helm.sh |
| iputils-ping| latest from apt| `apt-get install iputils-ping` |

## Kubernetes Components (via Helm)

| Component | Chart Version | Namespace |
|---|---|---|
| cert-manager | `v1.13.2` | `cert-manager` |
| Envoy Gateway | `v1.0.0` | `envoy-gateway-system`|
