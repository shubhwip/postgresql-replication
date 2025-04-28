#!/bin/bash
set -e  # Exit on error

# Create publication first
docker exec pg-publisher psql -U replicator -d demo -c "CREATE PUBLICATION my_pub FOR TABLE items;"

# Then create replication slot in separate transaction
# docker exec pg-publisher psql -U replicator -d demo -c "SELECT pg_create_logical_replication_slot('sync_slot', 'pgoutput');"

echo "Creating subscription..."
# docker exec pg-subscriber psql -U replicator -d demo -c \
# "CREATE SUBSCRIPTION my_sub 
# CONNECTION 'host=host.docker.internal port=5432 user=replicator password=secret dbname=demo'
# PUBLICATION my_pub 
# WITH (copy_data = false, create_slot = false, slot_name = 'sync_slot');"

 docker exec pg-subscriber psql -U replicator -d demo -c \
"CREATE SUBSCRIPTION my_sub 
CONNECTION 'host=host.docker.internal port=5432 user=replicator password=secret dbname=demo'
PUBLICATION my_pub 
WITH (copy_data = false);"

echo "Monitoring initial sync..."
watch -n 1 'docker exec pg-subscriber psql -U replicator -d demo -c "SELECT * FROM pg_stat_subscription;"'

