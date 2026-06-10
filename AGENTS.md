# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is

**nf-proteindesign** is a Nextflow pipeline for AI protein binder design (BoltzGen, Proteina-Complexa, or RFdiffusion v3), plus an MkDocs documentation site in `docs/`. There is no long-running app server for the pipeline itself — runs are one-shot `nextflow run` commands.

### Prerequisites (already on the VM image)

- **Java 21** (bundled with Ubuntu)
- **Python 3.12** + `pip`
- **Docker** (installed for containerized GPU runs; daemon must be started manually — see below)
- **Nextflow 25.10.2** (pinned; see update script). Avoid Nextflow **26.04.x** (DSL parse error on `meta` in `publishDir`) and **24.10.x** (`Channel` scope errors in `main.nf`).

### Starting Docker

Systemd is not available in this environment. Start Docker before any `-profile docker` run:

```bash
sudo dockerd > /tmp/dockerd.log 2>&1 &
sudo chmod 666 /var/run/docker.sock   # if permission denied
```

### PATH

MkDocs installs to `~/.local/bin`. Ensure it is on `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Pipeline — quick validation (no GPU, no containers)

Use the RFdiffusion v3 test profile with `-stub-run`. On the default 4-CPU / 16 GB cloud VM, pass a resource override config because `conf/base.config` requests up to 40 GB for GPU processes:

```bash
cd /workspace
nextflow run main.nf \
  -profile test_design_rfdiffusion_v3 \
  -stub-run \
  -c conf/cloud_dev.config
```

`conf/cloud_dev.config` caps CPUs/memory for local stub runs on smaller machines.

### Pipeline — full GPU run (requires NVIDIA GPU)

```bash
nextflow run main.nf -profile test_design_protein,docker
```

This VM has no GPU; full runs must be done on a GPU host with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

### Documentation site

```bash
export PATH="$HOME/.local/bin:$PATH"
mkdocs build          # static site → site/
mkdocs serve -a 0.0.0.0:8000   # dev server
```

`mkdocs build` regenerates `docs/reference/parameters.md` from `nextflow_schema.json`; do not commit that file unless intentionally updating docs.

### Lint / test commands

| Task | Command |
|------|---------|
| Workflow stub E2E | `nextflow run main.nf -profile test_design_rfdiffusion_v3 -stub-run -c conf/cloud_dev.config` |
| Docs build | `mkdocs build` |
| Clean work dir | `nextflow clean -f` |

There is no separate unit-test suite or linter in this repository.

### Common gotchas

- **CPU/memory limits**: stub runs fail with `Process requirement exceeds available CPUs/memory` without `conf/cloud_dev.config` on small VMs.
- **Nextflow version**: pin to **25.10.2** via `NXF_VER=25.10.2` when (re)installing.
- **Foldseek**: disabled in all test profiles (`run_foldseek = false`); production runs need `--foldseek_database`.
