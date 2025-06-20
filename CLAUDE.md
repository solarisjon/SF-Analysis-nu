# SolidFire Log Analysis Tool

## Project Overview
This is a SolidFire storage system log analysis tool built with Nushell. It parses structured SolidFire log files and converts them into tabular data for analysis.

## Key Components
- `src/parsesfv2.nu` - Main log parsing function
- `data/` - Contains SolidFire log files (sf-master.error, sf-master.info, etc.)
- `docs/www.nushell.sh/` - Local copy of Nushell language guide for reference
- `README.md` - The README file for publishing to bitbucket and github

## SolidFire Log Format
SolidFire logs use a structured format with:
- Nested objects in double braces: `clusterFault={{...}}`
- Key-value pairs: `key=value`
- Special arrays: `details=[...]`
- Mixed data types: strings, integers, floats, booleans

## Nushell Coding Standards
- Use descriptive variable names with snake_case
- Prefer `mut` for variables that change
- Use `let` for immutable bindings
- Break complex pipelines into readable steps
- Add type hints for function parameters
- Use structured error handling

## Common Analysis Patterns
- Parse logs with `parse-sf-logs`
- Filter by time ranges, error types, or components
- Group by cluster, node, or fault type
- Export results to CSV/JSON for external tools
- Use `where` for filtering, `group-by` for aggregation

## Testing
- Test parsing with sample log files in `data/`
- Verify data types are correctly converted
- Check column naming for duplicates
- Validate structured object extraction
- Ensure you at least run a test on `data/simplelog` to validate code changes
- `data/sf-master.info.18` is a good test file that is realistic of primary use case

## File Naming Conventions
- Use `.nu` extension for Nushell scripts
- Prefix parsing functions with `parse-`
- Use descriptive names: `parsesfv2.nu` not `parser.nu`

## Dependencies
- Nushell (latest version recommended)
- Local Nushell docs in `docs/` for reference
- If we use python code anywhere we use uv for package management not native pip

## Important Notes
- Always preserve original log structure when parsing
- Handle malformed log entries gracefully
- Maintain backward compatibility with existing data
- Document any changes to parsing logic
- Always update the README with usage cases, requirements, description, contributions, versions etc 
