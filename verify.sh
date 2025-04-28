#!/bin/bash
echo "Publisher count:"
docker exec pg-publisher psql -U replicator -d demo -c "SELECT COUNT(*) FROM items;"

echo "Subscriber count:"
docker exec pg-subscriber psql -U replicator -d demo -c "SELECT COUNT(*) FROM items;"

