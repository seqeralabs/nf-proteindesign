# URL Support for Structure Files

The pipeline supports using URLs for structure files in addition to local file paths.

## Usage

Simply provide a URL in the `target_structure` field of your samplesheet:

```csv
sample_id,target_structure,target_chain_ids,min_length,max_length,length_step,n_variants_per_length,design_type,protocol,num_designs,budget
my_sample,https://files.rcsb.org/download/1IVO.cif,A,100,100,1,1,protein,protein-anything,3,1
```

## Supported URLs

- RCSB PDB: `https://files.rcsb.org/download/{PDB_ID}.cif`
- Any publicly accessible HTTP/HTTPS URL ending in `.pdb` or `.cif`

## Example

```csv
sample_id,target_structure,target_chain_ids,min_length,max_length,length_step,n_variants_per_length,design_type,protocol,num_designs,budget
egfr_pdb,https://files.rcsb.org/download/1IVO.cif,A,100,100,1,1,protein,protein-anything,3,1
local_file,data/my_structure.cif,A,100,100,1,1,protein,protein-anything,3,1
```

## Notes

- URLs must be publicly accessible (no authentication required)
- Files are automatically downloaded and staged by Nextflow
- Downloaded files are cached in the work directory for reuse
