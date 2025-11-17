# Summary of Changes - Boltzgen Cache Fix

## Problem
The pipeline had a parameter `--cache_dir` to specify a local cache directory for Boltzgen models, but the cache directory was not being staged as an input to the process. This meant:
- The parameter was referenced but not actually used
- Files in the cache directory were not accessible to the Boltzgen process
- Models would be re-downloaded every run, even when a cache was specified

## Solution
Updated the pipeline to properly stage the cache directory as a process input, making it available to Boltzgen.

## Files Modified

### 1. `modules/local/boltzgen_run.nf`
- **Added**: Cache directory as a process input with `stageAs: 'input_cache/*'`
- **Modified**: Script logic to detect and use staged cache
- **Modified**: Environment variable `HF_HOME` to point to staged cache
- **Modified**: Boltzgen command to use correct cache path

### 2. `main.nf`
- **Added**: Channel creation for cache directory
- **Added**: Logic to use placeholder when no cache is specified
- **Modified**: Workflow call to pass cache channel

### 3. `workflows/protein_design.nf`
- **Added**: Cache channel as workflow input
- **Modified**: BOLTZGEN_RUN call to include cache channel

### 4. `workflows/p2rank_to_designs.nf`
- **Added**: Cache channel as workflow input
- **Modified**: BOLTZGEN_RUN call to include cache channel

### 5. `workflows/target_to_designs.nf`
- **Added**: Cache channel as workflow input
- **Modified**: BOLTZGEN_RUN call to include cache channel

## How It Works

### Without Cache (Default)
```bash
nextflow run main.nf --input samplesheet.csv --outdir results
```
- Creates `EMPTY_CACHE` placeholder file
- Process creates new cache directory and downloads models
- Behavior same as before

### With Cache
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    --cache_dir /path/to/cache
```
- Validates cache directory exists
- Stages cache contents into work directory as `input_cache/`
- Boltzgen uses pre-existing models from staged cache
- No re-downloading of ~6GB model weights

## Key Implementation Details

1. **`stageAs: 'input_cache/*'`**: Ensures cache is staged with predictable path
2. **EMPTY_CACHE placeholder**: Allows process to handle both scenarios (with/without cache)
3. **Conditional logic**: Script checks cache filename to determine which path to use
4. **Environment variables**: `HF_HOME` points to staged cache location
5. **Efficient staging**: Nextflow uses symlinks, no data duplication

## Testing

The configuration parses successfully:
```bash
nextflow config -profile test
```

## Next Steps

To test with actual data:

1. **Without cache** (will download models):
   ```bash
   nextflow run main.nf -profile test
   ```

2. **With pre-existing cache**:
   ```bash
   nextflow run main.nf -profile test --cache_dir /path/to/cache
   ```

## Benefits

✅ **Performance**: Avoid re-downloading 6GB of models  
✅ **Network Efficiency**: Reduce bandwidth usage  
✅ **Reproducibility**: Use fixed model versions  
✅ **Resource Sharing**: Share cache across multiple runs  
✅ **Backward Compatible**: Works with or without cache specified
