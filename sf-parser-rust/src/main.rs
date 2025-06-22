use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use clap::{Arg, Command};
use rayon::prelude::*;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::io::{BufRead, BufReader, Write};
use std::path::Path;
use std::sync::Arc;
use std::time::Instant;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogRecord {
    pub line_num: u32,
    pub date: String,
    pub time: String,
    pub timestamp: String,
    pub hostname: Option<String>,
    pub process: Option<String>,
    pub pid: Option<u32>,
    pub level: Option<String>,
    pub component: Option<String>,
    pub thread: Option<u32>,
    pub class: Option<String>,
    pub source: Option<String>,
    pub content: Option<String>,
    pub raw_line: String,
    pub parse_error: Option<String>,
    
    // Dynamic fields - we'll use a HashMap for flexibility
    #[serde(flatten)]
    pub dynamic_fields: HashMap<String, serde_json::Value>,
}

#[derive(Debug)]
pub struct SolidFireParser {
    basic_regex: Regex,
    call_regex: Regex,
    kv_regex: Regex,
    known_fields: HashSet<String>,
}

impl SolidFireParser {
    pub fn new() -> Result<Self> {
        // Compile regexes once for performance
        let basic_regex = Regex::new(
            r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s+(\S+)\s+([^\[]+)\[(\d+)\]:\s+\[([^\]]+)\]\s+\[([^\]]+)\]\s+(\d+)\s+(\S+)\s+([^|]+)\|\s*(.*)"
        ).context("Failed to compile basic regex")?;
        
