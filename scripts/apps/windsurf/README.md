# Secure API Key Management for Windsurf with GNOME Keyring

This guide explains how to securely store API keys and tokens using GNOME Keyring instead of hardcoding them in configuration files for Windsurf.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup Process](#setup-process)
  - [Step 1: Update MCP Configuration](#step-1-update-mcp-configuration)
  - [Step 2: Create Startup Script](#step-2-create-startup-script)
  - [Step 3: Update Desktop File](#step-3-update-desktop-file)
  - [Step 4: Store Secrets in GNOME Keyring](#step-4-store-secrets-in-gnome-keyring)
- [Managing Secrets](#managing-secrets)
  - [Adding a New Secret](#adding-a-new-secret)
  - [Viewing Secrets](#viewing-secrets)
  - [Updating Secrets](#updating-secrets)
  - [Deleting Secrets](#deleting-secrets)
- [Testing and Validation](#testing-and-validation)
- [Troubleshooting](#troubleshooting)
- [Utility Scripts](#utility-scripts)

## Overview

Instead of storing API keys and tokens directly in configuration files, this setup:

1. Stores sensitive information in GNOME Keyring (a secure password manager)
2. Uses a startup script to retrieve the secrets and set them as environment variables
3. Launches Windsurf with these environment variables available

## Prerequisites

- Nobara Linux or any Linux distribution with GNOME Keyring
- `secret-tool` utility (usually part of `libsecret-tools` package)
- Windsurf IDE installed

## Setup Process

### Step 1: Update MCP Configuration

Update your MCP configuration file to use environment variables instead of hardcoded values:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PAT}"
      }
    },
    "brave-search": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-brave-search"
      ],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
    }
  }
}
```

### Step 2: Create Startup Script

Create a script that will load secrets from GNOME Keyring and launch Windsurf:

```bash
#!/bin/bash

# Get secrets from GNOME Keyring
export GITHUB_PAT=$(secret-tool lookup service github-mcp username el_mango)
export BRAVE_API_KEY=$(secret-tool lookup service brave-mcp username el_mango)

# Print status (only for first-time setup verification)
if [ -n "$GITHUB_PAT" ]; then
  echo "GitHub PAT loaded successfully"
else
  echo "Failed to load GitHub PAT"
fi

if [ -n "$BRAVE_API_KEY" ]; then
  echo "Brave API Key loaded successfully"
else
  echo "Failed to load Brave API Key"
fi

# Start Windsurf with the environment variables set
/home/el_mango/.local/share/windsurf/Windsurf/windsurf "$@"
```

Save this as `start-windsurf.sh` in your Windsurf configuration directory (e.g., `~/.codeium/windsurf/`) and make it executable:

```bash
chmod +x ~/.codeium/windsurf/start-windsurf.sh
```

### Step 3: Update Desktop File

Update the Windsurf desktop file to use your startup script:

```ini
[Desktop Entry]
Name=Windsurf IDE
Comment=Windsurf IDE Editor with secure API keys
Exec=/home/el_mango/.codeium/windsurf/start-windsurf.sh %U
Icon=/home/el_mango/.local/share/windsurf/Windsurf/resources/app/resources/linux/code.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Windsurf
MimeType=x-scheme-handler/windsurf;
```

Save this to `~/.local/share/applications/windsurf.desktop`

### Step 4: Store Secrets in GNOME Keyring

Store your API keys and tokens in GNOME Keyring:

```bash
# Store GitHub PAT
secret-tool store --label="GitHub PAT for Windsurf" service github-mcp username el_mango

# Store Brave API Key
secret-tool store --label="Brave API Key for Windsurf" service brave-mcp username el_mango
```

When prompted, enter your API key or token.

## Managing Secrets

### Adding a New Secret

To add a new secret to GNOME Keyring:

```bash
secret-tool store --label="Description of the secret" service service-name username your-username
```

Example:
```bash
secret-tool store --label="OpenAI API Key for Windsurf" service openai-mcp username el_mango
```

Then update your startup script to include the new secret:

```bash
export OPENAI_API_KEY=$(secret-tool lookup service openai-mcp username el_mango)
```

And update your MCP configuration to use the environment variable:

```json
"openai": {
  "env": {
    "OPENAI_API_KEY": "${OPENAI_API_KEY}"
  }
}
```

### Viewing Secrets

To safely view your stored secrets, use this script:

```bash
#!/bin/bash

# Function to safely display a secret value
display_secret() {
  local secret_name=$1
  local secret_value=$2
  local visible_chars=4
  
  if [ -z "$secret_value" ]; then
    echo "❌ $secret_name is not set"
    return
  fi
  
  local length=${#secret_value}
  local first_chars=${secret_value:0:$visible_chars}
  local masked_length=$((length - visible_chars))
  local masked_chars=$(printf '%*s' $masked_length | tr ' ' '*')
  
  echo "✅ $secret_name is set"
  echo "   Value: $first_chars$masked_chars ($length characters total)"
}

# Get the secrets from GNOME Keyring
github_pat=$(secret-tool lookup service github-mcp username el_mango)
brave_api_key=$(secret-tool lookup service brave-mcp username el_mango)

echo "Secrets stored in GNOME Keyring:"
echo "==============================="
display_secret "GITHUB_PAT" "$github_pat"
display_secret "BRAVE_API_KEY" "$brave_api_key"
```

Save this as `check-secrets.sh` and make it executable.

### Updating Secrets

To update an existing secret, simply store it again with the same parameters:

```bash
secret-tool store --label="GitHub PAT for Windsurf" service github-mcp username el_mango
```

Enter the new value when prompted.

### Deleting Secrets

To delete a secret from GNOME Keyring:

```bash
secret-tool clear service github-mcp username el_mango
```

## Testing and Validation

### Test Script Method

Create a test script to verify your environment variables:

```bash
#!/bin/bash

# Source the environment variables from our start script
source <(grep "export GITHUB_PAT\|export BRAVE_API_KEY" ~/.codeium/windsurf/start-windsurf.sh)

# Check if the variables are set
echo "Testing if environment variables are properly set:"
echo ""

if [ -n "$GITHUB_PAT" ]; then
  echo "✅ GITHUB_PAT is set"
  echo "   Value starts with: ${GITHUB_PAT:0:4}..."
else
  echo "❌ GITHUB_PAT is NOT set"
fi

if [ -n "$BRAVE_API_KEY" ]; then
  echo "✅ BRAVE_API_KEY is set"
  echo "   Value starts with: ${BRAVE_API_KEY:0:4}..."
else
  echo "❌ BRAVE_API_KEY is NOT set"
fi
```

Save this as `test-mcp-env.sh` and make it executable.

### Windsurf Developer Console Method

To verify that Windsurf can access your environment variables:

1. Launch Windsurf using your startup script
2. Open Developer Tools (Ctrl+Shift+I)
3. In the Console tab, run:

```javascript
console.log('GITHUB_PAT:', process.env.GITHUB_PAT ? 'Set (starts with ' + process.env.GITHUB_PAT.substring(0, 4) + '...)' : 'NOT set');
console.log('BRAVE_API_KEY:', process.env.BRAVE_API_KEY ? 'Set (starts with ' + process.env.BRAVE_API_KEY.substring(0, 4) + '...)' : 'NOT set');
```

## Troubleshooting

If your secrets aren't loading correctly:

1. Verify that GNOME Keyring is running:
   ```bash
   ps aux | grep gnome-keyring-daemon
   ```

2. Check if your secrets are stored correctly:
   ```bash
   ./check-secrets.sh
   ```

3. Ensure your startup script has the correct paths:
   ```bash
   which secret-tool
   which windsurf
   ```

## Utility Scripts

All the scripts mentioned in this guide:

1. `start-windsurf.sh` - Loads secrets and starts Windsurf
2. `check-secrets.sh` - Safely displays stored secrets
3. `test-mcp-env.sh` - Tests if environment variables are set correctly

These scripts can be found in the `scripts` directory of this repository.
