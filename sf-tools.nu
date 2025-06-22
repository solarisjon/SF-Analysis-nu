#!/usr/bin/env nu

# SolidFire Tools - Nushell integration for fast Rust parser

# Parse SolidFire logs using the high-performance Rust parser
export def "sf parse" [
    input_file: string    # Input log file path
    --output (-o): string # Output JSON file (optional)
] {
    let parser_path = "./sf-parser-rust/target/release/sf-parser"
    
    if not ($parser_path | path exists) {
        error make { msg: "Rust parser not found. Run: cd sf-parser-rust && cargo build --release" }
    }
    
    if not ($input_file | path exists) {
        error make { msg: $"Input file not found: ($input_file)" }
    }
    
    print $"🚀 Parsing ($input_file) with Rust parser..."
    
    if ($output | is-empty) {
        run-external $parser_path $input_file
    } else {
        run-external $parser_path $input_file "--output" $output
    }
}