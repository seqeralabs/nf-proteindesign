# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the nf-proteindesign-2025 repository.

## deploy-docs.yml

Automatically builds and deploys the MkDocs documentation to GitHub Pages.

**Triggers:**
- Push to `main` branch
- Manual workflow dispatch

**Requirements:**
- GitHub Pages must be enabled in repository settings
- Pages source must be set to "GitHub Actions"

**What it does:**
1. Checks out the repository code
2. Sets up Python environment with caching
3. Installs MkDocs and required plugins
4. Builds the documentation site
5. Deploys to GitHub Pages

**Site URL:** https://flouwuenne.github.io/nf-proteindesign-2025/

For more information, see the [deployment documentation](../docs/deployment/github-pages.md).
