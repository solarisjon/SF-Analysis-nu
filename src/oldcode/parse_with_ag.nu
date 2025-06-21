# Alternative: Use angle-grinder (simpler than Vector)
def parse-sf-logs-ag [file_path: string] {
  # Check if angle-grinder is installed
  if (which agrind | is-empty) {
    print "Installing angle-grinder..."
    if ($nu.os-info.name == "macos") {
      if not (which brew | is-empty) {
        brew install angle-grinder
      } else {
        error make {msg: "Please install Homebrew or angle-grinder manually from https://github.com/rcoh/angle-grinder"}
      }
    } else {
      error make {msg: "Please install angle-grinder from https://github.com/rcoh/angle-grinder"}
    }
  }
  
  # Use angle-grinder to parse and output JSON
  agrind --file $file_path '
    * | parse "^(?P<host>[^:]+):(?P<timestamp>\\S+)\\s+(?P<node>\\S+)\\s+(?P<service>[^:]+):\\s+(?P<rest>.*)" 
    | json
  '
  | from json
}

# Recommendation: Stick with pure Nushell but use better patterns
def parse-sf-logs-optimized [file_path: string] {
  open $file_path
  | lines
  | each { |line|
      mut record = {}
      mut counter = 0
      
      # Basic parsing with single regex
      let basic_parts = ($line | parse --regex '^([^:]+):(\S+)\s+(\S+)\s+([^:]+):\s+(.*)')
      if ($basic_parts | length) > 0 {
        let parts = $basic_parts.0
        $record.col_0 = $parts.capture0  # host
        $record.col_1 = $parts.capture1  # timestamp  
        $record.col_2 = $parts.capture2  # node
        $record.col_3 = $parts.capture3  # service
        let rest = $parts.capture4       # everything else
        
        # Parse clusterFault efficiently
        let fault_matches = ($rest | parse --regex 'clusterFault=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}')
        if ($fault_matches | length) > 0 {
          let fault_content = $fault_matches.0.capture0
          
          # Extract details in one go
          let details_match = ($fault_content | parse --regex 'details=\[([^\]]*)\]')
          if ($details_match | length) > 0 {
            $record = ($record | insert "clusterFault(details)" $details_match.0.capture0)
          }
          
          # Extract all other key=value pairs at once
          let all_kv = ($fault_content 
            | str replace --all --regex 'details=\[[^\]]*\]' ''
            | parse --regex '(\w+)=([^}\s]+|\{[^}]*\})')
          
          for kv in $all_kv {
            let key = "clusterFault(" + $kv.capture0 + ")"
            let value = $kv.capture1
            
            let parsed_value = if ($value =~ '^\d+$') {
              ($value | into int)
            } else if ($value == "true") {
              true  
            } else if ($value == "false") {
              false
            } else {
              $value
            }
            
            $record = ($record | insert $key $parsed_value)
          }
        }
        
        # Add remaining parts as columns
        let clean_rest = ($rest 
          | str replace --all --regex 'clusterFault=\{\{[^}]*(?:\{[^}]*\}[^}]*)*\}' ''
          | split row " "
          | where $it != "" and $it != "}")
          
        mut col_idx = 4
        for part in $clean_rest {
          $record = ($record | insert $"col_($col_idx)" $part)
          $col_idx = $col_idx + 1
        }
      }
      
      $record
    }
}

# Install angle-grinder helper
def install-angle-grinder [] {
  if ($nu.os-info.name == "macos") {
    if not (which brew | is-empty) {
      brew install angle-grinder
    } else {
      print "Install Homebrew first, then run: brew install angle-grinder"
    }
  } else if ($nu.os-info.name == "linux") {
    print "Install via:"
    print "  cargo install angle-grinder"
    print "  or download from: https://github.com/rcoh/angle-grinder/releases"
  } else {
    print "Download from: https://github.com/rcoh/angle-grinder/releases"
  }
}