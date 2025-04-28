#!/bin/bash
set -e

# Create publications on both nodes
echo "Creating publications..."
docker exec pg-publisher psql -U replicator -d demo -c \
"CREATE PUBLICATION pub_publisher FOR TABLE items;"

docker exec pg-subscriber psql -U replicator -d demo -c \
"CREATE PUBLICATION pub_subscriber FOR TABLE items;"

# Create bidirectional subscriptions
echo "Creating subscriptions..."
# Publisher -> Subscriber
docker exec pg-publisher psql -U replicator -d demo -c \
"CREATE SUBSCRIPTION sub_to_subscriber
CONNECTION 'host=host.docker.internal port=5433 user=replicator password=secret dbname=demo'
PUBLICATION pub_subscriber
WITH (copy_data = false, origin = 'none');"

# Subscriber -> Publisher
docker exec pg-subscriber psql -U replicator -d demo -c \
"CREATE SUBSCRIPTION sub_to_publisher
CONNECTION 'host=host.docker.internal port=5432 user=replicator password=secret dbname=demo'
PUBLICATION pub_publisher
WITH (copy_data = false, origin = 'none');"

# Monitor
watch -n 1 '
  echo "Publisher subscriptions:" &&
  docker exec pg-publisher psql -U replicator -d demo -c "SELECT * FROM pg_stat_subscription;" &&
  echo "\nSubscriber subscriptions:" &&
  docker exec pg-subscriber psql -U replicator -d demo -c "SELECT * FROM pg_stat_subscription;"
'
