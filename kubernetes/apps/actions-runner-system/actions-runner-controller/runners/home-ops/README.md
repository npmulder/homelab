# GitHub Actions Runner Setup Documentation

This directory contains the configuration for GitHub Actions self-hosted runners using the [Actions Runner Controller](https://github.com/actions/actions-runner-controller) (ARC) with the newer **Runner Scale Set** architecture.

## Architecture Overview

The setup consists of two main components:

1. **Controller** (`../app/helmrelease.yaml`): The ARC controller that manages runner lifecycle
2. **Runner Scale Set** (`helmrelease.yaml`): The actual runners that execute GitHub Actions workflows

## File Structure

```
runners/home-ops/
├── helmrelease.yaml      # Main runner configuration
├── externalsecret.yaml   # GitHub authentication secrets
├── rbac.yaml            # Kubernetes permissions for runners
└── kustomization.yaml   # Kustomize resource list
```

## Component Breakdown

### 1. HelmRelease (`helmrelease.yaml`)

This file defines two resources:

#### OCIRepository (Lines 1-14)
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
```
- **Purpose**: Tells Flux where to find the Helm chart for runner scale sets
- **Chart Location**: `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set`
- **Version**: `0.12.1` (tag)
- **Update Interval**: Every 5 minutes

#### HelmRelease (Lines 16-71)
The main runner configuration:

**Basic Configuration:**
- **Name**: `home-ops-runner` (used as service account name too)
- **Update Interval**: Every 1 hour
- **Installation**: Retries indefinitely on failure
- **Upgrade**: 3 retries, cleans up on failure

**GitHub Configuration:**
```yaml
githubConfigUrl: https://github.com/onedr0p/home-ops
githubConfigSecret: home-ops-runner-secret
```
- **githubConfigUrl**: The repository or organization URL where runners will be registered
- **githubConfigSecret**: Kubernetes secret containing GitHub App credentials (created by `externalsecret.yaml`)

**Scaling:**
```yaml
minRunners: 1
maxRunners: 3
```
- Always keeps at least 1 runner available
- Can scale up to 3 runners when multiple jobs are queued

**Container Mode (Kubernetes):**
```yaml
containerMode:
  type: kubernetes
  kubernetesModeWorkVolumeClaim:
    accessModes: ["ReadWriteOnce"]
    storageClassName: openebs-hostpath
    resources:
      requests:
        storage: 25Gi
```
- **Type**: `kubernetes` - Runs jobs in Kubernetes pods (not Docker-in-Docker)
- **Storage**: 25GB persistent volume for runner workspace
- **Storage Class**: Uses OpenEBS hostpath provisioner

**Runner Image:**
```yaml
image: ghcr.io/home-operations/actions-runner:2.325.0@sha256:...
```
- Custom runner image with specific version
- Pinned by SHA256 for security

**Environment Variables:**
```yaml
env:
  - name: ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER
    value: "false"
  - name: NODE
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
```
- **ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER**: Allows jobs without container requirements
- **NODE**: Exposes the host IP to the runner

**Talos Integration:**
```yaml
volumes:
  - name: talos
    secret:
      secretName: home-ops-runner
```
- Mounts Talos secrets for node-level operations
- Requires Talos service account (defined in `rbac.yaml`)

**Service Account:**
```yaml
serviceAccountName: home-ops-runner
controllerServiceAccount:
  name: actions-runner-controller
  namespace: actions-runner-system
```
- Runner pods use `home-ops-runner` service account
- Controller operations use `actions-runner-controller` service account

### 2. ExternalSecret (`externalsecret.yaml`)

**Purpose**: Pulls GitHub App credentials from 1Password and creates a Kubernetes secret

**Configuration:**
- **Secret Store**: Uses `onepassword` ClusterSecretStore
- **Target Secret**: `home-ops-runner-secret` (referenced in helmrelease)
- **Data Source**: 1Password item key `actions-runner`
- **Required Fields**:
  - `ACTIONS_RUNNER_APP_ID`: GitHub App ID
  - `ACTIONS_RUNNER_INSTALLATION_ID`: Installation ID
  - `ACTIONS_RUNNER_PRIVATE_KEY`: Private key (PEM format)

**For Your Setup:**
You'll need to:
1. Create a GitHub App in your organization/repository
2. Store the credentials in your secret store (1Password, Vault, etc.)
3. Update the `secretStoreRef` if using a different store

### 3. RBAC (`rbac.yaml`)

Defines permissions for the runner:

**Kubernetes Permissions:**
```yaml
kind: ClusterRoleBinding
roleRef:
  kind: ClusterRole
  name: cluster-admin
```
- Grants `cluster-admin` role to runner service account
- **Note**: This is very permissive! Consider restricting based on your needs

**Talos Permissions:**
```yaml
apiVersion: talos.dev/v1alpha1
kind: ServiceAccount
spec:
  roles: ["os:admin"]
```
- Grants Talos OS admin permissions
- Required for node-level operations (if your runners need this)

## Why GitHub Apps Are Required

### The Short Answer
**Runner Scale Sets** (the architecture used here) **require** GitHub App authentication. This is not optional - it's the only supported authentication method for this newer runner architecture.

### Why Not Personal Access Tokens (PATs)?

**GitHub Apps are required because:**

1. **Architecture Requirement**: The newer Runner Scale Set architecture (used in this setup) only supports GitHub App authentication. Personal Access Tokens (PATs) are not supported.

2. **Better Security**:
   - Fine-grained permissions (only grant what's needed)
   - No user account tied to the token (if a user leaves, the app still works)
   - Can be scoped to specific repositories/organizations
   - Private keys can be rotated without affecting the app

3. **Better Management**:
   - Install once, use across multiple repositories
   - Easy to revoke or modify permissions
   - Better audit trail (actions are attributed to the app, not a user)
   - No risk of token expiration breaking your runners

4. **Scalability**:
   - Apps can handle higher rate limits
   - Better suited for automated systems
   - Designed for programmatic access

### Alternatives (Not Available for This Setup)

If you were using the **older RunnerDeployment** architecture (not Runner Scale Sets), you could use:
- Personal Access Tokens (PATs) - but these are deprecated and not recommended
- Fine-grained PATs - still not as secure as GitHub Apps

**However**, since this setup uses Runner Scale Sets, GitHub App authentication is the **only** option.

### What About Personal Access Tokens?

PATs have several disadvantages:
- ❌ Tied to a user account (if user leaves, token breaks)
- ❌ Broad permissions (hard to scope down)
- ❌ Can expire or be revoked by the user
- ❌ Not supported by Runner Scale Sets
- ❌ Weaker security model

GitHub Apps solve all these issues and are the modern, recommended approach.

## Setup Steps for Your Environment

### 1. Create GitHub App

#### Step 1.1: Navigate to GitHub App Registration

1. Go to your GitHub organization/repository
2. Navigate to: **Settings** → **Developer settings** → **GitHub Apps**
3. Click **"New GitHub App"** or **"Register new GitHub App"**

#### Step 1.2: Fill Out the Registration Form

**Required Fields:**

1. **GitHub App name*** (Required)
   - Example: `my-org-actions-runner` or `homelab-runners`
   - Must be unique across GitHub
   - Use a descriptive name that identifies your setup

2. **Description** (Optional but recommended)
   - Example: `Self-hosted GitHub Actions runners for Kubernetes`
   - Helps identify the app's purpose

3. **Homepage URL*** (Required)
   - Can be your repository URL: `https://github.com/your-org/your-repo`
   - Or your organization URL: `https://github.com/your-org`
   - This is just for identification - doesn't need to be a real website

**OAuth/User Authorization Section** (Skip these for runners):

4. **Callback URL** (Optional - leave empty)
   - Not needed for Actions runners
   - Click "Delete" if a placeholder is shown

5. **Expire user authorization tokens** (Uncheck)
   - Not needed for runners

6. **Request user authorization (OAuth) during installation** (Uncheck)
   - Not needed for runners

7. **Enable Device Flow** (Uncheck)
   - Not needed for runners

**Post Installation Section** (Optional):

8. **Setup URL** (Leave empty)
   - Not needed for runners

9. **Redirect on update** (Uncheck)
   - Not needed for runners

**Webhook Section:**

10. **Active** (Check or Uncheck - your choice)
    - **Checked**: GitHub will send webhook events (useful for monitoring)
    - **Unchecked**: No webhooks (simpler, works fine for runners)
    - For runners, webhooks are optional

11. **Webhook URL*** (Required if Active is checked)
    - If you checked "Active", provide a URL (can be a placeholder like `https://example.com/webhook`)
    - If you unchecked "Active", this field may not appear or can be left empty
    - **Note**: For basic runner functionality, you can uncheck "Active" to avoid needing a webhook URL

#### Step 1.3: Set Permissions

After clicking "Create GitHub App", you'll be taken to the app settings page. Here you need to configure permissions:

**Repository permissions:**
- **Actions**: Set to **Read and write** (Required)
- **Metadata**: Set to **Read-only** (Required)

**Organization permissions** (if installing at org level):
- **Self-hosted runners**: Set to **Read and write** (Required)

**Note**: You can leave all other permissions as "No access".

#### Step 1.4: Generate Private Key

1. Scroll down to the **"Private keys"** section
2. Click **"Generate a private key"**
3. **Download the `.pem` file immediately** - you can only download it once!
4. Save it securely - you'll need this for the ExternalSecret

#### Step 1.5: Note Your App ID

On the app settings page (where you are now), note down:

1. **App ID**: Found in the "About" section at the top of the page
   - In your case: `2375024` (visible in the "About" section)
   - This is the number next to "App ID:"

#### Step 1.6: Install the App (This is where you get the Installation ID)

**The Installation ID is only visible AFTER you install the app.** Here's how to get it:

1. **Click the "Install App" button** (usually in the left sidebar or at the top of the app settings page)

2. **Choose where to install:**
   - **Only select repositories**: Choose specific repos
   - **All repositories**: Install on all repos in your org
   - Click **"Install"**

3. **After installation, you'll see the Installation ID in one of these places:**

   **Method 1: From the URL**
   - After installation, look at the browser URL
   - It will look like: `https://github.com/settings/installations/78901234`
   - The number at the end (`78901234`) is your **Installation ID**

   **Method 2: From the Installation Settings Page**
   - After installation, you'll be on the installation settings page
   - The Installation ID is usually displayed at the top of the page
   - It may be labeled as "Installation ID" or shown in the page title/header

   **Method 3: From the App Settings**
   - Go back to your app settings page
   - Click **"Installations"** in the left sidebar
   - You'll see a list of installations
   - The Installation ID is shown for each installation

   **Method 4: Using GitHub API** (if you have access)
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://api.github.com/app/installations
   ```

4. **Note down the Installation ID** - you'll need this for your ExternalSecret configuration

**Important**: You need to install the app first before you can get the Installation ID. The Installation ID is specific to each installation (repository or organization).

### 2. Store Credentials

Store the credentials in your secret management system:
- App ID → `ACTIONS_RUNNER_APP_ID`
- Installation ID → `ACTIONS_RUNNER_INSTALLATION_ID`
- Private Key → `ACTIONS_RUNNER_PRIVATE_KEY`

### 3. Update Configuration

**In `helmrelease.yaml`:**
- Change `githubConfigUrl` to your repository/org URL
- Adjust `minRunners` and `maxRunners` as needed
- Update storage size if needed
- Modify runner image if using a custom one

**In `externalsecret.yaml`:**
- Update `secretStoreRef.name` if using different secret store
- Ensure the secret store has the credentials

**In `rbac.yaml`:**
- Consider reducing permissions from `cluster-admin` to least privilege
- Remove Talos service account if not using Talos

### 4. Deploy

The configuration is managed by Flux, so it will be automatically deployed when committed to your GitOps repository.

## Key Concepts

### Runner Scale Sets vs RunnerDeployments

This setup uses **Runner Scale Sets** (newer architecture):
- More efficient resource usage
- Better scaling behavior
- Supports ephemeral runners
- Uses Kubernetes mode for job execution

### Container Mode: Kubernetes

Jobs run in Kubernetes pods, not Docker-in-Docker:
- More secure (no Docker socket access)
- Better resource isolation
- Requires `ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER: "false"` for jobs without containers

### Storage

Runners need persistent storage for:
- Runner workspace
- Checkout code
- Build artifacts
- Cache directories

25GB is a reasonable default, adjust based on your workload.

## Troubleshooting

### Runners Not Appearing in GitHub

1. Check ExternalSecret status: `kubectl get externalsecret -n actions-runner-system`
2. Verify secret exists: `kubectl get secret home-ops-runner-secret -n actions-runner-system`
3. Check HelmRelease status: `kubectl get helmrelease -n actions-runner-system`
4. View runner pod logs: `kubectl logs -n actions-runner-system -l runner-scale-set=home-ops-runner`

### Jobs Not Starting

1. Verify runner is registered: Check GitHub → Settings → Actions → Runners
2. Check runner pod status: `kubectl get pods -n actions-runner-system`
3. Review controller logs: `kubectl logs -n actions-runner-system -l app=actions-runner-controller`

### Permission Issues

1. Verify RBAC: `kubectl get clusterrolebinding home-ops-runner`
2. Check service account: `kubectl get serviceaccount home-ops-runner -n actions-runner-system`
3. Review pod security policies if enabled

## References

- [Actions Runner Controller Documentation](https://github.com/actions/actions-runner-controller)
- [Runner Scale Sets Guide](https://github.com/actions/actions-runner-controller/blob/master/docs/detailed-docs.md)
- [GitHub App Setup](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)

