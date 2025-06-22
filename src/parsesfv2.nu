def parse-sf-logs [file_path: string, --columns-info] {
  let lines = (open $file_path | lines)
  
  # First pass: collect all possible column names from all lines
  print "First pass: discovering schema..."
  let all_columns = (
    $lines
    | each { |line|
        mut columns = []
        
        # Extract structured objects columns
        let structured_objects = ($line | parse --regex '(\w+)=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}')
        for obj in $structured_objects {
          let obj_name = $obj.capture0
          let obj_content = $obj.capture1
          
          # Details columns
          let details_matches = ($obj_content | parse --regex 'details=\[([^\]]*)\]')
          if ($details_matches | length) > 0 {
            let col_name = "complex_" + $obj_name
            $columns = ($columns | append $col_name)
          }
          
          # Other key=value pairs in objects
          let content_no_details = ($obj_content | str replace --all --regex 'details=\[[^\]]*\]' '')
          let obj_kv_matches = ($content_no_details | parse --regex '(\w+)=([^}\s]+|\{[^}]*\})')
          for match in $obj_kv_matches {
            let key = $match.capture0
            $columns = ($columns | append $key)
          }
        }
        
        # Extract regular key=value pairs
        let line_without_structured = ($line | str replace --all --regex '\w+=\{\{[^}]+\}\}' '')
        let remaining_kv_matches = ($line_without_structured | parse --regex '(\w+)=([^}\s]+|\[[^\]]*\])')
        for match in $remaining_kv_matches {
          let key = $match.capture0
          $columns = ($columns | append $key)
        }
        
        $columns
      }
    | flatten
    | append ["line_num", "date", "time", "timestamp", "hostname", "process", "pid", "level", "component", "thread", "class", "source", "content", "raw_line", "parse_error"]
    | uniq
  )
  
  print $"Schema discovered: ($all_columns | length) columns"
  
  # Second pass: parse each line with consistent schema
  print "Second pass: parsing with consistent schema..."
  $lines
  | enumerate
  | each { |item|
      let line_num = $item.index + 1
      let line = $item.item
      
      # Initialize record with all columns as null
      mut record = ($all_columns | reduce -f {} { |col, acc| $acc | insert $col null })
      
      # Set line metadata
      $record = ($record | upsert "line_num" $line_num)
      $record = ($record | upsert "raw_line" $line)
      $record = ($record | upsert "parse_error" null)
      
      # Parse structured SolidFire log format
      let log_parts = ($line | parse --regex '^(\d{4}-\d{2}-\d{2}T[\d:.]+Z)\s+(\S+)\s+([^\[]+)\[(\d+)\]:\s+\[([^\]]+)\]\s+\[([^\]]+)\]\s+(\d+)\s+(\S+)\s+([^|]+)\|\s*(.*)$')
      
      if ($log_parts | length) > 0 {
        let parts = ($log_parts | first)
        $record = ($record | upsert "timestamp" $parts.capture0)
        $record = ($record | upsert "hostname" $parts.capture1)
        $record = ($record | upsert "process" $parts.capture2)
        $record = ($record | upsert "pid" ($parts.capture3 | into int))
        $record = ($record | upsert "level" $parts.capture4)
        $record = ($record | upsert "component" $parts.capture5)
        $record = ($record | upsert "thread" ($parts.capture6 | into int))
        $record = ($record | upsert "class" $parts.capture7)
        $record = ($record | upsert "source" $parts.capture8)
        $record = ($record | upsert "content" $parts.capture9)
        
        # Extract date and time from timestamp
        let timestamp_parts = ($parts.capture0 | split row "T")
        $record = ($record | upsert "date" $timestamp_parts.0)
        let time_part = ($timestamp_parts.1 | split row "." | get 0)
        $record = ($record | upsert "time" $time_part)
        
        # Parse content for key=value pairs
        let content = $parts.capture9
        
        # Extract structured objects like clusterFault={{...}}
        let structured_objects = ($content | parse --regex '(\w+)=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}')
        for obj in $structured_objects {
          let obj_name = $obj.capture0
          let obj_content = $obj.capture1
          
          # Handle details as complex field
          let details_matches = ($obj_content | parse --regex 'details=\[([^\]]*)\]')
          if ($details_matches | length) > 0 {
            let col_name = "complex_" + $obj_name
            $record = ($record | upsert $col_name $obj_content)
          }
          
          # Parse other key=value pairs in the object
          let content_no_details = ($obj_content | str replace --all --regex 'details=\[[^\]]*\]' '')
          let obj_kv_matches = ($content_no_details | parse --regex '(\w+)=([^}\s]+|\{[^}]*\})')
          for match in $obj_kv_matches {
            let key = $match.capture0
            let value = $match.capture1
            
            let parsed_value = if ($value == "true") {
              true
            } else if ($value == "false") {
              false
            } else if ($value =~ '^\d+$') {
              ($value | into int)
            } else if ($value =~ '^\d+\.\d+$') {
              ($value | into float)
            } else {
              $value
            }
            
            $record = ($record | upsert $key $parsed_value)
          }
        }
        
        # Extract regular key=value pairs
        let line_without_structured = ($content | str replace --all --regex '\w+=\{\{[^}]+\}\}' '')
        let remaining_kv_matches = ($line_without_structured | parse --regex '(\w+)=([^}\s]+|\[[^\]]*\])')
        for match in $remaining_kv_matches {
          let key = $match.capture0
          let value = $match.capture1
          
          let parsed_value = if (($value | str starts-with "[") and ($value | str ends-with "]")) {
            $value | str substring 1..(($value | str length) - 1)
          } else if ($value == "true") {
            true
          } else if ($value == "false") {
            false
          } else if ($value =~ '^\d+$') {
            ($value | into int)
          } else if ($value =~ '^\d+\.\d+$') {
            ($value | into float)
          } else {
            $value
          }
          
          $record = ($record | upsert $key $parsed_value)
        }
      } else {
        $record = ($record | upsert "parse_error" "Failed to parse log format")
        $record = ($record | upsert "content" $line)
      }
      
      $record
    }
  | if $columns_info {
      let data = $in
      if ($data | length) > 0 {
        print $"Total rows: ($data | length)"
        let first_row = ($data | first)
        let first_cols = ($first_row | columns)
        print $"Columns in first row: ($first_cols | length)"
        print $"Sample columns: (($first_cols | first 10) | str join ', ')"
        
        # Display first row with first 5 columns
        let display_cols = ($first_cols | first 5)
        $data | first | select ...$display_cols
      } else {
        print "No data to display"
        $data
      }
    } else {
      $in
    }
}