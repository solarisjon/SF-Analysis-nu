def parse-solidfire-logs [file_path: string] {
  open $file_path
  | lines
  | each { |line|
      let parts = ($line | parse --regex '([^:]+):\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s+(\S+)\s+([^:]+):\s*(\[APP-\d+\])\s*(\[\w+\])\s*(\d+)\s+(\S+)\s+(\S+):(\d+):(\S+)\s*(.*)')
      if ($parts | length) > 0 {
        let parsed = $parts.0
        let message = $parsed.capture11

        # Basic record structure
        mut record = {
          host: $parsed.capture0,
          timestamp: ($parsed.capture1 | into datetime),
          node: $parsed.capture2,
          service: $parsed.capture3,
          app: $parsed.capture4,
          service_type: $parsed.capture5,
          id: ($parsed.capture6 | into int),
          process: $parsed.capture7,
          source_code: $parsed.capture8,
          line_number: ($parsed.capture9 | into int),
          what: $parsed.capture10,
          raw_message: $message
        }

        # Determine log type
        let log_type = if ($message | str contains "ProcessNewFaults") {
          "fault_detected"
        } else if ($message | str contains "ResolveFault") {
          if ($message | str contains "Resolving") { "fault_resolving" } else { "fault_resolved" }
        } else if ($message | str contains "CheckBlockServicesUnhealthy") {
          "health_check"
        } else {
          "other"
        }

        $record = ($record | insert "log_type" $log_type)

        # Extract fault information if present
        if ($message | str contains "clusterFault=") {
          let fault_match = ($message | parse --regex 'clusterFault=\{([^}]+)\}')
          if ($fault_match | length) > 0 {
            let fault_details = $fault_match.0.capture0
            let fault_pairs = ($fault_details | split row "," | each { |pair|
              let key_value = ($pair | parse --regex '(\w+)=([^,}\s]+|\{[^}]+\}|\[[^\]]+\])')
              if ($key_value | length) > 0 {
                let key = $key_value.0.capture0
                let value = $key_value.0.capture1
                let parsed_value = if ($value == "true" or $value == "false") {
                  ($value | into bool)
                } else if ($value =~ '^\d+$') {
                  ($value | into int)
                } else if ($value | str contains "{") {
                  # Handle nested structures
                  ($value | parse --regex '(\w+)=([^,}\s]+)' | each { |nested_pair|
                    let nested_key = $nested_pair.capture0
                    let nested_value = $nested_pair.capture1
                    { key: nested_key, value: nested_value }
                  })
                } else if ($value | str contains "[") {
                  # Handle arrays
                  ($value | parse --regex '\[([^\]]+)\]' | each { |array_match|
                    $array_match.capture0 | split row "," | each { |item| $item | str trim }
                  })
                } else {
                  $value
                }
                { key: $key, value: $parsed_value }
              }
            })
            $record = ($fault_pairs | reduce --fold $record { |fault_pair, acc|
              try {
                $acc | update $fault_pair.key (
                  if (($acc | get $fault_pair.key | type | str contains "list")) {
                    ($acc | get $fault_pair.key | append $fault_pair.value)
                  } else {
                    [($acc | get $fault_pair.key), $fault_pair.value]
                  }
                )
              } catch {
                $acc | insert $fault_pair.key $fault_pair.value
              }
            })
          }
        }

        # Extract structured arrays
        if ($message | str contains "nodesWithFailedServices=") {
          let nodes = ($message | parse --regex 'nodesWithFailedServices=\{([^}]+)\}')
          if ($nodes | length) > 0 {
            $record = ($record | insert "nodesWithFailedServices" ($nodes.0.capture0 | split row "," | each { |x| $x | str trim | into int }))
          }
        }

        if ($message | str contains "driveIDs=") {
          let drives = ($message | parse --regex 'driveIDs=\{([^}]+)\}')
          if ($drives | length) > 0 {
            $record = ($record | insert "driveIDs" ($drives.0.capture0 | split row "," | each { |x| $x | str trim | into int }))
          }
        }

        # Extract killServices with better parsing
        if ($message | str contains "killServices=") {
          let kill_services_raw = ($message | parse --regex 'killServices=\{(.+?)\}(?=\s+\w+=|$)')
          if ($kill_services_raw | length) > 0 {
            let kill_data = $kill_services_raw.0.capture0
            # Extract service IDs that are being killed
            let service_ids = ($kill_data | parse --regex '\((\d+),' | each { |match| $match.capture0 | into int })
            $record = ($record | insert "killServiceIDs" $service_ids)
            $record = ($record | insert "killServicesRaw" $kill_data)
          }
        }

        # Extract ServiceInfo details
        if ($message | str contains "ServiceInfo") {
          # Count ServiceInfo occurrences (approximate)
          let service_info_matches = ($message | str replace --all "ServiceInfo" "X")
          let original_length = ($message | str length)
          let replaced_length = ($service_info_matches | str length)
          $record = ($record | insert "serviceInfoCount" (($original_length - $replaced_length) / -10))

          # Extract unique node IDs from ServiceInfo using simpler approach
          let node_id_matches = ($message | parse --regex 'nodeID=(\d+)' | get capture0)
          if ($node_id_matches | length) > 0 {
            let node_ids = ($node_id_matches | each { |x| $x | into int } | uniq)
            $record = ($record | insert "serviceInfoNodeIDs" $node_ids)
          }

          # Extract service IDs from ServiceInfo
          let service_id_matches = ($message | parse --regex 'ServiceInfo\\([^,]*ID=(\d+)\\)' | get capture0)
          if ($service_id_matches | length) > 0 {
            let service_ids = ($service_id_matches | each { |x| $x | into int })
            $record = ($record | insert "serviceInfoIDs" $service_ids)
          }

          # Extract service statuses
          let status_matches = ($message | parse --regex 'status=(\w+)' | get capture0 | uniq)
          if ($status_matches | length) > 0 {
            $record = ($record | insert "serviceStatuses" $status_matches)
          }
        }

        # Extract platform information if present
        if ($message | str contains "platform=") {
          let platform_match = ($message | parse --regex 'platform=\{([^}]+)\}')
          if ($platform_match | length) > 0 {
            let platform_data = $platform_match.0.capture0
            # Extract chassis type
            let chassis_type = ($platform_data | parse --regex '"chassisType":"([^"]+)"')
            if ($chassis_type | length) > 0 {
              $record = ($record | insert "chassisType" $chassis_type.0.capture0)
            }
            # Extract node type
            let node_type = ($platform_data | parse --regex '"nodeType":"([^"]+)"')
            if ($node_type | length) > 0 {
              $record = ($record | insert "nodeType" $node_type.0.capture0)
            }
          }
        }

        # Extract detailed fault information
        if ($message | str contains "details=") {
          let details_match = ($message | parse --regex 'details=\[([^\]]+)\]')
          if ($details_match | length) > 0 {
            $record = ($record | insert "faultDetails" $details_match.0.capture0)
          }
        }

        $record
      }
    }
  | where $it != null
}

# Helper function to analyze service health issues
def analyze-service-health [] {
  group-by log_type
  | transpose log_type entries
  | each { |group|
      let entries = $group.entries
      {
        log_type: $group.log_type,
        count: ($entries | length),
        unique_nodes: ($entries | get nodesWithFailedServices? | flatten | uniq | length),
        time_range: {
          first: ($entries | get timestamp | min),
          last: ($entries | get timestamp | max)
        }
      }
    }
}

# Helper function to get service kill summary
def get-kill-services-summary [] {
  where killServiceIDs != null
  | each { |row|
      {
        timestamp: $row.timestamp,
        node: $row.node,
        failed_nodes: $row.nodesWithFailedServices,
        services_to_kill: $row.killServiceIDs,
        service_count: ($row.serviceInfoCount? | default 0)
      }
    }
  | sort-by timestamp
}

# Usage examples:
# parse-solidfire-logs "logfile.txt" | where log_type == "health_check" | get-kill-services-summary
# parse-solidfire-logs "logfile.txt" | analyze-service-health
