## About The Project

This repository is an implementation of a project from [Zero To Production In Rust](https://www.zero2prod.com/).

Key differences from the original reference implementation include:

- Using `nix` for the development environment (see `flake.nix`).
- Utilizing `kubernetes` for deployment via `helm` and `helmfile` (see `kuber/`).
- Employing `kind` to run a local `kubernetes` cluster (see `justfile`).
