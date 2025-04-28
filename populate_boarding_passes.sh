#!/bin/bash

# Database connection settings
# PGHOST="localhost"
# PGPORT="5432"
# PGUSER="replicator"
# PGDATABASE="demo"
# PGPASSWORD="secret"  # Set this only if needed

PGHOST="35.239.133.208"
PGPORT="5432"
PGUSER="postgres"
PGDATABASE="demo"
PGPASSWORD="pwd"  # Set this only if needed

export PGPASSWORD

# Helper function to generate a random 13-digit ticket number as a string
generate_ticket_no() {
  printf "%013d" $(( RANDOM % 9000000000000 + 1000000000000 ))
}

# Helper function to generate a random seat number (e.g., 12A, 27G)
generate_seat_no() {
  row=$(( RANDOM % 40 + 1 ))
  seat=$(echo {A..K} | tr ' ' '\n' | shuf -n 1)
  echo "${row}${seat}"
}

# Set a fixed flight_id for demonstration (change as needed)
flight_id=198393

# Start boarding_no at 1 and increment each time
boarding_no=1

for i in {1..1000}; do
  ticket_no=$(generate_ticket_no)
  seat_no=$(generate_seat_no)

  # Compose SQL statement
  SQL="INSERT INTO boarding_passes (ticket_no, flight_id, boarding_no, seat_no)
       VALUES ('$ticket_no', $flight_id, $boarding_no, '$seat_no')
       ON CONFLICT DO NOTHING;"

  echo "Inserting: ticket_no=$ticket_no, flight_id=$flight_id, boarding_no=$boarding_no, seat_no=$seat_no"
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "$SQL"

  # Increment boarding_no for next iteration
  boarding_no=$((boarding_no + 1))

  # Wait 5 seconds before next insert
  sleep 5
done
