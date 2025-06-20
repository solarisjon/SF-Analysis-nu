# Helper function to load JSONL files efficiently
def load-jsonl [file_path: string] {
  open $file_path | lines | each { |line| $line | from json }
}

# Quick loader for the preprocessed SF data
def load-sf-data [
  --type: string  # Wildcard pattern to filter columns (e.g., "*snap*", "*ID", "time*")
  --limit: int    # Limit number of rows returned
] {
  mut data = load-jsonl "output/sf-master.info.18.jsonl"
  
  # Apply column filtering if --type is specified
  if ($type != null and ($data | length) > 0) {
    let all_columns = ($data | columns)
    let search_term = ($type | str replace -a '*' '')
    let filtered_columns = ($all_columns | where { |col| $col | str contains --ignore-case $search_term })
    
    if ($filtered_columns | is-empty) {
      error make { msg: $"No columns match pattern: ($type)" }
    }
    
    # Always include core columns (only those that exist)
    let core_columns = ["date", "time", "serviceID", "sliceID"]
    let columns_to_select = ($core_columns | append $filtered_columns | uniq)
    
    # Filter data to only show rows that have at least one matching column
    $data = ($data | each { |row| 
      let row_columns = ($row | columns)
      let matching_cols = ($columns_to_select | where { |col| $col in $row_columns })
      if ($matching_cols | is-empty) {
        null
      } else {
        $row | select ...$matching_cols
      }
    } | where { |row| $row != null })
  }
  
  # Apply row limit if specified
  if ($limit != null) {
    $data = ($data | first $limit)
  }
  
  $data
}

# Load with sample size for testing
def load-sf-sample [size: int = 1000] {
  load-jsonl "output/sf-master.info.18.jsonl" | first $size
}

# Load simplelog data for testing
def load-sf-test [
  --type: string  # Wildcard pattern to filter columns
  --limit: int    # Limit number of rows returned
] {
  mut data = load-jsonl "output/simplelog.jsonl"
  
  # Apply column filtering if --type is specified
  if ($type != null and ($data | length) > 0) {
    let all_columns = ($data | columns)
    let search_term = ($type | str replace -a '*' '')
    let filtered_columns = ($all_columns | where { |col| $col | str contains --ignore-case $search_term })
    
    if ($filtered_columns | is-empty) {
      error make { msg: $"No columns match pattern: ($type)" }
    }
    
    # Always include core columns (only those that exist)
    let core_columns = ["date", "time", "serviceID", "sliceID"]
    let columns_to_select = ($core_columns | append $filtered_columns | uniq)
    
    # Filter data to only show rows that have at least one matching column
    $data = ($data | each { |row| 
      let row_columns = ($row | columns)
      let matching_cols = ($columns_to_select | where { |col| $col in $row_columns })
      if ($matching_cols | is-empty) {
        null
      } else {
        $row | select ...$matching_cols
      }
    } | where { |row| $row != null })
  }
  
  # Apply row limit if specified
  if ($limit != null) {
    $data = ($data | first $limit)
  }
  
  $data
}