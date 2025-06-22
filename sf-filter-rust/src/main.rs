use anyhow::{Context, Result};
use chrono::{NaiveDate, NaiveTime};
use clap::{Arg, Command};
use rayon::prelude::*;
use serde_json::Value;
use std::fs::File;
use std::io::{BufReader, Write};
use std::path::Path;
use std::time::Instant;

#[derive(Debug)]
pub struct TimeFilter {
    start_date: Option<NaiveDate>,
    end_date: Option<NaiveDate>,
    start_time: Option<NaiveTime>,
    end_time: Option<NaiveTime>,
}

impl TimeFilter {
    pub fn new(
        start_date: Option<&str>,
        end_date: Option<&str>,
        start_time: Option<&str>,
        end_time: Option<&str>,
    ) -> Result<Self> {
        let start_date = if let Some(date_str) = start_date {
            Some(NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
                .with_context(|| format!("Invalid start date format: {}", date_str))?)
        } else {
            None
        };

        let end_date = if let Some(date_str) = end_date {
            Some(NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
                .with_context(|| format!("Invalid end date format: {}", date_str))?)
        } else {
            None
        };

        let start_time = if let Some(time_str) = start_time {
            Some(NaiveTime::parse_from_str(time_str, "%H:%M:%S")
                .or_else(|_| NaiveTime::parse_from_str(time_str, "%H:%M"))
                .with_context(|| format!("Invalid start time format: {}", time_str))?)
        } else {
            None
        };

        let end_time = if let Some(time_str) = end_time {
            Some(NaiveTime::parse_from_str(time_str, "%H:%M:%S")
                .or_else(|_| NaiveTime::parse_from_str(time_str, "%H:%M"))
                .with_context(|| format!("Invalid end time format: {}", time_str))?)
        } else {
            None
        };

        Ok(TimeFilter {
            start_date,
            end_date,
            start_time,
            end_time,
        })
    }

    pub fn matches(&self, record: &Value) -> bool {
        // Extract date and time from the record
        let date_str = record.get("date")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let time_str = record.get("time")
            .and_then(|v| v.as_str())
            .unwrap_or("");

        // Parse date
        let record_date = if !date_str.is_empty() {
            match NaiveDate::parse_from_str(date_str, "%Y-%m-%d") {
                Ok(date) => Some(date),
                Err(_) => return false, // Skip malformed dates
            }
        } else {
            None
        };

        // Parse time (handle various formats)
        let record_time = if !time_str.is_empty() {
            NaiveTime::parse_from_str(time_str, "%H:%M:%S%.f")
                .or_else(|_| NaiveTime::parse_from_str(time_str, "%H:%M:%S"))
                .or_else(|_| NaiveTime::parse_from_str(time_str, "%H:%M"))
                .ok()
        } else {
            None
        };

        // Check date range
        if let (Some(record_date), Some(start_date)) = (record_date, self.start_date) {
            if record_date < start_date {
                return false;
            }
        }
        if let (Some(record_date), Some(end_date)) = (record_date, self.end_date) {
            if record_date > end_date {
                return false;
            }
        }

        // Check time range (only if no date filters, or if date is within range)
        if let (Some(record_time), Some(start_time)) = (record_time, self.start_time) {
            if record_time < start_time {
                return false;
            }
        }
        if let (Some(record_time), Some(end_time)) = (record_time, self.end_time) {
            if record_time > end_time {
                return false;
            }
        }

        true
    }
}

#[derive(Debug)]
pub struct SolidFireFilter {
    time_filter: Option<TimeFilter>,
    field_filters: Vec<(String, String)>, // field_name, field_value
}

impl SolidFireFilter {
    pub fn new(
        start_date: Option<&str>,
        end_date: Option<&str>,
        start_time: Option<&str>,
        end_time: Option<&str>,
        field_filters: Vec<(String, String)>,
    ) -> Result<Self> {
        let time_filter = if start_date.is_some() || end_date.is_some() || start_time.is_some() || end_time.is_some() {
            Some(TimeFilter::new(start_date, end_date, start_time, end_time)?)
        } else {
            None
        };

        Ok(SolidFireFilter {
            time_filter,
            field_filters,
        })
    }

    pub fn filter_record(&self, record: &Value) -> bool {
        // Check time filter
        if let Some(ref time_filter) = self.time_filter {
            if !time_filter.matches(record) {
                return false;
            }
        }

        // Check field filters
        for (field_name, field_value) in &self.field_filters {
            if let Some(record_value) = record.get(field_name) {
                match record_value {
                    Value::String(s) => {
                        if s != field_value {
                            return false;
                        }
                    }
                    Value::Number(n) => {
                        if let Ok(target_num) = field_value.parse::<f64>() {
                            if n.as_f64().unwrap_or(0.0) != target_num {
                                return false;
                            }
                        } else {
                            return false;
                        }
                    }
                    Value::Bool(b) => {
                        if let Ok(target_bool) = field_value.parse::<bool>() {
                            if *b != target_bool {
                                return false;
                            }
                        } else {
                            return false;
                        }
                    }
                    Value::Null => {
                        if field_value != "null" {
                            return false;
                        }
                    }
                    _ => return false, // Skip complex types for now
                }
            } else {
                return false; // Field doesn't exist
            }
        }

        true
    }