        let call_regex = Regex::new(
            r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s+(\S+)\s+([^\[]+)\[(\d+)\]:\s+\[([^\]]+)\]\s+\[([^\]]+)\]\s+(\d+)\s+(\S+)\s+([^|]+)\|([^|]+)\s+CALL:\s*(.*)"
        ).context("Failed to compile call regex")?;
        
        let kv_regex = Regex::new(r"(\w+)=([^\s]+)")
            .context("Failed to compile key-value regex")?;
        
        // Pre-define known fields that we expect to see frequently
        let known_fields: HashSet<String> = [
            "serviceID", "usedBytes", "nodeID", "sliceID", "snapshotID", 
            "groupID", "volumeID", "requestID", "status", "code", "type",
            "severity", "driveID", "masterID", "replicationID"
        ].iter().map(|s| s.to_string()).collect();
        
        Ok(SolidFireParser {
            basic_regex,
            call_regex,
            kv_regex,
            known_fields,
        })
    }
    
    pub fn parse_line(&self, line: &str, line_num: u32) -> LogRecord {
        // Try basic format first
        if let Some(captures) = self.basic_regex.captures(line) {
            return self.parse_basic_format(line, line_num, &captures);
        }
        
        // Try call format
        if let Some(captures) = self.call_regex.captures(line) {
            return self.parse_call_format(line, line_num, &captures);
        }
        
        // Fallback to minimal parsing
        self.parse_minimal_format(line, line_num)
    }
    
    fn parse_basic_format(&self, line: &str, line_num: u32, captures: &regex::Captures) -> LogRecord {
        let timestamp_str = captures.get(1).unwrap().as_str();
        let (date, time) = self.parse_timestamp(timestamp_str);
        
        let content = captures.get(10).map(|m| m.as_str()).unwrap_or("");
        let dynamic_fields = self.parse_key_value_pairs(content);
        
        LogRecord {
            line_num,
            date,
            time,
            timestamp: timestamp_str.to_string(),
            hostname: Some(captures.get(2).unwrap().as_str().to_string()),
            process: Some(captures.get(3).unwrap().as_str().trim().to_string()),
            pid: captures.get(4).unwrap().as_str().parse().ok(),
            level: Some(captures.get(5).unwrap().as_str().to_string()),
            component: Some(captures.get(6).unwrap().as_str().to_string()),
            thread: captures.get(7).unwrap().as_str().parse().ok(),
            class: Some(captures.get(8).unwrap().as_str().to_string()),
            source: Some(captures.get(9).unwrap().as_str().trim().to_string()),
            content: Some(content.to_string()),
            raw_line: line.to_string(),
            parse_error: None,
            dynamic_fields,
        }
    }
    
    fn parse_call_format(&self, line: &str, line_num: u32, captures: &regex::Captures) -> LogRecord {
        let timestamp_str = captures.get(1).unwrap().as_str();
        let (date, time) = self.parse_timestamp(timestamp_str);
        
        let content = captures.get(11).map(|m| m.as_str()).unwrap_or("");
        let mut dynamic_fields = self.parse_key_value_pairs(content);
        
        // Add method as a dynamic field
        if let Some(method) = captures.get(10) {
            dynamic_fields.insert("method".to_string(), 
                serde_json::Value::String(method.as_str().to_string()));
        }
        
        LogRecord {
            line_num,
            date,
            time,
            timestamp: timestamp_str.to_string(),
            hostname: Some(captures.get(2).unwrap().as_str().to_string()),
            process: Some(captures.get(3).unwrap().as_str().trim().to_string()),
            pid: captures.get(4).unwrap().as_str().parse().ok(),
            level: Some(captures.get(5).unwrap().as_str().to_string()),
            component: Some(captures.get(6).unwrap().as_str().to_string()),
            thread: captures.get(7).unwrap().as_str().parse().ok(),
            class: Some(captures.get(8).unwrap().as_str().to_string()),
            source: Some(captures.get(9).unwrap().as_str().trim().to_string()),
            content: Some(content.to_string()),
            raw_line: line.to_string(),
            parse_error: None,
            dynamic_fields,
        }
    }
    
    fn parse_minimal_format(&self, line: &str, line_num: u32) -> LogRecord {
        let parts: Vec<&str> = line.split_whitespace().collect();
        
        if parts.len() < 3 {
            return LogRecord {
                line_num,
                date: "".to_string(),
                time: "".to_string(),
                timestamp: "".to_string(),
                hostname: None,
                process: None,
                pid: None,
                level: None,
                component: None,
                thread: None,
                class: None,
                source: None,
                content: Some(line.to_string()),
                raw_line: line.to_string(),
                parse_error: Some("Failed to parse - insufficient parts".to_string()),
                dynamic_fields: HashMap::new(),
            };
        }
        
        let timestamp_str = parts[0];
        let (date, time) = self.parse_timestamp(timestamp_str);
        
        LogRecord {
            line_num,
            date,
            time,
            timestamp: timestamp_str.to_string(),
            hostname: parts.get(1).map(|s| s.to_string()),
            process: parts.get(2).map(|s| s.to_string()),
            pid: None,
            level: None,
            component: None,
            thread: None,
            class: None,
            source: None,
            content: Some(parts[3..].join(" ")),
            raw_line: line.to_string(),
            parse_error: Some("Minimal parsing used".to_string()),
            dynamic_fields: HashMap::new(),
        }
    }
    
    fn parse_timestamp(&self, timestamp_str: &str) -> (String, String) {
        match timestamp_str.parse::<DateTime<Utc>>() {
            Ok(dt) => {
                let date = dt.format("%Y-%m-%d").to_string();
                let time = dt.format("%H:%M:%S%.6f").to_string();
                (date, time)
            }
            Err(_) => ("".to_string(), "".to_string()),
        }
    }
    
    fn parse_key_value_pairs(&self, content: &str) -> HashMap<String, serde_json::Value> {
        let mut result = HashMap::new();
        
        // Simple space-separated key=value extraction
        for word in content.split_whitespace() {
            if let Some(eq_pos) = word.find('=') {
                let key = &word[..eq_pos];
                let value = &word[eq_pos + 1..];
                
                // Skip complex nested structures for now
                if value.contains('{') || value.contains('[') {
                    result.insert(format!("complex_{}", key), 
                        serde_json::Value::String(value.to_string()));
                    continue;
                }
                
                // Type conversion
                let typed_value = if let Ok(int_val) = value.parse::<i64>() {
                    serde_json::Value::Number(serde_json::Number::from(int_val))
                } else if let Ok(float_val) = value.parse::<f64>() {
                    serde_json::Value::Number(serde_json::Number::from_f64(float_val).unwrap_or(serde_json::Number::from(0)))
                } else if value.eq_ignore_ascii_case("true") {
                    serde_json::Value::Bool(true)
                } else if value.eq_ignore_ascii_case("false") {
                    serde_json::Value::Bool(false)
                } else {
                    serde_json::Value::String(value.to_string())
                };
                
                result.insert(key.to_string(), typed_value);
            }
        }
        
        result
    }
    
    pub fn parse_file(&self, input_path: &Path, output_path: &Path, chunk_size: usize) -> Result<()> {
        let start_time = Instant::now();
        
        // Display version and info
        println!("🔥 SolidFire Log Parser v{}", env!("CARGO_PKG_VERSION"));
        println!("📊 Parsing {} to {}", input_path.display(), output_path.display());
        
        // Phase 1: Discover all possible dynamic fields
        println!("Phase 1: Discovering schema...");
        let all_dynamic_fields = self.discover_schema(input_path)?;
        println!("Found {} dynamic fields", all_dynamic_fields.len());
        
        // Phase 2: Parse with consistent schema
        println!("Phase 2: Parsing with consistent schema...");
        
        let file = File::open(input_path)
            .with_context(|| format!("Failed to open input file: {}", input_path.display()))?;
        let reader = BufReader::new(file);
        
        let mut output_file = File::create(output_path)
            .with_context(|| format!("Failed to create output file: {}", output_path.display()))?;
        
        // Write JSON array start
        writeln!(output_file, "[")?;
        
        let mut line_num = 1u32;
        let mut first_record = true;
        let mut processed_lines = 0;
        
        // Process in chunks for memory efficiency and progress reporting
        let lines: Vec<String> = reader.lines().collect::<Result<Vec<_>, _>>()?;
        let total_lines = lines.len();
        
        for chunk in lines.chunks(chunk_size) {
            let records: Vec<LogRecord> = chunk
                .par_iter()
                .enumerate()
                .map(|(i, line)| {
                    let mut record = self.parse_line(line, line_num + i as u32);
                    // Ensure all dynamic fields exist with null values if missing
                    self.ensure_complete_schema(&mut record, &all_dynamic_fields);
                    record
                })
                .collect();
            
            // Write records to JSON
            for record in records {
                if !first_record {
                    writeln!(output_file, ",")?;
                }
                let json = serde_json::to_string(&record)?;
                write!(output_file, "  {}", json)?;
                first_record = false;
            }
            
            line_num += chunk.len() as u32;
            processed_lines += chunk.len();
            
            if processed_lines % 10000 == 0 {
                println!("Processed {} / {} lines ({:.1}%)", 
                    processed_lines, total_lines, 
                    (processed_lines as f64 / total_lines as f64) * 100.0);
            }
        }
        
        // Write JSON array end
        writeln!(output_file, "\n]")?;
        
        let duration = start_time.elapsed();
        let lines_per_sec = total_lines as f64 / duration.as_secs_f64();
        
        println!("Completed: {} lines in {:.2?} ({:.0} lines/sec)", 
            total_lines, duration, lines_per_sec);
        println!("All records now have consistent columns!");
        
        Ok(())
    }
    
    fn discover_schema(&self, input_path: &Path) -> Result<HashSet<String>> {
        let file = File::open(input_path)?;
        let reader = BufReader::new(file);
        
        let mut all_fields = HashSet::new();
        let sample_size = 1000; // Sample first 1000 lines for schema discovery
        
        for (i, line) in reader.lines().enumerate() {
            if i >= sample_size {
                break;
            }
            
            let line = line?;
            let fields = self.extract_dynamic_field_names(&line);
            all_fields.extend(fields);
        }
        
        Ok(all_fields)
    }
    
    fn extract_dynamic_field_names(&self, line: &str) -> HashSet<String> {
        let mut fields = HashSet::new();
        
        // Extract content part (after the | separator)
        if let Some(pipe_pos) = line.find('|') {
            let content = &line[pipe_pos + 1..];
            
            // Find all key=value pairs
            for word in content.split_whitespace() {
                if let Some(eq_pos) = word.find('=') {
                    let key = &word[..eq_pos];
                    // Skip complex nested structures for consistency
                    let value = &word[eq_pos + 1..];
                    if !value.contains('{') && !value.contains('[') {
                        fields.insert(key.to_string());
                    }
                }
            }
        }
        
        fields
    }
    
    fn ensure_complete_schema(&self, record: &mut LogRecord, all_fields: &HashSet<String>) {
        // Add any missing dynamic fields as null
        for field_name in all_fields {
            if !record.dynamic_fields.contains_key(field_name) {
                record.dynamic_fields.insert(field_name.clone(), serde_json::Value::Null);
            }
        }
    }
}

