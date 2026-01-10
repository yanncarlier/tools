#!/bin/bash
# delete_all_containers.sh
# Summary: Stop and remove all Docker containers, images, and volumes on the host.
# WARNING: Destructive operation. This will remove containers, images and volumes.

set -euo pipefail

# Stop all running containers (if any)
docker stop $(docker ps -a -q) || true

# Remove all containers (force remove)
docker rm -f $(docker ps -a -q) || true

# Remove all images
docker rmi -f $(docker images -q) || true

# Prune system including volumes
docker system prune -a --volumes -f || true
