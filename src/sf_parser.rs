// Fast SolidFire log preprocessor in Rust
// Usage: cargo run --release -- input.log output.jsonl

use std::env;
use std::fs::File;
use std::io::{BufRead, BufReader, BufWriter, Write};
use regex::Regex;
use serde_json::json;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: {} input.log output.jsonl", args[0]);
        std::process::exit(1);
    }

    let input_file = &args[1];
    let output_file = &args[2];

    let file = File::open(input_file)?;
    let reader = BufReader::new(file);
    let output = File::create(output_file)?;
    let mut writer = BufWriter::new(output);

    // Pre-compile regex patterns for performance
    let structured_re = Regex::new(r"(\w+)=\{\{([^}]*(?:\{[^}]*\}[^}]*)*)\}\}")?;
    let kv_re = Regex::new(r"(\w+)=([^}\s]+|\[[^\]]*\])")?;
    let timestamp_re = Regex::new(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^\s]*)")?;

    let mut line_number = 0;
    for line in reader.lines() {
        line_number += 1;
        let line = line?;
        
        if line.trim().is_empty() {
            continue;
        }

        let mut record = json!({
            "line_number": line_number,
            "raw_line": line
        });

        // Extract timestamp
        if let Some(cap) = timestamp_re.captures(&line) {
            record["timestamp"] = json!(cap.get(1).unwrap().as_str());
        }

        // Extract structured objects
        for cap in structured_re.captures_iter(&line) {
            let obj_name = cap.get(1).unwrap().as_str();
            let obj_content = cap.get(2).unwrap().as_str();
            
            // Parse key-value pairs within the object
            for kv_cap in kv_re.captures_iter(obj_content) {
                let key = kv_cap.get(1).unwrap().as_str();
                let value = kv_cap.get(2).unwrap().as_str();
                let field_name = format!("{}_{}", obj_name, key);
                record[field_name] = json!(value);
            }
        }

        writeln!(writer, "{}", record)?;
        
        // Progress indicator
        if line_number % 10000 == 0 {
            eprintln!("Processed {} lines", line_number);
        }
    }

    writer.flush()?;
    println!("Processed {} lines to {}", line_number, output_file);
    Ok(())
}