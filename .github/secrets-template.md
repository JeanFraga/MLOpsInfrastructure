# GitHub Secrets Setup Guide

Configure the following secrets in your GitHub repository for automated deployments.

## Required Secrets

### Kubernetes Configuration
- **`KUBECONFIG`** - Base64 encoded kubeconfig file for your Kubernetes cluster

### Optional Secrets (for production)
- **`DOCKER_REGISTRY_URL`** - Docker registry URL (e.g., `ghcr.io`, `docker.io`)
- **`DOCKER_REGISTRY_USERNAME`** - Docker registry username
- **`DOCKER_REGISTRY_PASSWORD`** - Docker registry password or token
- **`SLACK_WEBHOOK_URL`** - Slack webhook for deployment notifications
- **`MLOPS_DOMAIN`** - Domain name for MLOps services (e.g., `mlops.example.com`)

## Setup Instructions

1. **Go to your repository settings**
   - Navigate to `https://github.com/JeanFraga/MLOpsInfrastructure/settings/secrets/actions`

2. **Add the required secrets**
   - Click "New repository secret"
   - Add each secret with the name and value

3. **Environment-specific secrets**
   - Consider using environment-specific secrets for staging vs production

## Generating KUBECONFIG Secret

```bash
# Encode your kubeconfig file
cat ~/.kube/config | base64 | tr -d '\n'
```

Copy the output and paste it as the value for the `KUBECONFIG` secret.

## Security Best Practices

- **Never commit secrets to the repository**
- **Use the minimum required permissions**
- **Rotate secrets regularly**
- **Use environment-specific secrets when possible**
- **Monitor secret usage in GitHub Actions logs**

## Testing Secrets

After adding secrets, test them by:

1. **Running the validation workflow** - Should pass without errors
2. **Checking deployment workflow** - Should authenticate successfully
3. **Monitoring GitHub Actions logs** - Look for authentication errors

## Troubleshooting

### Common Issues

- **Invalid KUBECONFIG**: Ensure the base64 encoding is correct
- **Permission errors**: Check that the kubeconfig has sufficient permissions
- **Network issues**: Verify cluster accessibility from GitHub Actions runners

### Getting Help

If you encounter issues:
- Check the GitHub Actions logs for error details
- Verify your cluster is accessible
- Test your kubeconfig locally first
- Create an issue in this repository for help
