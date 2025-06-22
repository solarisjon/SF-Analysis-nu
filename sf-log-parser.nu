#!/usr/bin/env nu

# Fixed SolidFire Log Parser with consistent columns
# Ensures all records have the same columns with null for missing values

def main [input_file: string, output_file?: string] {
    let out_file = if ($output_file | is-empty) { 
        ($input_file | path parse | get stem) + "-parsed.json" 
    } else { 
        $output_file 
    }
    
    if not ($input_file | path exists) {
        error make { msg: $"Input file ($input_file) does not exist" }
    }
    
    print $"Parsing ($input_file) to ($out_file)..."
    print "Phase 1: Scanning for all possible columns..."
    
    # First pass: discover all possible columns
    let all_columns = discover_all_columns $input_file
    print $"Found ($all_columns | length) unique columns"
    
    print "Phase 2: Parsing with consistent schema..."
    let start_time = (date now)
    
    open $input_file 
    | lines 
    | enumerate 
    | each { |it|
        if ($it.index mod 10000) == 0 {
            print $"Processed ($it.index) lines..."
        }
        
        try {
            parse_with_schema $it.item ($it.index + 1) $all_columns
        } catch { |e|
            # Create error record with all columns
            create_error_record ($it.index + 1) $e.msg $it.item $all_columns
        }
    }
    | to json
    | save --force $out_file
    
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    let parsed_data = (open $out_file)
    let success_count = ($parsed_data | where parse_error == null | length)
    let error_count = ($parsed_data | where parse_error != null | length)
    
    print $"Successfully parsed ($success_count) lines, ($error_count) errors"
    print $"Output saved to ($out_file)"
    print $"Processing time: ($duration)"
    print $"All records now have consistent columns!"
    print $"Usage: nu -c 'open ($out_file) | where serviceID == 230'"
}

def discover_all_columns [input_file: string] {
    let base_columns = [
        "line_num", "date", "time", "timestamp", "hostname", "process", 
        "pid", "level", "component", "thread", "class", "source", 
        "content", "raw_line", "parse_error"
    ]
    
    # Sample first 1000 lines to discover dynamic columns
    let dynamic_columns = (
        open $input_file 
        | lines 
        | first 1000
        | each { |line|
            try {
                let content = extract_content $line
                parse_dynamic_columns $content
            } catch {
                []
            }
        }
        | flatten
        | uniq
    )
    
    # Combine base and dynamic columns
    $base_columns | append $dynamic_columns | uniq
}

def extract_content [line: string] {
    # Quick extraction of content part for column discovery
    let parts = ($line | split row '| ')
    if ($parts | length) > 1 {
        $parts | get 1
    } else {
        ""
    }
}

def parse_dynamic_columns [content: string] {
    mut columns = []
    
    # Extract key=value pairs
    let words = ($content | split row ' ')
    for word in $words {
        if ($word | str contains '=') and not ($word | str contains '{') {
            let parts = ($word | split row '=' | first 2)
            if ($parts | length) == 2 {
                let key = ($parts | get 0)
                $columns = ($columns | append $key)
            }
        }
    }
    
    $columns
}

def parse_with_schema [line: string, line_num: int, schema: list] {
    # Try parsing with multiple strategies
    let parsed_data = try {
        parse_basic_format_with_schema $line $line_num
    } catch {
        try {
            parse_call_format_with_schema $line $line_num
        } catch {
            parse_minimal_format_with_schema $line $line_num
        }
    }
    
    # Ensure all schema columns exist
    ensure_complete_schema $parsed_data $schema
}

def parse_basic_format_with_schema [line: string, line_num: int] {
    let pattern = '{timestamp} {hostname} {process}[{pid}]: [{level}] [{component}] {thread} {class} {source}| {content}'
    
    let parsed = ($line | parse $pattern)
    
    if ($parsed | is-empty) {
        error make { msg: "Basic format pattern failed" }
    }
    
    let match = ($parsed | get 0)
    let dt = ($match.timestamp | into datetime)
    
    mut result = {
        line_num: $line_num,
        date: ($dt | format date "%Y-%m-%d"),
        time: ($dt | format date "%H:%M:%S.%f"),
        timestamp: $match.timestamp,
        hostname: $match.hostname,
        process: $match.process,
        pid: ($match.pid | into int),
        level: $match.level,
        component: $match.component,
        thread: ($match.thread | into int),
        class: $match.class,
        source: ($match.source | str trim),
        content: $match.content,
        raw_line: $line,
        parse_error: null
    }
    
    # Parse content for key=value pairs
    let parsed_content = parse_simple_content $match.content
    $result | merge $parsed_content
}

