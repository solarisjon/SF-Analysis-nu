# SolidFire Log Data: Component-Field Mapping Analysis

This document provides a comprehensive analysis of which fields are associated with which SolidFire components, based on parsed log data analysis.

## Overview

**Analysis Date:** June 22, 2025  
**Data Source:** `data/sf-smallmaster.parsed.json`  
**Total Log Entries Analyzed:** 100  
**Components Identified:** 7 (API, Event, Leader, MS, Scheduler, Snaps, Vvols)  
**Unique Fields Found:** 57  
**Field Exclusivity:** 96.5% of fields are exclusive to specific components  

## Component Breakdown

### 1. **API Component** (9 records)
**Purpose:** API request handling and authentication

**Primary Fields (>50% frequency):**
- `activeApiThreads` (55.6%) - Number of active API threads
  - Sample values: 1
- `authMethod` (55.6%) - Authentication method used
  - Sample values: Cluster, Ldap
- `sourceIP` (55.6%) - Source IP address of API request
  - Sample values: 0.0.0.0, 100.86.118.53, 100.86.118.47
- `totalApiThreads` (55.6%) - Total number of API threads
  - Sample values: 16
- `user` (55.6%) - User making the API request
  - Sample values: internal, vasa_admin_i3ci, cn=w577934,ou=service

**Secondary Fields:**
- `complex_JsonMask(result)` (22.2%) - JSON result masking
- `complex_authMethod` (22.2%) - Complex authentication details
- `complex_ip` (22.2%) - Complex IP information
- `complex_logJson[kParamsKey]` (22.2%) - JSON parameter logging
- `complex_user` (22.2%) - Complex user information
- `requestID` (22.2%) - API request identifier
- `accounts,ou` (11.1%) - Account organizational unit

### 2. **Event Component** (6 records)
**Purpose:** System event logging and publishing

**Primary Fields (>50% frequency):**
- `complex_details` (100%) - Event details in complex format
- `complex_event` (100%) - Event information structure
- `complex_message` (100%) - Event message content
- `mNumEventsPublished` (100%) - Number of events published
  - Sample values: 15, 16, 17
- `nodeID` (100%) - Node identifier where event occurred
  - Sample values: 3
- `published` (100%) - Event publication timestamp
- `reported` (100%) - Event reporting timestamp
- `type` (100%) - Event type
  - Sample values: SliceEvent, ApiEvent, SchedulerEvent
- `serviceID` (66.7%) - Service identifier associated with event

### 3. **Leader Component** (2 records)
**Purpose:** Cluster leadership and voting coordination

**Primary Fields (>50% frequency):**
- `complex_nodesWithWorkingEAContainers` (100%) - Nodes with working EA containers
- `sequenceNumber` (100%) - Leadership sequence number
  - Sample values: 10
- `shouldVote` (100%) - Whether node should participate in voting
  - Sample values: 1
- `stateVote` (100%) - Current state vote
  - Sample values: 1

### 4. **MS (Master Service) Component** (50 records)
**Purpose:** Block service statistics and drive usage monitoring

**Primary Fields (>50% frequency):**
- `serviceID` (100%) - Block service identifier
  - Sample values: 230, 110, 231
- `usedBytes` (100%) - Bytes used by the service
  - Sample values: 1909106990888, 1909724887808, 1909110310916

### 5. **Scheduler Component** (3 records)
**Purpose:** Scheduled task management

**Primary Fields:**
- `scheduleID` (66.7%) - Schedule identifier
  - Sample values: 71, 103

### 6. **Snaps (Snapshots) Component** (28 records)
**Purpose:** Snapshot management and replication

**Primary Fields (>50% frequency):**
- `groupSnapshotID` (78.6%) - Group snapshot identifier
  - Sample values: 13831746

