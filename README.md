# SolidFire Log Analysis Tool

High-performance, two-stage log analysis system for SolidFire storage systems. Parse massive log files into structured data and create focused datasets for lightning-fast analysis with Nushell.

## Overview

This tool provides a complete workflow for analyzing SolidFire logs:

1. **Parse** massive log files into structured JSON with consistent schema
2. **Filter** into smaller, targeted datasets for specific analysis needs  
3. **Query** with full Nushell syntax for powerful data exploration

### Key Features

- 🚀 **High Performance**: 49K+ lines/sec parsing, 44K+ records/sec filtering
- 📊 **Complete Schema Discovery**: Finds ALL fields across entire log files (231+ columns)
- 🔍 **Consistent Data Structure**: Every record has identical columns, no missing field errors
- ⚡ **Fast Queries**: 10-100x performance improvement on filtered datasets
- 🛠️ **Flexible Filtering**: Time ranges, field values, component types
- 🔧 **Nushell Integration**: Full compatibility with Nushell's powerful query syntax

## Requirements

### System Requirements
- **Rust** (latest stable) - for building the parsers
- **Nushell** (latest) - for querying and data manipulation
- **macOS/Linux** - tested on Darwin 24.5.0+

### SolidFire Log Format Support
- Structured logs with format: `TIMESTAMP hostname process[pid]: [LEVEL] [COMPONENT] thread class source| content`
- Key-value pairs: `serviceID=230 usedBytes=1909106990888`
- Nested objects: `clusterFault={{id=743 type=Service severity=Critical}}`
- Arrays: `candidateNames={5-0000000014,177-0000000021}`
- Complex fields: `details=[Block service(s) on more than one node are unhealthy]`

## Installation

### Build the Parsers
```bash
# Build main parser
cd sf-parser-rust
cargo build --release

# Build filter utility  
cd ../sf-filter-rust
cargo build --release
```

### Verify Installation
```bash
# Check versions
./sf-parser-rust/target/release/sf-parser --version   # Should show 1.2.0
./sf-filter-rust/target/release/sf-filter --version   # Should show 1.0.0
```

## Quick Start

### 1. Parse Your Log File
```bash
# Parse complete SolidFire log into structured JSON
./sf-parser-rust/target/release/sf-parser data/sf-master.info -o data/output.json

# Output shows:
# 🔥 SolidFire Log Parser v1.2.0
# Phase 1: Discovering schema...
# Found 231 dynamic fields
# Phase 2: Parsing with consistent schema...
# Completed: 783733 lines in 15.97s (49087 lines/sec)
```

### 2. Filter for Focused Analysis
```bash
# Create smaller datasets for faster queries
./sf-filter-rust/target/release/sf-filter data/output.json \
  --start-time "04:30" --end-time "05:30" \
  -o data/morning-logs.json

# Output shows:  
# 🔍 SolidFire Log Filter v1.0.0
# Filtered 783733 → 2663 records in 338.13ms (44362 records/sec)
```

### 3. Query with Nushell
```bash
# Fast queries on filtered data
nu -c 'open data/morning-logs.json | where snapshotID == 13846639 | length'
nu -c 'open data/morning-logs.json | where component == "Snaps" | first 10'
nu -c 'open data/morning-logs.json | group-by component | columns'
```

## Use Cases & Examples

### Performance Analysis
```bash
# Filter API performance logs
./sf-filter-rust/target/release/sf-filter data/output.json \
  --field "component=API" \
  --start-time "08:00" --end-time "10:00" \
  -o data/api-performance.json

# Analyze slow operations
nu -c 'open data/api-performance.json | where totalMS > 1000 | sort-by totalMS | reverse'
```

### Snapshot Management Analysis
```bash
# Get all snapshot-related operations
./sf-filter-rust/target/release/sf-filter data/output.json \
  --field "component=Snaps" \
  -o data/snapshot-analysis.json

# Find snapshot deletion patterns
nu -c 'open data/snapshot-analysis.json | where content =~ "delete" | group-by snapshotID'

# Track specific snapshot lifecycle
./sf-filter-rust/target/release/sf-filter data/output.json \
  --field "snapshotID=13846639" \
  -o data/snapshot-13846639.json
```

### Service Health Monitoring
```bash
# Monitor specific service
./sf-filter-rust/target/release/sf-filter data/output.json \
  --field "serviceID=230" \
  -o data/service-230.json

# Check service errors during maintenance window
./sf-filter-rust/target/release/sf-filter data/output.json \
  --start-date "2025-06-12" \
  --start-time "02:00" --end-time "04:00" \
  --field "level=ERROR" \
  -o data/maintenance-errors.json
```

### Cluster Analysis
```bash
# Daily operational overview
./sf-filter-rust/target/release/sf-filter data/output.json \
  --start-date "2025-06-12" --end-date "2025-06-12" \
  -o data/daily-ops.json

# Analyze by time periods
nu -c 'open data/daily-ops.json | 
  insert hour ($it.time | str substring 0..2) | 
  group-by hour | 
  each { |group| {hour: $group.name, count: ($group.items | length)} }'
```

### Troubleshooting Workflows
```bash
# Find errors around specific time
./sf-filter-rust/target/release/sf-filter data/output.json \
  --start-time "14:25" --end-time "14:35" \
  --field "level=ERROR" \
  -o data/incident-analysis.json

# Correlate with warnings  
./sf-filter-rust/target/release/sf-filter data/output.json \
  --start-time "14:20" --end-time "14:40" \
  --field "level=WARN" \
  -o data/incident-warnings.json

# Multi-component analysis
nu -c 'open data/incident-analysis.json | group-by component | 
  each { |group| {component: $group.name, errors: ($group.items | length)} } |
  sort-by errors | reverse'
```

