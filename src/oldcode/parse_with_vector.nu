def parse-sf-logs-vector [file_path: string] {
  # Check if vector is installed
  if (which vector | is-empty) {
    error make {msg: "Vector not found. Install with: curl --proto '=https' --tlsv1.2 -sSf https://sh.vector.dev | bash"}
  }
  
  # Check if config file exists
  if not ($"(pwd)/vector.toml" | path exists) {
    error make {msg: "vector.toml configuration file not found in current directory"}
  }
  
  # Update the config file to use the provided file path
  let config_content = (open vector.toml | str replace 'include = ["./simplelog"]' $'include = ["($file_path)"]')
  $config_content | save vector_temp.toml
  
  # Run vector and parse JSON output
  let result = (
    vector --config vector_temp.toml 
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
  )
  
  # Clean up temp file
  rm -f vector_temp.toml
  
  $result
}

# Alternative function that uses vector as a one-shot processor
def parse-sf-logs-vector-oneshot [file_path: string] {
  # Create a simple vector config on the fly
  let temp_config = $"
[sources.logs]
type = \"file\"
include = [\"($file_path)\"]
read_from = \"beginning\"

[transforms.parse]
type = \"remap\"
inputs = [\"logs\"]
source = '''
# Basic parsing with regex
.parsed = parse_regex!(.message, r'^(?P<host>[^:]+):(?P<timestamp>\\S+)\\s+(?P<node>\\S+)\\s+(?P<service>[^:]+):\\s+(?P<rest>.*)$')

# Extract clusterFault if present
if match(.parsed.rest, r'clusterFault=') {
  .cluster_fault_raw = parse_regex(.parsed.rest, r'clusterFault=\\{\\{(?P<content>[^}]*(?:\\{[^}]*\\}[^}]*)*)\\}')
  if exists(.cluster_fault_raw.content) {
    .cluster_fault_content = .cluster_fault_raw.content
  }
}

# Keep everything for now
. = merge(., .parsed)
'''

[sinks.stdout]
type = \"console\"
inputs = [\"parse\"]
encoding.codec = \"json\"
"
  
  # Save temp config and run
  $temp_config | save vector_simple.toml
  
  let result = (
    vector --config vector_simple.toml --quiet
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
  )
  
  # Clean up
  rm -f vector_simple.toml
  
  $result
}

# Installation helper
def install-vector [] {
  print "Installing Vector..."
  if ($nu.os-info.name == "macos") {
    if (which brew | is-empty) {
      print "Installing via curl..."
      bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.vector.dev | bash"
    } else {
      print "Installing via Homebrew..."
      brew install vector
    }
  } else if ($nu.os-info.name == "linux") {
    bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.vector.dev | bash"
  } else {
    error make {msg: "Unsupported OS. Please install Vector manually from https://vector.dev/docs/setup/installation/"}
  }
}