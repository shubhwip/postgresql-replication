#!/bin/bash
# Insert initial data
docker exec -it pg-subscriber psql -U replicator -d demo -c "$(cat init.sql)"

# Continuous insert during setup
for i in {1..10}; do
  docker exec pg-subscriber psql -U replicator -d demo -c \
  "INSERT INTO items (name) VALUES ('Item during setup $i')"
done

