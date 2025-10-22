# Deployments Directory

Place your `XDStarClient.ear` file in this directory.

## How to Deploy

1. Obtain the XDStarClient.ear file (either build from source or download)
2. Copy it to this directory:
   ```bash
   cp /path/to/XDStarClient.ear ./deployments/
   ```
3. The file will be automatically deployed by JBoss when the container starts

## Building from Source

According to the Gazelle documentation, the sources are available on IHE's GitLab server.
You can compile the application using Maven with the production profile.

## Deployment Status

JBoss will create marker files in this directory:
- `XDStarClient.ear.deployed` - Successfully deployed
- `XDStarClient.ear.failed` - Deployment failed (check logs)
- `XDStarClient.ear.pending` - Deployment in progress

## Accessing Deployment Logs

View JBoss logs to monitor deployment:
```bash
docker-compose logs -f jboss
```