    pub fn filter_file(&self, input_path: &Path, output_path: &Path) -> Result<()> {
        let start_time = Instant::now();
        
        println!("🔍 SolidFire Log Filter v{}", env!("CARGO_PKG_VERSION"));
        println!("📊 Filtering {} to {}", input_path.display(), output_path.display());
        
        if let Some(ref time_filter) = self.time_filter {
            println!("📅 Time filters active:");
            if let Some(start_date) = time_filter.start_date {
                println!("   Start date: {}", start_date);
            }
            if let Some(end_date) = time_filter.end_date {
                println!("   End date: {}", end_date);
            }
            if let Some(start_time) = time_filter.start_time {
                println!("   Start time: {}", start_time);
            }
            if let Some(end_time) = time_filter.end_time {
                println!("   End time: {}", end_time);
            }
        }
        
        if !self.field_filters.is_empty() {
            println!("🔧 Field filters active:");
            for (field, value) in &self.field_filters {
                println!("   {} = {}", field, value);
            }
        }

        // Read and parse JSON
        let file = File::open(input_path)
            .with_context(|| format!("Failed to open input file: {}", input_path.display()))?;
        let reader = BufReader::new(file);
        
        let json_data: Value = serde_json::from_reader(reader)
            .with_context(|| "Failed to parse JSON input")?;
        
        let records = json_data.as_array()
            .with_context(|| "Input JSON must be an array of records")?;
        
        println!("📝 Processing {} records...", records.len());
        
        // Filter records in parallel
        let filtered_records: Vec<&Value> = records
            .par_iter()
            .filter(|record| self.filter_record(record))
            .collect();
        
        // Write filtered results
        let mut output_file = File::create(output_path)
            .with_context(|| format!("Failed to create output file: {}", output_path.display()))?;
        
        // Write JSON array
        writeln!(output_file, "[")?;
        for (i, record) in filtered_records.iter().enumerate() {
            if i > 0 {
                writeln!(output_file, ",")?;
            }
            let json = serde_json::to_string(record)?;
            write!(output_file, "  {}", json)?;
        }
        writeln!(output_file, "\n]")?;
        
        let duration = start_time.elapsed();
        let filter_rate = records.len() as f64 / duration.as_secs_f64();
        
        println!("✅ Filtered {} → {} records in {:.2?} ({:.0} records/sec)", 
            records.len(), filtered_records.len(), duration, filter_rate);
        println!("📁 Output saved to: {}", output_path.display());
        
        // Suggest nushell usage
        println!("\n💡 Usage examples:");
        println!("   nu -c 'open {} | where snapshotID != null | length'", output_path.display());
        println!("   nu -c 'open {} | first 10'", output_path.display());
        
        Ok(())
    }
}

fn main() -> Result<()> {
    let matches = Command::new("sf-filter")
        .version(env!("CARGO_PKG_VERSION"))
        .about("Fast time-range and field filter for SolidFire parsed JSON logs")
        .arg(Arg::new("input")
            .help("Input JSON file from sf-parser")
            .required(true)
            .index(1))
        .arg(Arg::new("output")
            .help("Output filtered JSON file")
            .short('o')
            .long("output"))
        .arg(Arg::new("start-date")
            .help("Start date (YYYY-MM-DD)")
            .long("start-date")
            .value_name("DATE"))
        .arg(Arg::new("end-date")
            .help("End date (YYYY-MM-DD)")
            .long("end-date")
            .value_name("DATE"))
        .arg(Arg::new("start-time")
            .help("Start time (HH:MM:SS or HH:MM)")
            .long("start-time")
            .value_name("TIME"))
        .arg(Arg::new("end-time")
            .help("End time (HH:MM:SS or HH:MM)")
            .long("end-time")
            .value_name("TIME"))
        .arg(Arg::new("field")
            .help("Field filter: field=value (can be used multiple times)")
            .long("field")
            .value_name("FIELD=VALUE")
            .action(clap::ArgAction::Append))
        .get_matches();
    
    let input_path = Path::new(matches.get_one::<String>("input").unwrap());
    let output_path = if let Some(output) = matches.get_one::<String>("output") {
        Path::new(output).to_path_buf()
    } else {
        let mut output = input_path.to_path_buf();
        let stem = output.file_stem().unwrap().to_str().unwrap();
        output.set_file_name(format!("{}-filtered.json", stem));
        output
    };
    
    // Parse field filters
    let mut field_filters = Vec::new();
    if let Some(fields) = matches.get_many::<String>("field") {
        for field_spec in fields {
            if let Some((field, value)) = field_spec.split_once('=') {
                field_filters.push((field.to_string(), value.to_string()));
            } else {
                anyhow::bail!("Invalid field filter format. Use: field=value");
            }
        }
    }
    
    let filter = SolidFireFilter::new(
        matches.get_one::<String>("start-date").map(|s| s.as_str()),
        matches.get_one::<String>("end-date").map(|s| s.as_str()),
        matches.get_one::<String>("start-time").map(|s| s.as_str()),
        matches.get_one::<String>("end-time").map(|s| s.as_str()),
        field_filters,
    )?;
    
    filter.filter_file(input_path, &output_path)?;
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    
    #[test]
    fn test_time_filter() {
        let filter = TimeFilter::new(None, None, Some("08:30"), Some("09:00")).unwrap();
        
        let record1 = json!({
            "date": "2025-06-12",
            "time": "08:35:00",
            "content": "test"
        });
        
        let record2 = json!({
            "date": "2025-06-12", 
            "time": "10:00:00",
            "content": "test"
        });
        
        assert!(filter.matches(&record1));
        assert!(!filter.matches(&record2));
    }
    
    #[test]
    fn test_date_filter() {
        let filter = TimeFilter::new(Some("2025-06-12"), Some("2025-06-12"), None, None).unwrap();
        
        let record1 = json!({
            "date": "2025-06-12",
            "time": "08:35:00",
            "content": "test"
        });
        
        let record2 = json!({
            "date": "2025-06-13",
            "time": "08:35:00", 
            "content": "test"
        });
        
        assert!(filter.matches(&record1));
        assert!(!filter.matches(&record2));
    }
}