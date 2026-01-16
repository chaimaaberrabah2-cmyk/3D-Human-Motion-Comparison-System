# 3D Human Motion Comparison System - Docker Guide

## Quick Start with Docker

### Prerequisites
- Docker Desktop installed ([Download](https://docs.docker.com/get-docker/))
- At least 4GB RAM available
- 10GB free disk space

### Deployment Steps

1. **Clone or extract the project**
   ```bash
   cd /path/to/3D-Human-Motion-Comparison-System
   ```

2. **Run the deployment script**
   ```bash
   ./deploy.sh
   ```

   This will:
   - Build the Docker image
   - Start PostgreSQL database
   - Initialize database schema
   - Load training data automatically
   - Start the application

3. **Access the application**
   - Application: `http://localhost:8000`
   - Database: `localhost:5432`

### Manual Docker Commands

If you prefer manual control:

```bash
# Build the image
docker-compose build

# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Restart services
docker-compose restart
```

### Database Access

Access PostgreSQL directly:
```bash
docker-compose exec db psql -U postgres -d motion_compare_db
```

Query exercises:
```sql
SELECT exercise_name, category FROM exercises;
```

### Troubleshooting

**Issue: Port 5432 already in use**
```bash
# Stop local PostgreSQL
brew services stop postgresql

# Or change port in docker-compose.yml
ports:
  - "5433:5432"  # Use port 5433 instead
```

**Issue: Out of memory**
```bash
# Increase Docker memory in Docker Desktop settings
# Preferences → Resources → Memory (set to 4GB+)
```

**Issue: Permission denied**
```bash
# Make deploy script executable
chmod +x deploy.sh
```

### Data Volumes

Training data and models are mounted as read-only volumes:
- `./train` → `/app/train` (read-only)
- `./models` → `/app/models` (read-only)
- `./uploads` → `/app/uploads` (read-write)

### Sharing with Team

**Option 1: Share the entire project**
```bash
# Create a tar archive (excluding large files)
tar -czf motion-compare-system.tar.gz \
  --exclude='venv' \
  --exclude='__pycache__' \
  --exclude='.git' \
  .
```

**Option 2: Share via Git**
```bash
git add .
git commit -m "Add Docker support"
git push
```

**Option 3: Docker Hub (for image only)**
```bash
# Tag the image
docker tag motion_compare_app:latest yourusername/motion-compare:latest

# Push to Docker Hub
docker push yourusername/motion-compare:latest
```

### Environment Variables

Edit `docker-compose.yml` to change:
- Database credentials
- Application settings
- Port mappings

### Development Mode

For development with live code reload:
```yaml
# Add to docker-compose.yml under app service
volumes:
  - .:/app  # Mount entire directory
command: python main.py --dev
```

### Production Deployment

For production, consider:
1. Using environment-specific `.env` files
2. Setting up SSL/TLS
3. Using a reverse proxy (nginx)
4. Implementing proper logging
5. Setting up monitoring

### Clean Up

Remove all containers and volumes:
```bash
docker-compose down -v
```

Remove Docker image:
```bash
docker rmi motion_compare_app
```
