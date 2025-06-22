# Large Data Files

The following files are excluded from the repository due to GitHub's 100MB size limit:

-  (285MB) - Main SolidFire log file for testing
-  (196-300MB) - SolidFire error logs  
-  (4.5GB) - Parsed output from sf-parser
-  (712MB) - Filtered subset from sf-filter

## Sample Data Included

Small sample files are included for testing:
-  - Small test log for development
-  - Sample parsed output
-  - Small filtered datasets

## Usage

Place your SolidFire log files in the data/ directory:
```bash
# Copy your log file
cp /path/to/your/sf-master.info data/

# Parse it
./sf-parser-rust/target/release/sf-parser data/sf-master.info -o data/output.json
```
