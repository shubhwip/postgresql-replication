## Step-by-Step: Logical Replication with DemoDB

### 1. Download and Prepare DemoDB

**Description:**  
Download the sample database, remove any commands that would drop or create the database (to avoid conflicts), and prepare it for initialization.

```bash
# Download and unzip the DemoDB sample database
wget https://postgrespro.com/files/edu/demo-big-en.zip
unzip demo-big-en.zip

# Remove DROP/CREATE DATABASE commands to avoid overwriting your DB
sed -i '/DROP DATABASE/d;/CREATE DATABASE/d' demo-big-en-20170815.sql

# Rename and move the SQL file for initialization
mv demo-big-en-20170815.sql init-scripts/init.sql
```

---

### 2. Start publisher and subscriber database instances
```shell
docker compose up --build
```

### 3. Drop Constraints on Publisher

**Description:**  
To avoid conflicts during replication or data import, drop constraints that might cause issues. Run these SQL commands on your **publisher** database.

```sql
ALTER TABLE bookings.boarding_passes DROP CONSTRAINT IF EXISTS boarding_passes_flight_id_boarding_no_key;
ALTER TABLE bookings.boarding_passes DROP CONSTRAINT IF EXISTS boarding_passes_flight_id_seat_no_key;
ALTER TABLE bookings.boarding_passes DROP CONSTRAINT IF EXISTS boarding_passes_ticket_no_fkey;
```

---

### 4. Set Up the Publisher

**Description:**  
Create a publication for the table you want to replicate and a logical replication slot to track changes.

```sql
-- On the publisher
CREATE PUBLICATION pub_publisher FOR TABLE bookings.boarding_passes;
SELECT pg_create_logical_replication_slot('sync_slot', 'pgoutput');
```

---

### 5. Take a Table Dump from the Publisher

**Description:**  
Export the relevant table from the publisher in a format suitable for restoring on the subscriber.

```bash
docker exec pg-publisher pg_dump \
  -h host.docker.internal -p 5432 \
  -U replicator \
  -t bookings.boarding_passes \
  -Fc -f /etc/postgresql/boarding_passes.dump demo
```

---

### 6. Restore the Dump on the Subscriber

**Description:**  
Import the dumped table into the subscriber database to ensure both databases are in sync before replication starts.

```bash
docker exec pg-publisher pg_restore \
  -h host.docker.internal -p 5433 \
  -U replicator \
  -d demo /etc/postgresql/boarding_passes.dump
```

---

### 7. Start Inserting Data on the Publisher

**Description:**  
Begin adding new records to the publisher. These new changes will be picked up by logical replication.

```bash
bash populate_boarding_passes.sh
```

---

### 8. Create a Subscription on the Subscriber

**Description:**  
Set up the subscriber to receive changes from the publisher, using the existing replication slot.

```bash
docker exec pg-subscriber psql -U replicator -d demo -c \
"CREATE SUBSCRIPTION my_sub 
  CONNECTION 'host=host.docker.internal port=5432 user=replicator password=secret dbname=demo'
  PUBLICATION pub_publisher 
  WITH (copy_data = false, create_slot = false, slot_name = 'sync_slot');"
```

---

### 9. Verify Replication

**Description:**  
Check that the data is consistent on both publisher and subscriber.

```sql
SELECT COUNT(*) FROM bookings.boarding_passes;
```

Run this on both the publisher and the subscriber to confirm the row counts match.

---

**Tip:**  
If you need to repeat the process, remember to clean up the subscription and replication slot before starting over.

---