#!/usr/bin/env python3
"""
Fast SolidFire log preprocessor using pandas and polars
Converts logs to parquet format for fast Nushell processing
"""

import re
import json
import sys
from pathlib import Path
import polars as pl

def preprocess_sf_log(input_file: str, output_file: str, chunk_size: int = 50000):
    """Process large SolidFire log files in chunks"""
    
    # Regex patterns
    structured_pattern = re.compile(r'(\w+)=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}\}')
    kv_pattern = re.compile(r'(\w+)=([^}\s]+|\[[^\]]*\])')
    timestamp_pattern = re.compile(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^\s]*)')
    
    processed_data = []
    
    with open(input_file, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
                
            record = {'line_number': line_num}
            
            # Extract timestamp
            ts_match = timestamp_pattern.match(line)
            if ts_match:
                record['timestamp'] = ts_match.group(1)
            
            # Extract structured objects
            for match in structured_pattern.finditer(line):
                obj_name, obj_content = match.groups()
                
                # Parse details arrays specially
                details_match = re.search(r'details=\[([^\]]*)\]', obj_content)
                if details_match:
                    record[f'{obj_name}_details'] = details_match.group(1)
                
                # Parse other key-value pairs
                content_no_details = re.sub(r'details=\[[^\]]*\]', '', obj_content)
                for kv_match in kv_pattern.finditer(content_no_details):
                    key, value = kv_match.groups()
                    record[f'{obj_name}_{key}'] = value
            
            # Extract simple key-value pairs outside structured objects
            line_no_struct = structured_pattern.sub('', line)
            for kv_match in kv_pattern.finditer(line_no_struct):
                key, value = kv_match.groups()
                if key not in record:  # Avoid overwriting structured data
                    record[key] = value
            
            processed_data.append(record)
            
            # Process in chunks to manage memory
            if len(processed_data) >= chunk_size:
                save_chunk(processed_data, output_file, line_num - chunk_size + 1)
                processed_data = []
            
            if line_num % 10000 == 0:
                print(f"Processed {line_num} lines...")
    
    # Save remaining data
    if processed_data:
        save_chunk(processed_data, output_file, line_num - len(processed_data) + 1)
    
    print(f"Preprocessing complete! Output: {output_file}")

def save_chunk(data, base_filename, start_line):
    """Save chunk as parquet file"""
    df = pl.DataFrame(data)
    chunk_file = f"{base_filename}.chunk_{start_line}.parquet"
    df.write_parquet(chunk_file)
    print(f"Saved chunk: {chunk_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python sf_preprocessor.py input.log output_base")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_base = sys.argv[2]
    
    preprocess_sf_log(input_file, output_base)