def parse_call_format_with_schema [line: string, line_num: int] {
    let pattern = '{timestamp} {hostname} {process}[{pid}]: [{level}] [{component}] {thread} {class} {source}|{method} CALL: {content}'
    
    let parsed = ($line | parse $pattern)
    
    if ($parsed | is-empty) {
        error make { msg: "CALL format pattern failed" }
    }
    
    let match = ($parsed | get 0)
    let dt = ($match.timestamp | into datetime)
    
    {
        line_num: $line_num,
        date: ($dt | format date "%Y-%m-%d"),
        time: ($dt | format date "%H:%M:%S.%f"),
        timestamp: $match.timestamp,
        hostname: $match.hostname,
        process: $match.process,
        pid: ($match.pid | into int),
        level: $match.level,
        component: $match.component,
        thread: ($match.thread | into int),
        class: $match.class,
        source: ($match.source | str trim),
        method: $match.method,
        call_content: $match.content,
        content: $match.content,
        raw_line: $line,
        parse_error: null
    }
}

def parse_minimal_format_with_schema [line: string, line_num: int] {
    let parts = ($line | split row ' ')
    if ($parts | length) < 4 {
        error make { msg: "Not enough parts for minimal parsing" }
    }
    
    let timestamp_str = ($parts | get 0)
    let hostname = ($parts | get 1)
    let process_part = ($parts | get 2)
    
    let process_pid = ($process_part | split row '[')
    let process = ($process_pid | get 0)
    let pid_part = try {
        ($process_pid | get 1 | str replace ']' '' | into int)
    } catch {
        0
    }
    
    let dt = try {
        $timestamp_str | into datetime
    } catch {
        error make { msg: "Failed to parse timestamp in minimal format" }
    }
    
    {
        line_num: $line_num,
        date: ($dt | format date "%Y-%m-%d"),
        time: ($dt | format date "%H:%M:%S.%f"),
        timestamp: $timestamp_str,
        hostname: $hostname,
        process: $process,
        pid: $pid_part,
        level: null,
        component: null,
        thread: null,
        class: null,
        source: null,
        content: ($line | str substring (($timestamp_str | str length) + ($hostname | str length) + ($process_part | str length) + 4)..),
        raw_line: $line,
        parse_error: null,
        parse_method: "minimal"
    }
}

def parse_simple_content [content: string] {
    mut result = {}
    
    let words = ($content | split row ' ')
    for word in $words {
        if ($word | str contains '=') and not ($word | str contains '{') and not ($word | str contains '[') {
            let parts = ($word | split row '=' | first 2)
            if ($parts | length) == 2 {
                let key = ($parts | get 0)
                let value = ($parts | get 1)
                
                let typed_value = try {
                    if ($value | str contains '.') {
                        $value | into float
                    } else {
                        $value | into int
                    }
                } catch {
                    $value
                }
                
                $result = ($result | insert $key $typed_value)
            }
        }
    }
    
    $result
}

def ensure_complete_schema [record: record, schema: list] {
    mut complete_record = $record
    
    for column in $schema {
        if not ($column in ($record | columns)) {
            $complete_record = ($complete_record | insert $column null)
        }
    }
    
    $complete_record
}

def create_error_record [line_num: int, error_msg: string, raw_line: string, schema: list] {
    mut error_record = {
        line_num: $line_num,
        parse_error: $error_msg,
        raw_line: $raw_line,
        date: null,
        time: null,
        timestamp: null,
        hostname: null,
        process: null,
        pid: null,
        level: null,
        component: null,
        thread: null,
        class: null,
        source: null,
        content: null
    }
    
    # Add all other schema columns as null
    for column in $schema {
        if not ($column in ($error_record | columns)) {
            $error_record = ($error_record | insert $column null)
        }
    }
    
    $error_record
}