#!/usr/bin/env nu

# Parse simplelog using angle-grinder
def parse_simplelog [
    file_path: string = "simplelog"  # Path to the log file
    --format: string = "table"       # Output format: table, json, csv
] {
    let ag_query = '
        * | parse "sf-master.info:(?P<timestamp>.*?)Z (?P<hostname>\\S+) (?P<process>.*?): (?P<content>.*)"
        | fields timestamp, hostname, process, content
    '
    
    match $format {
        "json" => {
            agrind -f $file_path -o json $ag_query | from json
        }
        "csv" => {
            agrind -f $file_path -o logfmt $ag_query | from csv
        }
        _ => {
            agrind -f $file_path $ag_query | lines | skip 1 | each { |line|
                let parts = $line | split column "|" timestamp hostname process content
                {
                    timestamp: ($parts.timestamp | str trim)
                    hostname: ($parts.hostname | str trim) 
                    process: ($parts.process | str trim)
                    content: ($parts.content | str trim)
                }
            }
        }
    }
}

# Enhanced parser with additional filtering options
def parse_simplelog_enhanced [
    file_path: string = "simplelog"    # Path to the log file
    --hostname: string                 # Filter by hostname
    --after: string                    # Filter entries after this timestamp
    --before: string                   # Filter entries before this timestamp
    --contains: string                 # Filter content containing this string
    --format: string = "table"         # Output format: table, json, csv
] {
    mut ag_query = '
        * | parse "sf-master.info:(?P<timestamp>.*?)Z (?P<hostname>\\S+) (?P<process>.*?): (?P<content>.*)"
    '
    
    # Add filters
    if ($hostname | is-not-empty) {
        $ag_query = $ag_query + $' | where hostname == "($hostname)"'
    }
    
    if ($after | is-not-empty) {
        $ag_query = $ag_query + $' | where timestamp > "($after)"'
    }
    
    if ($before | is-not-empty) {
        $ag_query = $ag_query + $' | where timestamp < "($before)"'
    }
    
    if ($contains | is-not-empty) {
        $ag_query = $ag_query + $' | where content ~= "($contains)"'
    }
    
    $ag_query = $ag_query + " | fields timestamp, hostname, process, content"
    
    match $format {
        "json" => {
            agrind -f $file_path -o json $ag_query | from json
        }
        "csv" => {
            agrind -f $file_path -o logfmt $ag_query | from csv  
        }
        _ => {
            agrind -f $file_path $ag_query | lines | skip 1 | each { |line|
                let parts = $line | split column "|" timestamp hostname process content
                {
                    timestamp: ($parts.timestamp | str trim)
                    hostname: ($parts.hostname | str trim)
                    process: ($parts.process | str trim) 
                    content: ($parts.content | str trim)
                }
            }
        }
    }
}

# Extract fault information specifically
def parse_faults [
    file_path: string = "simplelog"    # Path to the log file
] {
    let ag_query = '
        * | parse "sf-master.info:(?P<timestamp>.*?)Z (?P<hostname>\\S+) (?P<process>.*?): (?P<content>.*)"
        | where content ~= "Fault"
        | fields timestamp, hostname, content
    '
    
    agrind -f $file_path $ag_query | lines | skip 1 | each { |line|
        let parts = $line | split column "|" timestamp hostname content
        {
            timestamp: ($parts.timestamp | str trim)
            hostname: ($parts.hostname | str trim)
            content: ($parts.content | str trim)
        }
    }
}