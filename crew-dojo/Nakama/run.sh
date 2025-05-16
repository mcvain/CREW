#!/bin/bash
# Original script 
# if [ ! -f "go.mod" ]; then
#     go mod init example.com/go-project
#     go get github.com/heroiclabs/nakama-common/runtime@v1.26.0
# fi
# go mod vendor
# docker compose -p dojo-nakama-server up -d --build nakama
# docker image prune

# Apptainer version

#!/bin/bash

# Check if Go module files exist, if not initialize them
if [ ! -f "go.mod" ]; then
    go mod init example.com/go-project
    go get github.com/heroiclabs/nakama-common/runtime@v1.26.0
fi
go mod vendor

# Create necessary directories if they don't exist
mkdir -p ./data
mkdir -p ./postgres_data

# Build Nakama container from Dockerfile if image doesn't exist
if [ ! -f "nakama.sif" ]; then
    echo "Building Nakama Apptainer image..."
    apptainer build --sandbox nakama_sandbox docker-daemon://nakama:latest || apptainer build --build nakama_sandbox .
    apptainer build nakama.sif nakama_sandbox
fi

# Build PostgreSQL container if it doesn't exist
if [ ! -f "postgres.sif" ]; then
    echo "Building PostgreSQL Apptainer image..."
    apptainer build postgres.sif docker://postgres:12.2-alpine
fi

# Check if postgres instance is already running
if ! apptainer instance list | grep -q "postgres-instance"; then
    echo "Starting PostgreSQL server as Apptainer instance..."
    apptainer instance start \
        --fakeroot \
        --network none \
        --env POSTGRES_DB=nakama \
        --env POSTGRES_PASSWORD=localdb \
        --bind ./postgres_data:/var/lib/postgresql/data \
        postgres.sif postgres-instance
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL to start..."
    sleep 10
fi

# Check if nakama instance is already running
if ! apptainer instance list | grep -q "nakama-instance"; then
    echo "Starting Nakama server as Apptainer instance..."
    apptainer instance start \
        --fakeroot \
        --network host \
        --bind ./data:/nakama/data \
        --env "NAKAMA_DATABASE_ADDRESS=localhost:5432/nakama" \
        nakama.sif nakama-instance
    
    echo "Nakama server started. API available at http://localhost:7350/"
fi

echo "Services are running. Use 'apptainer instance list' to see running instances."
echo "To stop services: apptainer instance stop nakama-instance postgres-instance"
echo "NOTE: With --network=none, containers can only communicate via the host network."
echo "You may need to run this script with sudo for full networking capabilities."