## Advanced Usage

### Multiple Field Filters
```bash
# Complex filtering scenarios
./sf-filter-rust/target/release/sf-filter data/output.json \
  --field "component=MS" \
  --field "serviceID=230" \
  --field "level=ERROR" \
  --start-time "08:00" \
  -o data/complex-filter.json
```

### Performance Optimization
```bash
# For massive datasets, filter progressively:

# 1. First by time (reduces 783K → ~50K)
./sf-filter-rust/target/release/sf-filter data/output.json \
  --start-date "2025-06-12" \
  -o data/today.json

# 2. Then by component (reduces 50K → ~5K)  
./sf-filter-rust/target/release/sf-filter data/today.json \
  --field "component=Snaps" \
  -o data/today-snapshots.json

# 3. Lightning-fast queries on 5K records
nu -c 'open data/today-snapshots.json | where snapshotID != null'
```

### Convenience Scripts
```bash
# Use provided convenience patterns
nu filter-examples.nu snapshots  # Filter all snapshot operations
nu filter-examples.nu morning    # Morning hours (04:30-05:30)
nu filter-examples.nu today      # Today's logs only

# Automated testing
nu test-nushell-queries.nu       # Verify query compatibility
```

## Parser Capabilities

### sf-parser v1.2.0 Features
- **Strategic Sampling**: Discovers fields throughout entire file, not just first 1000 lines
- **Parallel Processing**: Multi-threaded parsing with Rayon
- **Schema Consistency**: Every record has identical column structure
- **Type Conversion**: Automatic detection of integers, floats, booleans
- **Complex Data**: Handles nested objects, arrays, and structured content
- **Error Handling**: Graceful parsing of malformed entries

### sf-filter v1.0.0 Features
- **Time Filtering**: Date ranges, time ranges, or both
- **Field Filtering**: Exact matches on any field value
- **Multiple Filters**: Combine time and field filters
- **Parallel Processing**: Fast filtering with Rayon
- **Custom Output**: Specify output file names
- **Progress Reporting**: Shows filtering statistics

## Schema Structure

### Core Fields (Always Present)
```bash
line_num          # Line number in original file
date              # YYYY-MM-DD 
time              # HH:MM:SS.ffffff
timestamp         # Full ISO timestamp
hostname          # SolidFire node hostname
process           # Process name (e.g., "master-1")
pid               # Process ID
level             # Log level (APP-5, ERROR, WARN, etc.)
component         # SolidFire component (MS, Snaps, API, etc.)
thread            # Thread ID
class             # C++ class name
source            # Source file and line
content           # Original log message content
raw_line          # Complete original log line
parse_error       # null or error description
```

### Dynamic Fields (231+ discovered)
All fields found throughout the log file, including:
- `serviceID`, `snapshotID`, `volumeID`, `groupSnapshotID`
- `usedBytes`, `totalMS`, `responseCreationMS`
- `component`, `level`, `severity`, `code`
- Complex nested data from SolidFire operations

## Performance Benchmarks

### Parsing Performance
- **Large Files**: 783K lines in ~16 seconds (49K lines/sec)
- **Schema Discovery**: 231 fields found across entire file
- **Memory Efficient**: Chunked processing prevents memory overflow
- **Parallel**: Multi-core utilization for maximum speed

### Filtering Performance  
- **Time Filtering**: 783K → 2.6K records in 338ms (44K records/sec)
- **Field Filtering**: Complex filters with minimal performance impact
- **Memory Usage**: Processes data in parallel chunks

### Query Performance
- **Original File**: 783K records, queries timeout or take minutes
- **Filtered Files**: 2-5K records, queries complete in milliseconds
- **Improvement**: 10-100x faster query execution

## Troubleshooting

### Common Issues

**"Cannot find column 'snapshotID'"**
- Solution: Ensure using sf-parser v1.2.0 (check with `--version`)
- Cause: Older versions only sampled first 1000 lines

**Queries are slow**  
- Solution: Use sf-filter to create smaller datasets first
- Example: Filter by time/component before complex queries

**Parser not finding all fields**
- Solution: Verify using v1.2.0 with strategic sampling
- Check: Parser should show "Found 231 dynamic fields"

**Time filtering not working**
- Solution: Check time format (HH:MM or HH:MM:SS)
- Solution: Check date format (YYYY-MM-DD)
- Note: Records with parse errors may have empty time fields

### Getting Help
```bash
./sf-parser-rust/target/release/sf-parser --help
./sf-filter-rust/target/release/sf-filter --help
nu filter-examples.nu  # Shows usage patterns
```

## Version History

- **v2.0** (Current) - Complete two-stage solution
  - sf-parser v1.2.0: Strategic sampling, finds all fields
  - sf-filter v1.0.0: Fast filtering utility
  - Complete nushell compatibility
  - Comprehensive documentation

- **v1.2.0** - Fixed schema discovery throughout entire files
- **v1.1.0** - Added unit tests and nushell validation  
- **v1.0.0** - Initial high-performance Rust parser

## Contributing

When making changes:
1. Update version numbers in Cargo.toml files
2. Run tests: `cargo test` and `nu test-nushell-queries.nu`
3. Update documentation for new features
4. Follow commit message conventions for version tracking

## License

SolidFire Analysis Tool - Internal tooling for SolidFire log analysis.