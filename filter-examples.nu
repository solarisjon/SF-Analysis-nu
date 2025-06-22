#!/usr/bin/env nu

# Convenience script for common filtering operations with sf-filter

print "🔍 SolidFire Log Filter - Common Usage Examples"
print "=" * 50

print "\n📋 Available commands:"
print "1. Time range filtering:"
print "   ./sf-filter-rust/target/release/sf-filter data/output.json --start-time '08:30' --end-time '09:00'"

print "\n2. Date range filtering:"
print "   ./sf-filter-rust/target/release/sf-filter data/output.json --start-date '2025-06-12' --end-date '2025-06-12'"

print "\n3. Combined date and time:"
print "   ./sf-filter-rust/target/release/sf-filter data/output.json --start-date '2025-06-12' --start-time '08:30' --end-time '09:00'"

print "\n4. Field filtering (specific snapshotID):"
print "   ./sf-filter-rust/target/release/sf-filter data/output.json --field 'snapshotID=13846639'"

print "\n5. Multiple filters:"
print "   ./sf-filter-rust/target/release/sf-filter data/output.json --start-time '08:00' --field 'component=Snaps' --field 'serviceID=230'"

print "\n6. Custom output name:"
print "   ./sf-filter-rust/target/release/sf-filter data/output.json --start-time '04:30' --end-time '5:30' -o data/morning-logs.json"

print "\n💡 After filtering, your nushell queries will be much faster:"
print "   nu -c 'open data/output-filtered.json | where snapshotID == 13846639 | length'"
print "   nu -c 'open data/output-filtered.json | where ($it.snapshotID | is-not-empty) | length'"

print "\n🚀 Performance benefits:"
print "   • Original file: ~783K records (slow queries)"
print "   • Filtered file: ~few thousand records (fast queries)"
print "   • 10-100x faster nushell operations on filtered data"

def main [action?: string] {
    match $action {
        "snapshots" => {
            print "\n🔍 Filtering for snapshot-related logs..."
            ./sf-filter-rust/target/release/sf-filter data/output.json --field "component=Snaps" -o data/snapshots-only.json
            print "✅ Created data/snapshots-only.json with snapshot logs only"
        }
        "morning" => {
            print "\n🌅 Filtering for morning logs (04:30-05:30)..."
            ./sf-filter-rust/target/release/sf-filter data/output.json --start-time "04:30" --end-time "05:30" -o data/morning-logs.json
            print "✅ Created data/morning-logs.json with morning time range"
        }
        "today" => {
            let today = (date now | format date "%Y-%m-%d")
            print $"\n📅 Filtering for today's logs (($today))..."
            ./sf-filter-rust/target/release/sf-filter data/output.json --start-date $today --end-date $today -o data/today-logs.json
            print $"✅ Created data/today-logs.json with ($today) logs only"
        }
        _ => {
            print "\n📖 Usage: nu filter-examples.nu [action]"
            print "   snapshots - Filter snapshot-related logs"
            print "   morning   - Filter morning time range (04:30-05:30)"
            print "   today     - Filter today's logs"
        }
    }
}