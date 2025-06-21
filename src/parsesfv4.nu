def parse-sf-logs-streaming [file_path: string, chunk_size: int = 1000] {
  print $"Processing ($file_path) in chunks of ($chunk_size) lines..."
  
  # Process file in chunks to avoid memory issues
  let total_lines = (open $file_path | lines | length)
  print $"Total lines: ($total_lines)"
  
  mut processed = 0
  mut all_results = []
  
  # Process in chunks
  while $processed < $total_lines {
    let end_line = ([$processed + $chunk_size, $total_lines] | math min)
    print $"Processing lines ($processed) to ($end_line)..."
    
    let chunk_data = (
      open $file_path 
      | lines 
      | skip $processed 
      | first ($end_line - $processed)
      | each { |line|
          # Simplified parsing for speed - extract key structured data only
          mut record = {line_number: ($processed + $in + 1)}
          
          # Extract timestamp quickly
          if ($line =~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') {
            let ts = ($line | parse --regex '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^\s]*)').capture0.0?
            if $ts != null { $record = ($record | insert timestamp $ts) }
          }
          
          # Extract only clusterFault data (most important)
          let cluster_faults = ($line | parse --regex 'clusterFault=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}\}')
          for fault in $cluster_faults {
            let content = $fault.capture0
            # Quick key extraction
            let keys = ($content | parse --regex '(\w+)=([^}\s,]+)')
            for kv in $keys {
              let col_name = "fault_" + $kv.capture0
              $record = ($record | insert $col_name $kv.capture1)
            }
          }
          
          $record
        }
    )
    
    $all_results = ($all_results | append $chunk_data)
    $processed = $end_line
  }
  
  $all_results
}

# Ultra-fast extractor for specific fields only
def extract-sf-faults [file_path: string] {
  print "Extracting cluster faults only..."
  rg --line-number 'clusterFault=' $file_path
  | lines
  | each { |line|
      let parts = ($line | split column ":" line_num content)
      let line_num = ($parts.line_num.0 | into int)
      let content = $parts.content.0
      
      # Extract timestamp
      let timestamp = if ($content =~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') {
        ($content | parse --regex '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^\s]*)').capture0.0? | default ""
      } else { "" }
      
      {
        line_number: $line_num,
        timestamp: $timestamp,
        raw_fault: $content
      }
    }
}