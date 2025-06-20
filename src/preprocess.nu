#!/usr/bin/env nu

# Fast preprocessing of SolidFire logs using ripgrep
def preprocess-sf-logs [input_file: string, output_file: string] {
  print $"Preprocessing ($input_file) to ($output_file)..."
  
  # Use ripgrep to extract structured data and convert to CSV
  rg --line-number --no-heading '(\w+)=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}\}' $input_file
  | lines
  | each { |line|
      let parts = ($line | split column ":" line_num content)
      let line_num = ($parts.line_num.0 | into int)
      let content = $parts.content.0
      
      # Extract timestamp from beginning of line if present
      let timestamp = if ($content =~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') {
        ($content | parse --regex '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^\s]*)').capture0.0? | default ""
      } else { "" }
      
      {
        line_number: $line_num,
        timestamp: $timestamp,
        raw_content: $content
      }
    }
  | to json
  | save $output_file
  
  print "Preprocessing complete!"
}