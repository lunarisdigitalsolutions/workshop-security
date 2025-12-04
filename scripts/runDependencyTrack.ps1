Write-Host "Starting Dependency-Track service using Docker Compose..."
docker compose -f "$PSScriptRoot\..\docker-compose.dependency-track.yml" up -d
