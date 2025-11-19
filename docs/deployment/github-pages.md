# GitHub Pages Deployment

This documentation site is automatically deployed to GitHub Pages using GitHub Actions.

## Initial Setup (One-Time)

After merging the PR that adds the deployment workflow, a repository administrator needs to enable GitHub Pages:

1. Go to the repository on GitHub: [seqeralabs/nf-proteindesign](https://github.com/seqeralabs/nf-proteindesign)
2. Click on **Settings** (top navigation)
3. Click on **Pages** (left sidebar under "Code and automation")
4. Under **Build and deployment**:
   - **Source**: Select "GitHub Actions"
5. Save the settings

## Automatic Deployment

Once GitHub Pages is enabled, the documentation will be automatically deployed:

- **On every push to `main` branch**: The workflow builds and deploys the latest docs
- **Manual trigger**: You can manually trigger deployment from the Actions tab

The site will be available at: **https://seqeralabs.github.io/nf-proteindesign/**

## Workflow Details

The deployment workflow (`.github/workflows/deploy-docs.yml`) performs these steps:

1. **Checkout**: Gets the latest code from the repository
2. **Setup Python**: Installs Python 3.x with pip caching
3. **Install dependencies**: 
   - `mkdocs-material` (theme)
   - `mkdocs-mermaid2-plugin` (for diagrams)
4. **Build site**: Runs `mkdocs build` to generate static HTML
5. **Upload artifact**: Packages the built site
6. **Deploy**: Deploys to GitHub Pages using the official action

## Local Development

To preview documentation changes locally before pushing:

```bash
# Install dependencies
pip install mkdocs-material mkdocs-mermaid2-plugin

# Serve locally with live reload
mkdocs serve

# Build static site
mkdocs build
```

The local server will be available at: http://localhost:8000

## Updating Documentation

1. Edit markdown files in the `docs/` directory
2. Commit and push changes to a branch
3. Create a pull request
4. Once merged to `main`, the site automatically updates within 2-3 minutes

## Troubleshooting

### Deployment fails

Check the Actions tab for error details:
1. Go to **Actions** tab in the repository
2. Click on the failed workflow run
3. Review the job logs for errors

Common issues:
- Missing dependencies: Update the workflow to install additional packages
- Build errors: Check for syntax errors in markdown or mkdocs.yml
- Permission errors: Ensure the repository has Pages enabled with "GitHub Actions" source

### Site not updating

- Wait 2-3 minutes after the workflow completes
- Clear browser cache
- Check if the workflow actually ran (Actions tab)
- Verify Pages is still enabled in repository settings

### 404 errors

- Ensure Pages source is set to "GitHub Actions"
- Check that the workflow completed successfully
- Verify the site URL matches: https://seqeralabs.github.io/nf-proteindesign/

## Configuration

The site configuration is defined in `mkdocs.yml` at the repository root. Key settings:

- **Theme**: Material for MkDocs with custom styling
- **Features**: Navigation tabs, search, code copying, dark/light mode
- **Plugins**: Search and Mermaid diagram support
- **Extensions**: Code highlighting, admonitions, emoji support

To modify the site appearance or behavior, edit `mkdocs.yml` and the workflow will rebuild automatically on the next push to `main`.
