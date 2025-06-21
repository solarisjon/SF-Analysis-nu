# SolidFire Log Analysis Tool

## Overview
Nushell-based SolidFire storage log parser that converts structured logs to tabular data.

## Structure
- `src/parsesfv2.nu` - Main parser
- `data/` - SolidFire log files
- Test files: `data/simplelog`, `data/sf-master.info.18`

## SolidFire Log Format
- Nested objects: `clusterFault={{...}}`
- Key-value pairs: `key=value`
- Arrays: `details=[...]`

## Standards
- snake_case variables, `mut` for mutable, `let` for immutable
- Type hints on function parameters
- Graceful error handling for malformed entries
- Preserve original log structure

## Dependencies
- Nushell (latest)
- Python packages via `uv` (not pip) 

## Nushell
- The most up to date language spec and information can be found locally at: /Users/solarisjon/Documents/nushell-docs
- Ensure any nushell code complies with this documentation

# Source Code Management
- Please ensure new commits are done in github on any major changes made and document those commits clearly

# README.md
- All coding projects will have a README.md file this should be kept current at all times with any changes such as:
	- new files
	- new or changed  options
	- new use cases

# Tests
- ensure any code changes are tested I will always try and provide a sample data file please ask me if not sure
- if you think there is a better way of doing things suggest then ( up to 5 ) and give pro's and cons
