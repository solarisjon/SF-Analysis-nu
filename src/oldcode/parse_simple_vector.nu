def parse-sf-logs-simple [file_path: string] {
  # Update config to use the correct file path
  let original_config = (open simple_vector.toml --raw)
  let updated_config = ($original_config | str replace './simplelog' $file_path)
  $updated_config | save temp_vector.toml
  
  # Run vector and capture output
  let raw_output = (vector --config temp_vector.toml | complete)
  
  # Clean up temp file
  rm -f temp_vector.toml
  
  if $raw_output.exit_code != 0 {
    error make {msg: $"Vector failed: ($raw_output.stderr)"}
  }
  
  # Parse the JSON output
  $raw_output.stdout 
  | lines 
  | where $it != ""
  | each { |line| 
      try { 
        $line | from json 
      } catch { 
        null 
      } 
    }
  | where $it != null
}

# Function to demonstrate Vector's advantages
def parse-sf-logs-hybrid [file_path: string] {
  # Use Vector for initial parsing, then Nushell for complex transformations
  let vector_parsed = parse-sf-logs-simple $file_path
  
  $vector_parsed | each { |record|
    mut output = {}
    
    # Basic columns from Vector parsing
    $output.col_0 = ($record.host? | default "")
    $output.col_1 = ($record.timestamp? | default "")  
    $output.col_2 = ($record.node? | default "")
    $output.col_3 = ($record.service? | default "")
    
    # Use Nushell for complex clusterFault parsing
    let message_content = ($record.message_content? | default "")
    if ($message_content | str contains "clusterFault={{") {
      let fault_match = ($message_content | parse --regex 'clusterFault=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}')
      if ($fault_match | length) > 0 {
        let fault_content = $fault_match.0.capture0
        
        # Parse details
        let details_match = ($fault_content | parse --regex 'details=\[([^\]]*)\]')
        if ($details_match | length) > 0 {
          $output."clusterFault(details)" = $details_match.0.capture0
        }
        
        # Parse other key=value pairs
        let content_no_details = ($fault_content | str replace --all --regex 'details=\[[^\]]*\]' '')
        let kv_matches = ($content_no_details | parse --regex '(\w+)=([^}\s]+|\{[^}]*\})')
        
        mut counter = 0
        for match in $kv_matches {
          let key = $match.capture0
          let value = $match.capture1
          let col_name = "clusterFault(" + $key + ")_" + ($counter | into string)
          
          # Type conversion
          let parsed_value = if ($value == "true") {
            true
          } else if ($value == "false") {
            false
          } else if ($value =~ '^\d+$') {
            ($value | into int)
          } else {
            $value
          }
          
          $output = ($output | insert $col_name $parsed_value)
          $counter = $counter + 1
        }
      }
    }
    
    $output
  }
}