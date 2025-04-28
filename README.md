# Logical Replication Setup Guide (Cloud SQL for PostgreSQL)

# Logical Replication Gap Challenge

## The Synchronization Problem

**Typical Scenario:**
```text
Timeline:
T1 ─── Backup Start ──── T2 ─── Restore Complete ──── T3 ─── Replication Start ───▶
      (Node1 Snapshot)          (Node2 Ready)            (Continuous Sync)
```

**What Breaks:**
1. **Data Blackout Period:** Changes made to Node1 between T1 (backup) and T3 (replication start) are lost
2. **WAL Gap:** PostgreSQL's Write-Ahead Logs (WAL) between backup and replication setup aren't transferred
3. **Mismatched LSNs:** Restored backup on Node2 doesn't know the Log Sequence Number (LSN) where Node1 continued writing after backup

**Why This Matters:**
- Causes silent data loss for business-critical applications
- Forces administrators to either:
  - Accept missing records, or
  - Perform full database resyncs (expensive for large datasets)

---

## The Solution: Bridging the Gap with Logical Replication Slots

**How We Fix It:**
```text
Timeline:
T1 ─── Backup Start ──── T2 ─── Restore Complete ──── T3 ─── Replication Start ───▶
      │                  │                            │
      └─ Replication Slot Created                     │
          (Preserves WALs from T1) ───────────────────┘
```

**Key Components:**
1. **Replication Slot:** Created _before_ backup, preserves WALs from T1 onward
2. **Point-in-Time Recovery:** Cloud SQL maintains slot metadata during backup/restore
3. **LSN Alignment:** Restored Node2 starts replication exactly where backup ended

**Technical Flow:**
1. Create logical replication slot on Node1 **before** backup
2. Backup includes slot's restart_lsn position
3. Restored Node2 knows to request changes starting at backup's LSN
4. Subscription uses existing slot to fetch all changes since T1

---

## Why This Guide Matters

**Avoid:**
- 15-30% data loss in typical backup-to-replication setups
- Multi-hour downtime for full resyncs (critical for 24/7 systems)
- Manual WAL file shipping/archiving

**Enable:**
- Zero data loss between backup and replication
- Sub-second RPO (Recovery Point Objective)
- Seamless failover for HA/DR configurations

---

```sql
-- Critical Step: Slot Creation Before Backup
SELECT pg_create_logical_replication_slot('sync_slot', 'pgoutput');
-- Returns: (sync_slot, 0/12345678) ← This LSN is preserved in backup
```

This approach guarantees all changes made after the backup are automatically replicated, closing the T1-T3 synchronization gap inherent in basic replication setups.

---

## 1. Define Parameters

Replace the following variables with your actual values:

```bash
# Set these variables before running commands
export PROJECT_ID="your-gcp-project"
export REGION="us-central1-a"
export DB_VERSION="POSTGRES_17"
export DB_USER="postgres"
export DB_PASSWORD="yourpassword"
export NODE1_NAME="node1"
export NODE2_NAME="node2"
export NODE1_IP="PRIMARY_NODE_IP"
export NODE2_IP="REPLICA_NODE_IP"
export DEMO_SQL="demo-big-en-20170815.sql"
```
---

## 2. Create PostgreSQL Instances

Create the primary (node1) and replica (node2) instances with the required flags for logical replication.

```bash
gcloud sql instances create $NODE1_NAME \
  --database-version=$DB_VERSION \
  --cpu=2 \
  --memory=4GiB \
  --zone=$REGION \
  --root-password=$DB_PASSWORD \
  --no-deletion-protection \
  --database-flags=cloudsql.enable_pglogical=on,cloudsql.logical_decoding=on,max_replication_slots=10,max_worker_processes=8,max_wal_senders=10,track_commit_timestamp=on,pglogical.conflict_resolution=last_update_wins \
  --edition=ENTERPRISE

gcloud sql instances create $NODE2_NAME \
  --database-version=$DB_VERSION \
  --cpu=2 \
  --memory=4GiB \
  --zone=$REGION \
  --root-password=$DB_PASSWORD \
  --no-deletion-protection \
  --database-flags=cloudsql.enable_pglogical=on,cloudsql.logical_decoding=on,max_replication_slots=10,max_worker_processes=8,max_wal_senders=10,track_commit_timestamp=on,pglogical.conflict_resolution=last_update_wins \
  --edition=ENTERPRISE
```

---

## 3. Configure Authorized Networks

- Add your local IP and each instance’s outgoing IP to the authorized networks of both instances.
- This ensures connectivity for replication and management.

---

## 4. Prepare Demo Database

**Download and prepare the demo SQL file:**

```bash
curl https://edu.postgrespro.com/demo-big-en.zip -o demo.zip
unzip demo.zip
sed -i '/DROP DATABASE/d;/CREATE DATABASE/d' $DEMO_SQL
```

---

## 5. Create Database on Both Instances

```bash
gcloud sql databases create demo --instance=$NODE1_NAME
gcloud sql databases create demo --instance=$NODE2_NAME
```

---

## 6. Populate Primary (node1) with Demo Data

```bash
gcloud sql import sql $NODE1_NAME $DEMO_SQL --database=demo
```

---

## 7. Drop Constraints on node1

Connect to node1 and run:

```sql
ALTER TABLE bookings.boarding_passes DROP CONSTRAINT IF EXISTS boarding_passes_flight_id_boarding_no_key;
ALTER TABLE bookings.boarding_passes DROP CONSTRAINT IF EXISTS boarding_passes_flight_id_seat_no_key;
ALTER TABLE bookings.boarding_passes DROP CONSTRAINT IF EXISTS boarding_passes_ticket_no_fkey;
```

---

## 8. Grant Replication Role to postgres

```sql
ALTER USER postgres WITH REPLICATION;
```

---

## 9. Create Publication and Replication Slot on node1

Connect to node1 and run:

```sql
CREATE PUBLICATION pub_publisher FOR TABLE bookings.boarding_passes;
SELECT pg_create_logical_replication_slot('sync_slot', 'pgoutput');
```

---

## 10. Take Backup of node1

- Use the Cloud SQL UI to take a backup of node1 after creating the publication and replication slot.

---

## 11. Restore Backup to node2

- Use the Cloud SQL UI to restore the backup to node2, overwriting the instance.

---

## 12. Insert New Records into node1

You can now insert new records into node1. These will be replicated later.
```shell
bash populate_boarding_passes.sh 
```

---

## 13. Set Up Subscription on node2

Connect to node2 and run (replace placeholders):

```sql
CREATE SUBSCRIPTION my_sub
  CONNECTION 'host=$NODE1_IP port=5432 user=$DB_USER password=$DB_PASSWORD dbname=demo'
  PUBLICATION pub_publisher
  WITH (copy_data = false, create_slot = false, slot_name = 'sync_slot');
```

- `copy_data = false`: Only changes since the backup will be replicated.
- `create_slot = false`: Uses the existing slot created on node1.
- `slot_name = 'sync_slot'`: Matches the slot created earlier.

---

## 14. Validate Replication

Check replication status on node2:

```sql
SELECT * FROM pg_stat_subscription;
```

Insert a test row on node1 and verify it appears on node2.

---

## Notes

- Use variables for all IPs, passwords, and instance names.
- Only changes made after the backup will be replicated to node2.
- For bidirectional replication, repeat the publication/subscription process in the opposite direction.

---