**Secondary Fields:**
- `sliceID` (35.7%) - Slice identifier
- `snapshotID` (35.7%) - Individual snapshot identifier
- `groupUUID` (21.4%) - Group UUID
- `volumeID` (21.4%) - Volume identifier
- Various snapshot-related fields (14.3% each): `checksum`, `fromServiceID`, `fromSlice`, `newSnapID`, `oldSnapID`
- Complex data structures (7.1% each): `complex_attributes`, `complex_groupSnapshots`, etc.

### 7. **Vvols (Virtual Volumes) Component** (2 records)
**Purpose:** Virtual volume management

**Primary Fields (>50% frequency):**
- `overrideSnapMirrorHold` (100%) - Snapshot mirror hold override
  - Sample values: False
- `snapshotID` (100%) - Associated snapshot identifier
  - Sample values: 13746085, 13746086
- `vvolParms` (100%) - Virtual volume parameters

## Field Sharing Analysis

### Shared Fields (Used by Multiple Components)
Only 2 fields (3.5%) are shared across components:

1. **`serviceID`** - Used by Event and MS components
   - In Event: Associates events with specific services
   - In MS: Identifies block services for statistics

2. **`snapshotID`** - Used by Snaps and Vvols components
   - In Snaps: References individual snapshots
   - In Vvols: Associates virtual volumes with snapshots

### Exclusive Fields (Component-Specific)
55 fields (96.5%) are exclusive to specific components, indicating strong separation of concerns:

**API Exclusive Fields:**
- Authentication: `authMethod`, `user`, `accounts,ou`, `sourceIP`
- Threading: `activeApiThreads`, `totalApiThreads`
- Request tracking: `requestID`
- Complex data: Various `complex_*` fields for detailed logging

**Event Exclusive Fields:**
- Event metadata: `type`, `published`, `reported`, `mNumEventsPublished`
- Event content: `complex_details`, `complex_event`, `complex_message`
- Context: `nodeID`

**MS Exclusive Fields:**
- Storage metrics: `usedBytes`

**Snapshots Exclusive Fields:**
- Snapshot management: `groupSnapshotID`, `snapshotUUID`, `groupUUID`
- Replication: `replicateGroup`, `replicateSnapshot`, `srcSnapshotID`
- FIFO management: `fifoSize`, `minFifoSize`, `numFifoSnaps`, `oldestFifoSnap`
- Slice management: `sliceID`, `fromSlice`, `fromServiceID`

## Usage Recommendations

### For Log Filtering:
1. **API logs**: Filter by component="API" to get authentication and request data
2. **Storage metrics**: Filter by component="MS" for drive usage and service statistics
3. **Event tracking**: Filter by component="Event" for system events and notifications
4. **Snapshot operations**: Filter by component="Snaps" for snapshot management activities
5. **Leadership activities**: Filter by component="Leader" for cluster coordination
6. **Scheduled tasks**: Filter by component="Scheduler" for scheduled operations
7. **Virtual volumes**: Filter by component="Vvols" for virtual volume operations

### For Field Analysis:
- Most components have highly specialized field sets with minimal overlap
- `serviceID` is the most universal field, appearing in both Event and MS logs
- Component-specific fields provide deep insight into each subsystem's operations
- Complex fields (prefixed with `complex_`) contain structured data requiring additional parsing

### For Troubleshooting:
- **Authentication issues**: Focus on API component with `authMethod`, `user`, `sourceIP`
- **Storage problems**: Check MS component for `serviceID` and `usedBytes` patterns
- **Snapshot failures**: Examine Snaps component for replication and FIFO fields
- **Event correlation**: Use Event component with `nodeID`, `type`, and timestamps
- **Cluster coordination**: Monitor Leader component for voting and sequence data

## Data Quality Notes

- Analysis based on 100 log entries with good component distribution
- High field exclusivity (96.5%) indicates well-structured component separation
- Some fields may appear in other components not represented in this sample
- Complex fields may contain nested JSON requiring additional parsing for full analysis