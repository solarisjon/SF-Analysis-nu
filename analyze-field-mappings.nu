#!/usr/bin/env nu

# SolidFire Field-to-Component Analysis Script
# Analyzes parsed JSON data to identify component-specific fields

def main [] {
    let data_file = "data/sf-smallmaster.parsed.json" 
    
    print "Analyzing SolidFire log data for field-to-component mappings..."
    print $"Reading data from: ($data_file)"
    
    # Load the parsed data
    let parsed_data = (open $data_file)
    
    print $"Total log entries: (($parsed_data | length))"
    
    # Get all unique components
    let components = ($parsed_data | get component | uniq | sort)
    print $"Unique components found: ($components)"
    
    # Standard log fields to exclude from analysis
    let standard_fields = ["line_num", "date", "time", "timestamp", "hostname", "process", "pid", "level", "component", "thread", "class", "source", "content", "raw_line", "parse_error"]
    
    print ""
    print "COMPONENT-FIELD MAPPING ANALYSIS"
    print "=================================================="
    
    for component in $components {
        print ""
        print $"COMPONENT: ($component)"
        
        # Get all records for this component
        let component_records = ($parsed_data | where component == $component)
        print $"Total Records: (($component_records | length))"
        print "------------------------------"
        
        # Get all possible field names from the records
        let all_fields = if (($component_records | length) > 0) {
            ($component_records | first | columns)
        } else {
            []
        }
        
        # Find all fields that have non-null values for this component
        mut fields_with_values = []
        
        for field in $all_fields {
            if ($field not-in $standard_fields) {
                # Check if this field has non-null values for this component
                let non_null_count = ($component_records | get $field | where {|x| $x != null} | length)
                if $non_null_count > 0 {
                    $fields_with_values = ($fields_with_values | append {
                        field: $field,
                        count: $non_null_count,
                        total_records: ($component_records | length),
                        frequency: ($non_null_count / ($component_records | length) * 100 | math round)
                    })
                }
            }
        }
        
        # Sort fields by frequency
        let sorted_fields = ($fields_with_values | sort-by frequency -r)
        
        if ($sorted_fields | length) > 0 {
            print "Fields with data:"
            for field_info in $sorted_fields {
                print $"   • ($field_info.field): ($field_info.count)/(($field_info.total_records)) records (($field_info.frequency)%)"
                
                # Show sample values for top fields
                if $field_info.frequency > 50 {  # Show samples for fields used in >50% of records
                    let sample_values = ($component_records | get $field_info.field | where {|x| $x != null} | uniq | first 3)
                    if ($sample_values | length) > 0 {
                        let values_str = ($sample_values | str join ", ")
                        print $"     Sample values: ($values_str)"
                    }
                }
            }
        } else {
            print "   No component-specific fields found (only standard log fields)"
        }
    }
    
    print ""
    print "Analysis complete!"
}