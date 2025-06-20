def parse-sf-logs [file_path: string, --columns-info] {
  open $file_path
  | lines
  | each { |line|
      mut record = {}
      mut counter = 0
      
      # Extract structured objects like clusterFault={{...}}  
      let structured_objects = ($line | parse --regex '(\w+)=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}')
      
      for obj in $structured_objects {
        let obj_name = $obj.capture0
        let obj_content = $obj.capture1
        
        # Extract details separately (keep as full string)
        let details_matches = ($obj_content | parse --regex 'details=\[([^\]]*)\]')
        for detail_match in $details_matches {
          let col_name = $obj_name + "(details)_" + ($counter | into string)
          $counter = $counter + 1
          $record = ($record | insert $col_name $detail_match.capture0)
        }
        
        # Parse other key=value pairs in the object (excluding details)
        let content_no_details = ($obj_content | str replace --all --regex 'details=\[[^\]]*\]' '')
        let obj_kv_matches = ($content_no_details | parse --regex '(\w+)=([^}\s]+|\{[^}]*\})')
        
        for match in $obj_kv_matches {
          let key = $match.capture0
          let value = $match.capture1
          
          # Use object name as prefix for column name with counter to avoid duplicates
          let col_name = $obj_name + "(" + $key + ")_" + ($counter | into string)
          $counter = $counter + 1
          
          # Parse value type
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
          
          $record = ($record | insert $col_name $parsed_value)
        }
      }
      
      # Extract other key=value pairs outside structured objects
      let line_without_structured = ($line | str replace --all --regex '\w+=\{\{[^}]+\}\}' '')
      let remaining_kv_matches = ($line_without_structured | parse --regex '(\w+)=([^}\s]+|\[[^\]]*\])')
      
      for match in $remaining_kv_matches {
        let key = $match.capture0
        let value = $match.capture1
        
        # Handle duplicate column names
        let col_name = if ($record | columns | any { |c| $c == $key }) {
          $"($key)_($counter)"
        } else {
          $key
        }
        $counter = $counter + 1
        
        # Handle bracketed values specially
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
        
        $record = ($record | insert $col_name $parsed_value)
      }
      
      # Add space-separated columns for remaining text
      let line_clean = ($line 
        | str replace --all --regex '\w+=\{\{[^}]+\}\}' '' 
        | str replace --all --regex '\w+=\[[^\]]*\]' '' 
        | str replace --all --regex '\w+=[^}\s\[]+' '')
      let parts = ($line_clean | split row " " | where { |part| ($part | str trim) != "" and $part != "}" })
      
      mut col_index = 0
      for part in $parts {
        # Extract date and time from timestamp if this is col_0
        if $col_index == 0 and ($part =~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') {
          let timestamp_parts = ($part | split row "T")
          $record = ($record | insert "date" $timestamp_parts.0)
          let time_part = ($timestamp_parts.1 | split row "." | get 0)
          $record = ($record | insert "time" $time_part)
        }
        
        $record = ($record | insert $"col_($col_index)" $part)
        $col_index = $col_index + 1
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