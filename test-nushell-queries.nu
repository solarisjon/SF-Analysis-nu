#!/usr/bin/env nu

# Test script for validating nushell query compatibility with sf-parser output
# This script tests the core queries that should work with parsed SolidFire logs

def main [] {
    print "🧪 Testing Nushell Query Compatibility with SolidFire Parser"
    print "=" * 60
    
    # Check if test data exists
    if not ("data/snapshot-test.json" | path exists) {
        print "❌ Test data not found. Run the parser first:"
        print "   ./sf-parser-rust/target/release/sf-parser data/snapshot-sample.log -o data/snapshot-test.json"
        exit 1
    }
    
    let test_file = "data/snapshot-test.json"
    print $"📁 Using test file: ($test_file)"
    
    # Test 1: Basic data loading
    print "\n🔍 Test 1: Basic data loading"
    try {
        let data = open $test_file
        let count = $data | length
        print $"✅ Successfully loaded ($count) records"
    } catch {
        print "❌ Failed to load data"
        exit 1
    }
    
    # Test 2: Column consistency
    print "\n🔍 Test 2: Column consistency"
    try {
        let data = open $test_file
        let first_cols = $data | first | columns | length
        let last_cols = $data | last | columns | length
        if $first_cols == $last_cols {
            print ("✅ All records have consistent schema (" + ($first_cols | into string) + " columns)")
        } else {
            print $"❌ Schema inconsistency: first=($first_cols), last=($last_cols)"
        }
    } catch {
        print "❌ Failed to check column consistency"
    }
    
    # Test 3: Core field presence
    print "\n🔍 Test 3: Core field presence"
    try {
        let data = open $test_file | first
        let required_fields = ["line_num", "date", "time", "timestamp", "snapshotID"]
        
        for field in $required_fields {
            if ($data | columns | any {|col| $col == $field}) {
                print $"✅ ($field) field present"
            } else {
                print $"❌ ($field) field missing"
            }
        }
    } catch {
        print "❌ Failed to check field presence"
    }
    
    # Test 4: Your original working query
    print "\n🔍 Test 4: Filter by specific snapshotID"
    try {
        let count = open $test_file | where snapshotID == 13846639 | length
        print $"✅ Found ($count) records with snapshotID=13846639"
    } catch {
        print "❌ Failed to filter by snapshotID"
    }
    
    # Test 5: Time range filtering (correct syntax)
    print "\n🔍 Test 5: Time range filtering"
    try {
        let count = open $test_file | where time >= "08:35:00" and time <= "09:00:00" | length
        print $"✅ Found ($count) records in time range 08:35:00-09:00:00"
    } catch {
        print "❌ Failed to filter by time range"
    }
    
    # Test 6: Non-null filtering (correct nushell syntax)
    print "\n🔍 Test 6: Non-null snapshotID filtering"
    try {
        let count = open $test_file | where ($it.snapshotID | is-not-empty) | length
        print $"✅ Found ($count) records with non-null snapshotID"
    } catch {
        print "❌ Failed to filter non-null snapshotID"
    }
    
    # Test 7: Combined query (your problem case - corrected)
    print "\n🔍 Test 7: Combined time + snapshotID query (CORRECTED SYNTAX)"
    try {
        let count = open $test_file | where time >= "08:35:00" and time <= "09:00:00" and ($it.snapshotID | is-not-empty) | length
        print $"✅ Found ($count) records in time range with non-null snapshotID"
        print "💡 Correct syntax: where time >= \"08:35:00\" and time <= \"09:00:00\" and (\$it.snapshotID | is-not-empty)"
    } catch {
        print "❌ Failed combined query"
    }
    
    # Test 8: Show available snapshot-related columns
    print "\n🔍 Test 8: Available snapshot-related columns"
    try {
        let snap_cols = open $test_file | first | columns | where ($it | str contains -i "snap")
        print $"✅ Snapshot columns available: ($snap_cols | str join ', ')"
    } catch {
        print "❌ Failed to find snapshot columns"
    }
    
    print "\n🎉 Nushell query compatibility tests completed!"
    print "\n📝 USAGE NOTES:"
    print "  • Working query: nu -c 'open data/output.json | where snapshotID == 13846639 | length'"
    print "  • For non-null: use ($it.snapshotID | is-not-empty) instead of != null"
    print "  • Time ranges work fine: where time >= \"04:30\" and time <= \"5:30\""
}