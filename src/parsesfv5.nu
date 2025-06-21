# Fast SolidFire log analysis using Rust preprocessor
def parse-sf-logs-rust [input_file: string, --preprocess] {
  let output_file = ($input_file | path parse | get stem) + ".jsonl"
  let output_path = ("output/" + $output_file)
  
  if $preprocess {
    print "🦀 Running Rust preprocessor..."
    ^./sf-parser/target/release/sf-parser $input_file $output_path
  }
  
  if ($output_path | path exists) {
    print $"📊 Loading preprocessed data from ($output_path)"
    open $output_path 
    | lines 
    | each { |line| $line | from json }
  } else {
    error make { msg: $"Preprocessed file not found: ($output_path). Run with --preprocess flag first." }
  }
}

# Quick analysis functions for preprocessed data
def analyze-cluster-faults [data] {
  $data 
  | where clusterFault_id != null
  | select clusterFault_id clusterFault_type clusterFault_severity clusterFault_code timestamp
  | sort-by timestamp
}

def analyze-node-health [data] {
  $data
  | where status != null
  | select nodeID status masterID name timestamp
  | sort-by nodeID timestamp
}

def analyze-services [data] {
  $data
  | where type == "slice"
  | select serviceID nodeID status driveIDs timestamp
  | sort-by nodeID serviceID
}