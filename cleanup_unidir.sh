#!/bin/bash
# Full cleanup for both publisher and subscriber
echo "Cleaning publisher..."
docker exec pg-publisher psql -U replicator -d demo -c \
"DROP PUBLICATION IF EXISTS my_pub pub_subscriber pub_publisher;
SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots WHERE slot_name IN ('initial_slot', 'sync_slot', 'my_sub', 'sub_to_subscriber', 'sub_to_publisher');" 2>/dev/null

echo "Cleaning subscriber..."
docker exec pg-subscriber psql -U replicator -d demo -c \
"ALTER SUBSCRIPTION my_sub DISABLE;
ALTER SUBSCRIPTION my_sub SET (slot_name = NONE);
DROP SUBSCRIPTION IF EXISTS my_sub;" 2>/dev/null

echo "Removing Docker volumes..."
# rm -rf ./publisher/data
# rm -rf ./subscriber/data
# docker-compose down -v
