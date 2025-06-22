# SolidFire Log Analysis Tool

A flexible Nushell-based parser for SolidFire storage system logs that converts structured log files into searchable JSON format.

## Overview

This tool parses SolidFire `sf-master.info` log files into structured JSON data that can be easily queried using Nushell's powerful data manipulation commands.

## Features

- **Flexible parsing**: Handles multiple SolidFire log formats with graceful degradation
- **Structured output**: Converts logs to JSON for easy analysis with `open` command
- **Type conversion**: Automatically converts numeric values and preserves data types
- **Error handling**: Gracefully handles malformed log entries
- **Fast processing**: Efficient parsing of large log files (1M+ lines)
- **UTC timezone**: Separates date and time fields in UTC timezone

## Usage

### Basic Usage

```bash
# Parse a log file
nu sf-log-parser.nu data/sf-master.info.18

# Specify output file
nu sf-log-parser.nu data/sf-master.info.18 output/parsed-log.json
```

### Analysis Examples

Once parsed, you can use Nushell's powerful query capabilities:

```bash
# Open and explore the parsed data
open sf-master-parsed.json

# Filter by service ID
open sf-master-parsed.json | where serviceID == 230

# Find logs from specific time range
open sf-master-parsed.json | where date == "2025-06-05" and time > "09:00:00"

# Group by component and count
open sf-master-parsed.json | group-by component | transpose component count

# Find error logs
open sf-master-parsed.json | where level == "ERROR"

# Search for specific content
open sf-master-parsed.json | where content =~ "snapshot"

# Get unique hostnames
open sf-master-parsed.json | get hostname | uniq

# Show top services by usage
open sf-master-parsed.json | where usedBytes != null | sort-by usedBytes -r | first 10
```

## Log Format Support

The parser handles multiple SolidFire log formats:

### Standard Format
```
2025-06-05T00:20:07.858372Z icpbasi03037 master-1[112875]: [APP-5] [MS] 2069182 BSDirector ms/ClusterStatistics.cpp:1452:GetBlockDriveUsageFromStats| serviceID=230 usedBytes=1909106990888
```

### API Call Format
```
2025-06-05T09:55:03.019876Z icpbasi03037 master-1[112875]: [APP-5] [API] 2069183 Scheduler httpserver/RestAPIServer.cpp:321:LogAndDispatch|RestAPI::CreateGroupSnapshot CALL: requestID=null logJson[kParamsKey]={"enableRemoteReplication":true}
```

### Complex Nested Format
```
2025-06-05T00:20:07.869764Z icpbasi03037 master-1[112875]: [APP-5] [BSDirector] 2069182 BSDirector ms/BinSyncUtil.cpp:160:BlockServiceSpaceUsageInfo|BlockServiceSpaceUsageInfo {mAvailableServicesUsableCapacity={633550625832960,0}}
```

## Output Structure

Each parsed log entry includes:

### Standard Fields
- `line_num`: Original line number
- `date`: Date in YYYY-MM-DD format (UTC)
- `time`: Time in HH:MM:SS.ffffff format (UTC)
- `timestamp`: Original ISO 8601 timestamp
- `hostname`: Server hostname
- `process`: Process name
- `pid`: Process ID
- `level`: Log level (APP-5, ERROR, etc.)
- `component`: Component name (MS, API, Snaps, etc.)
- `thread`: Thread ID
- `class`: Class name
- `source`: Source file and function
- `content`: Raw log content
- `raw_line`: Original log line
- `parse_error`: null if parsed successfully

### Dynamic Fields
Key=value pairs from log content become individual columns:
- `serviceID`: Service identifier
- `usedBytes`: Storage usage in bytes
- `requestID`: API request ID
- And many more depending on log content...

## File Structure

```
├── sf-log-parser.nu          # Main parser script
├── data/
│   ├── sf-master.info.18     # Sample log file
│   └── sf-smallmaster        # Small test file (100 lines)
├── README.md                 # This file
└── CLAUDE.md                # Project instructions
```

## Requirements

- **Nushell**: Latest version
- **Memory**: Sufficient RAM for log file size (JSON output uses more memory than original)
- **Storage**: ~2-3x original file size for JSON output

## Performance

- **Small files** (< 1MB): Sub-second parsing
- **Medium files** (1-100MB): Seconds to minutes
- **Large files** (> 100MB): Minutes, progress shown every 10,000 lines

## Examples

### Quick Start
```bash
# Parse the test file
nu sf-log-parser.nu data/sf-smallmaster

# View results
open sf-smallmaster-parsed.json | first 5

# Find all entries for service 230
open sf-smallmaster-parsed.json | where serviceID == 230
```

### Advanced Analysis
```bash
# Storage usage analysis
open sf-master-parsed.json 
| where usedBytes != null 
| select serviceID usedBytes 
| group-by serviceID 
| transpose serviceID usage 
| sort-by usage -r

# Timeline analysis
open sf-master-parsed.json 
| select date time component level 
| where level != "APP-5" 
| sort-by date time

# Error investigation
open sf-master-parsed.json 
| where content =~ "error|failed|exception" 
| select time hostname component content
```

## Troubleshooting

### Common Issues

1. **Parse errors**: Check log format variations, parser handles most cases gracefully
2. **Memory issues**: Process large files in chunks or use streaming approach
3. **Performance**: Consider filtering during parsing for very large files

### Debug Information

The parser provides detailed feedback:
- Line count processed
- Success/error statistics
- Processing time
- Usage examples

## Contributing

This tool follows the project's coding standards:
- Nushell snake_case conventions
- Graceful error handling
- Type hints on functions
- Comprehensive testing with sample data

## Testing

Use the provided test file:
```bash
# Test with small sample
nu sf-log-parser.nu data/sf-smallmaster

# Verify output structure
open sf-smallmaster-parsed.json | columns
```