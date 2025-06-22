# SolidFire Log Analysis - Two-Stage Parser Solution

## Overview
Fast, efficient SolidFire log analysis using a two-stage approach:
1. **sf-parser v1.2.0** - Parse massive log files into consistent JSON
2. **sf-filter v1.0.0** - Create smaller, focused datasets for lightning-fast queries

## Quick Start

### Stage 1: Parse Full Log File
```bash
# Parse your massive SolidFire log file (once)
./sf-parser-rust/target/release/sf-parser data/sf-master.info -o data/output.json

# Shows progress and finds ALL possible fields (231+ columns)
# Creates consistent schema - every row has same columns
```

### Stage 2: Filter for Fast Queries
```bash
# Create smaller datasets for specific analysis:

# Time range filtering
./sf-filter-rust/target/release/sf-filter data/output.json --start-time "04:30" --end-time "5:30" -o data/morning.json

# Field filtering 
./sf-filter-rust/target/release/sf-filter data/output.json --field "snapshotID=13846639" -o data/snapshot-13846639.json

# Component filtering
./sf-filter-rust/target/release/sf-filter data/output.json --field "component=Snaps" -o data/snapshots-only.json

# Combined filters
./sf-filter-rust/target/release/sf-filter data/output.json --start-time "08:00" --field "component=Snaps" --field "serviceID=230"
```

### Stage 3: Lightning-Fast Nushell Queries
```bash
# Query the small filtered files (10-100x faster!)
nu -c 'open data/morning.json | where snapshotID == 13846639 | length'
nu -c 'open data/snapshots-only.json | where ($it.snapshotID | is-not-empty) | length'
nu -c 'open data/snapshot-13846639.json | first 10'
```

## Performance Benefits

### Before (Single Large File)
- 783K records in output.json 
- Queries timeout or take minutes
- High memory usage
- Cannot find snapshotID fields

### After (Filtered Files)
- 783K → 2-5K records in filtered files
- Queries complete in seconds
- Low memory usage
- All fields consistently available

## Version Tracking

Current versions:
- **sf-parser: v1.2.0** - Full file parsing with complete schema discovery
- **sf-filter: v1.0.0** - Fast filtering for targeted analysis

Check versions:
```bash
./sf-parser-rust/target/release/sf-parser --version
./sf-filter-rust/target/release/sf-filter --version
```

## Common Patterns

Use the convenience script for common operations:
```bash
nu filter-examples.nu snapshots  # Filter snapshot logs
nu filter-examples.nu morning    # Filter morning time range  
nu filter-examples.nu today      # Filter today's logs
```

## Troubleshooting

**"Cannot find column 'snapshotID'"** 
- Ensure you used sf-parser v1.2.0 (not older versions)
- v1.2.0 samples throughout entire file to find all fields

**Queries are slow**
- Use sf-filter to create smaller datasets first
- Query the filtered files instead of the massive output.json

**Time filtering not working**
- Check time format: use "HH:MM" or "HH:MM:SS" 
- Check date format: use "YYYY-MM-DD"
- Records with parsing errors may have empty time fields