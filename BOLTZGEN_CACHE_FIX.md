# Boltzgen Local Cache Fix

## Summary

Fixed the issue where the `--cache_dir` parameter was referenced but the cache files were not actually being staged into the process work directory. Now when you specify a local cache directory, Nextflow will properly stage the cache files so Boltzgen can use them.

## Changes Made

### 1. Updated `modules/local/boltzgen_run.nf`

**Added cache directory as an input:**
```groovy
input:
tuple val(meta), path(design_yaml), path(structure_files)
path cache_dir, stageAs: 'input_cache/*'
```

The `stageAs: 'input_cache/*'` directive ensures the cache directory contents are staged into a subdirectory called `input_cache` in the work directory.

**Updated script logic:**
- Now checks if a cache directory was provided (not the `EMPTY_CACHE` placeholder)
- Uses `--cache input_cache` when a cache is provided, or `--cache cache` to create a new cache
- Sets `HF_HOME` to point to the staged cache directory
- Only creates a new cache directory if no cache was provided

### 2. Updated `main.nf`

**Added cache directory channel creation:**
```groovy
// If cache_dir is specified, stage it as input; otherwise use empty placeholder
if (params.cache_dir) {
    ch_cache = Channel
        .fromPath(params.cache_dir, type: 'dir', checkIfExists: true)
        .first()
} else {
    // Create a placeholder file when no cache is provided
    ch_cache = Channel.value(file('EMPTY_CACHE'))
}
```

**Updated workflow call:**
```groovy
PROTEIN_DESIGN(ch_input, ch_cache, workflow_mode)
```

### 3. Updated Workflow Files

Updated all workflow files to accept and pass the cache channel:
- `workflows/protein_design.nf`
- `workflows/p2rank_to_designs.nf`
- `workflows/target_to_designs.nf`

## Usage

### Without Local Cache (Default Behavior)

If you don't specify `--cache_dir`, Boltzgen will download models as needed:

```bash
nextflow run main.nf --input samplesheet.csv --outdir results
```

### With Local Cache (Pre-downloaded Models)

If you have already downloaded the Boltzgen models (~6GB), you can specify the cache directory to avoid re-downloading:

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --cache_dir /path/to/boltzgen/cache
```

The cache directory should contain the HuggingFace model files that Boltzgen needs. You can pre-populate this by running Boltzgen once and copying the cache from `~/.cache/huggingface/` or wherever it was downloaded.

### Example: Creating a Cache Directory

```bash
# Run once to download models
mkdir -p /shared/boltzgen_cache
export HF_HOME=/shared/boltzgen_cache
boltzgen run example.yaml --cache /shared/boltzgen_cache --output test_output

# Now use this cache in the pipeline
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --cache_dir /shared/boltzgen_cache
```

## Benefits

1. **Faster Execution**: Avoid re-downloading ~6GB of model weights for each run
2. **Network Efficiency**: Especially useful in environments with limited network bandwidth
3. **Reproducibility**: Use a fixed version of model weights
4. **Multi-run Efficiency**: Share the cache across multiple pipeline runs

## Technical Details

- The cache directory is staged into each task's work directory as `input_cache/`
- Nextflow handles symlinking the cache files efficiently, so no duplication occurs
- The `EMPTY_CACHE` placeholder file is used when no cache is provided, allowing the process to handle both scenarios
- The `stageAs` directive ensures the cache contents are accessible at a predictable path
