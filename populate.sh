#!/bin/bash

# Continuous insert during setup
for i in {1..20000}; do
  echo "Inserting item $i"
  docker exec pg-subscriber psql -U replicator -d demo -c \
  "INSERT INTO items (name) VALUES ('Item during setup $i')"
  sleep 1
done

