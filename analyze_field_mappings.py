#!/usr/bin/env python3

import json
from collections import defaultdict, Counter
import sys

def analyze_field_mappings():
    """Analyze SolidFire log data for field-to-component mappings."""
    
    data_file = "data/sf-smallmaster.parsed.json"
    
    print("🔍 Analyzing SolidFire log data for field-to-component mappings...")
    print(f"📁 Reading data from: {data_file}")
    
    try:
        with open(data_file, 'r') as f:
            parsed_data = json.load(f)
    except FileNotFoundError:
        print(f"❌ Error: File {data_file} not found!")
        return
    except json.JSONDecodeError as e:
        print(f"❌ Error parsing JSON: {e}")
        return
    
    print(f"📊 Total log entries: {len(parsed_data)}")
    
    # Get all unique components
    components = sorted(set(record.get('component') for record in parsed_data if record.get('component')))
    print(f"🏷️  Unique components found: {components}")
    
    # Standard log fields to exclude from analysis
    standard_fields = {
        "line_num", "date", "time", "timestamp", "hostname", "process", "pid", 
        "level", "component", "thread", "class", "source", "content", "raw_line", "parse_error"
    }
    
    print("\n" + "=" * 60)
    print("📋 COMPONENT-FIELD MAPPING ANALYSIS")
    print("=" * 60)
    
    # Store component analysis for cross-component field analysis
    component_field_usage = defaultdict(dict)
    all_field_components = defaultdict(set)
    
    for component in components:
        print(f"\n🏷️  COMPONENT: {component}")
        
        # Get all records for this component
        component_records = [record for record in parsed_data if record.get('component') == component]
        print(f"📊 Total Records: {len(component_records)}")
        print("-" * 40)
        
        # Find all fields that have non-null values for this component
        field_stats = []
        
        if component_records:
            # Get all field names from all records of this component
            all_fields = set()
            for record in component_records:
                all_fields.update(record.keys())
            
            for field in sorted(all_fields):
                if field not in standard_fields:
                    # Count non-null values for this field
                    non_null_count = sum(1 for record in component_records 
                                       if record.get(field) is not None)
                    
                    if non_null_count > 0:
                        frequency = (non_null_count / len(component_records)) * 100
                        field_stats.append({
                            'field': field,
                            'count': non_null_count,
                            'total_records': len(component_records),
                            'frequency': round(frequency, 1)
                        })
                        
                        # Store for cross-component analysis
                        component_field_usage[component][field] = frequency
                        all_field_components[field].add(component)
        
        # Sort fields by frequency
        field_stats.sort(key=lambda x: x['frequency'], reverse=True)
        
        if field_stats:
            print("🔸 Fields with data:")
            for field_info in field_stats:
                print(f"   • {field_info['field']}: {field_info['count']}/{field_info['total_records']} records ({field_info['frequency']}%)")
                
                # Show sample values for frequently used fields
                if field_info['frequency'] > 50:
                    sample_values = []
                    for record in component_records:
                        value = record.get(field_info['field'])
                        if value is not None and value not in sample_values:
                            sample_values.append(str(value))
                            if len(sample_values) >= 3:
                                break
                    
                    if sample_values:
                        print(f"     📋 Sample values: {', '.join(sample_values)}")
        else:
            print("   ⚠️  No component-specific fields found (only standard log fields)")
    
    # Cross-component field analysis
    print("\n" + "=" * 60)
    print("🎯 FIELD EXCLUSIVITY ANALYSIS")
    print("=" * 60)
    
    # Find exclusive fields (used by only one component)
    exclusive_fields = {field: list(components)[0] for field, components in all_field_components.items() 
                       if len(components) == 1}
    
    if exclusive_fields:
        print("🔒 Fields exclusive to specific components:")
        for field, component in sorted(exclusive_fields.items()):
            print(f"   • {field} → {component} only")
    else:
        print("   ⚠️  No fields are exclusive to a single component")
    
    # Find common fields (used by multiple components)
    common_fields = {field: list(components) for field, components in all_field_components.items() 
                    if len(components) > 1}
    
    if common_fields:
        print("\n🔄 Fields shared across components:")
        for field, components in sorted(common_fields.items()):
            components_str = ", ".join(sorted(components))
            print(f"   • {field} → used by: {components_str}")
    
    # Generate summary statistics
    print("\n" + "=" * 60)
    print("📊 SUMMARY STATISTICS")
    print("=" * 60)
    
    total_fields = len(all_field_components)
    exclusive_count = len(exclusive_fields)
    shared_count = len(common_fields)
    
    print(f"📈 Total unique fields found: {total_fields}")
    print(f"🔒 Exclusive fields: {exclusive_count} ({round(exclusive_count/total_fields*100, 1)}%)")
    print(f"🔄 Shared fields: {shared_count} ({round(shared_count/total_fields*100, 1)}%)")
    
    # Most commonly used fields across all components
    field_usage_count = Counter()
    for field, components in all_field_components.items():
        field_usage_count[field] = len(components)
    
    print(f"\n🏆 Most widely used fields:")
    for field, component_count in field_usage_count.most_common(5):
        components_list = sorted(all_field_components[field])
        print(f"   • {field}: used by {component_count} components ({', '.join(components_list)})")
    
    print("\n✅ Analysis complete!")

if __name__ == "__main__":
    analyze_field_mappings()