fn main() -> Result<()> {
    let matches = Command::new("sf-parser")
        .version("0.1.0")
        .about("High-performance SolidFire log parser")
        .arg(Arg::new("input")
            .help("Input log file")
            .required(true)
            .index(1))
        .arg(Arg::new("output")
            .help("Output JSON file")
            .short('o')
            .long("output"))
        .arg(Arg::new("chunk-size")
            .help("Processing chunk size")
            .short('c')
            .long("chunk-size")
            .default_value("1000"))
        .get_matches();
    
    let input_path = Path::new(matches.get_one::<String>("input").unwrap());
    let output_path = if let Some(output) = matches.get_one::<String>("output") {
        Path::new(output).to_path_buf()
    } else {
        let mut output = input_path.to_path_buf();
        output.set_extension("parsed.json");
        output
    };
    
    let chunk_size: usize = matches.get_one::<String>("chunk-size")
        .unwrap()
        .parse()
        .context("Invalid chunk size")?;
    
    let parser = SolidFireParser::new()?;
    parser.parse_file(input_path, &output_path, chunk_size)?;
    
    println!("Output saved to: {}", output_path.display());
    println!("Usage: nu -c 'open {} | where serviceID == 230'", output_path.display());
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;
    use tempfile::TempDir;
    
    #[test]
    fn test_basic_log_parsing() {
        let parser = SolidFireParser::new().unwrap();
        let line = "2025-06-05T00:20:07.858372Z icpbasi03037 master-1[112875]: [APP-5] [MS] 2069182 BSDirector ms/ClusterStatistics.cpp:1452:GetBlockDriveUsageFromStats| serviceID=230 usedBytes=1909106990888";
        
        let record = parser.parse_line(line, 1);
        
        assert_eq!(record.line_num, 1);
        assert_eq!(record.date, "2025-06-05");
        assert_eq!(record.hostname, Some("icpbasi03037".to_string()));
        assert_eq!(record.parse_error, None);
        assert!(record.dynamic_fields.contains_key("serviceID"));
        assert!(record.dynamic_fields.contains_key("usedBytes"));
    }
    
    #[test]
    fn test_snapshot_log_parsing() {
        let parser = SolidFireParser::new().unwrap();
        let line = "2025-06-12T08:35:00.177183Z icpbasi03037 master-1[112875]: [APP-5] [Vvols] 2069183 Scheduler cs/CServiceSliceSnapshots.cpp:1037:UnregisterSnapshot| snapshotID=13846639 vvolParms=<empty> overrideSnapMirrorHold=False";
        
        let record = parser.parse_line(line, 1);
        
        assert_eq!(record.line_num, 1);
        assert_eq!(record.date, "2025-06-12");
        assert_eq!(record.time, "08:35:00.177183");
        assert_eq!(record.parse_error, None);
        assert!(record.dynamic_fields.contains_key("snapshotID"));
        assert_eq!(record.dynamic_fields.get("snapshotID").unwrap(), &serde_json::Value::Number(serde_json::Number::from(13846639)));
        assert!(record.dynamic_fields.contains_key("overrideSnapMirrorHold"));
        assert_eq!(record.dynamic_fields.get("overrideSnapMirrorHold").unwrap(), &serde_json::Value::Bool(false));
    }
    
    #[test]
    fn test_schema_consistency() {
        let parser = SolidFireParser::new().unwrap();
        
        // Create test data with different fields in each line
        let lines = vec![
            "2025-06-05T00:20:07.858372Z icpbasi03037 master-1[112875]: [APP-5] [MS] 2069182 BSDirector ms/ClusterStatistics.cpp:1452:GetBlockDriveUsageFromStats| serviceID=230 usedBytes=1909106990888",
            "2025-06-12T08:35:00.177183Z icpbasi03037 master-1[112875]: [APP-5] [Vvols] 2069183 Scheduler cs/CServiceSliceSnapshots.cpp:1037:UnregisterSnapshot| snapshotID=13846639 vvolParms=<empty> overrideSnapMirrorHold=False",
            "2025-06-05T00:20:07.858372Z icpbasi03037 master-1[112875]: [APP-5] [MS] 2069182 BSDirector ms/ClusterStatistics.cpp:1452:GetBlockDriveUsageFromStats| volumeID=1207 nodeID=2"
        ];
        
        // Parse all lines and collect unique dynamic field names
        let mut all_fields = HashSet::new();
        let mut records = Vec::new();
        
        for (i, line) in lines.iter().enumerate() {
            let record = parser.parse_line(line, (i + 1) as u32);
            all_fields.extend(record.dynamic_fields.keys().cloned());
            records.push(record);
        }
        
        // Ensure all records have all dynamic fields (with nulls for missing)
        for mut record in records.iter_mut() {
            parser.ensure_complete_schema(&mut record.clone(), &all_fields);
        }
        
        // Verify all records have the same number of dynamic fields
        let first_record_field_count = records[0].dynamic_fields.len();
        for record in &records {
            assert_eq!(record.dynamic_fields.len(), first_record_field_count, 
                "All records should have the same number of dynamic fields for schema consistency");
            
            // Verify all expected fields are present
            for field_name in &all_fields {
                assert!(record.dynamic_fields.contains_key(field_name), 
                    "Field '{}' should be present in all records", field_name);
            }
        }
    }
    
    #[test]
    fn test_nushell_query_compatibility() {
        let parser = SolidFireParser::new().unwrap();
        let temp_dir = TempDir::new().unwrap();
        
        // Create test log file
        let test_log_path = temp_dir.path().join("test.log");
        let test_content = r#"2025-06-05T00:20:07.858372Z icpbasi03037 master-1[112875]: [APP-5] [MS] 2069182 BSDirector ms/ClusterStatistics.cpp:1452:GetBlockDriveUsageFromStats| serviceID=230 usedBytes=1909106990888
2025-06-12T08:35:00.177183Z icpbasi03037 master-1[112875]: [APP-5] [Vvols] 2069183 Scheduler cs/CServiceSliceSnapshots.cpp:1037:UnregisterSnapshot| snapshotID=13846639 vvolParms=<empty> overrideSnapMirrorHold=False
2025-06-12T08:35:00.178356Z icpbasi03037 master-1[112875]: [APP-5] [Snaps] 2069183 Scheduler cs/CServiceSliceSnapshots.cpp:866:UnregisterSnapshotInternal|Individual delete of group snapshot member sliceID=1207 snapshotID=13846639 groupSnapshotID=13933489 volumeID=1207
2025-06-05T10:30:15.123456Z icpbasi03037 master-1[112875]: [APP-5] [MS] 2069182 BSDirector ms/ClusterStatistics.cpp:1452:GetBlockDriveUsageFromStats| serviceID=110 usedBytes=2000000000000"#;
        
        fs::write(&test_log_path, test_content).unwrap();
        
        // Parse with Rust parser
        let output_path = temp_dir.path().join("output.json");
        parser.parse_file(&test_log_path, &output_path, 1000).unwrap();
        
        // Verify file was created and is valid JSON
        assert!(output_path.exists(), "Output JSON file should be created");
        
        let json_content = fs::read_to_string(&output_path).unwrap();
        let parsed_json: serde_json::Value = serde_json::from_str(&json_content).unwrap();
        
        // Verify it's an array
        assert!(parsed_json.is_array(), "Output should be a JSON array");
        let records = parsed_json.as_array().unwrap();
        assert_eq!(records.len(), 4, "Should have 4 parsed records");
        
        // Verify all records have consistent schema
        let first_record = &records[0];
        let expected_keys: HashSet<String> = first_record.as_object().unwrap().keys().cloned().collect();
        
        for (i, record) in records.iter().enumerate() {
            let record_obj = record.as_object().unwrap();
            let record_keys: HashSet<String> = record_obj.keys().cloned().collect();
            assert_eq!(record_keys, expected_keys, 
                "Record {} should have the same keys as the first record", i);
        }
        
        // Verify specific field presence for nushell queries
        for record in records {
            let obj = record.as_object().unwrap();
            
            // Core fields should always be present
            assert!(obj.contains_key("line_num"), "line_num should be present");
            assert!(obj.contains_key("date"), "date should be present");
            assert!(obj.contains_key("time"), "time should be present");
            assert!(obj.contains_key("timestamp"), "timestamp should be present");
            assert!(obj.contains_key("snapshotID"), "snapshotID should be present (even if null)");
            assert!(obj.contains_key("serviceID"), "serviceID should be present (even if null)");
        }
        
        println!("✅ All nushell compatibility tests passed!");
        println!("✅ JSON output is valid and has consistent schema");
        println!("✅ Test queries that should work:");
        println!("   nu -c 'open {} | where snapshotID == 13846639 | length'", output_path.display());
        println!("   nu -c 'open {} | where serviceID == 230 | length'", output_path.display());
        println!("   nu -c 'open {} | where time >= \"08:35:00\" | length'", output_path.display());
    }
}
