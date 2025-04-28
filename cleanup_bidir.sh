#!/bin/bash
set -e  # Exit on error

# Cleanup both nodes
for CONTAINER in pg-publisher pg-subscriber; do
  echo "Cleaning $CONTAINER..."
  
  # Drop subscriptions (native and pglogical)
  docker exec $CONTAINER psql -U replicator -d demo -c \
  "DO \$\$ 
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'sub_to_subscriber') THEN
      DROP SUBSCRIPTION sub_to_subscriber;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'sub_to_publisher') THEN
      DROP SUBSCRIPTION sub_to_publisher;
    END IF;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Subscriptions already removed';
  END \$\$;"

  # Drop publications
  docker exec $CONTAINER psql -U replicator -d demo -c \
  "DROP PUBLICATION IF EXISTS pub_publisher, pub_subscriber;"

  # Drop replication slots (native)
  docker exec $CONTAINER psql -U replicator -d demo -c \
  "SELECT pg_drop_replication_slot(slot_name) 
   FROM pg_replication_slots 
   WHERE slot_name IN ('sub_to_subscriber', 'sub_to_publisher', 'sync_slot');"

  # Cleanup pglogical artifacts (if extension exists)
  docker exec $CONTAINER psql -U replicator -d demo -c \
  "DO \$\$ 
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pglogical') THEN
      PERFORM pglogical.drop_subscription('sub_to_subscriber');
      PERFORM pglogical.drop_subscription('sub_to_publisher');
      PERFORM pglogical.drop_replication_set('default');
      PERFORM pglogical.drop_node('$CONTAINER');
    END IF;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'pglogical artifacts already removed';
  END \$\$;"
done

echo "Monitoring remaining objects..."
watch -n 1 '
  echo "Publisher:";
  docker exec pg-publisher psql -U replicator -d demo -c "\dRp+" &&
  docker exec pg-publisher psql -U replicator -d demo -c "\dRs" &&
  echo "\nSubscriber:";
  docker exec pg-subscriber psql -U replicator -d demo -c "\dRp+" &&
  docker exec pg-subscriber psql -U replicator -d demo -c "\dRs"
'
