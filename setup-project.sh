#!/usr/bin/env bash

# setup-devcontainer.sh
# Usage: ./setup-devcontainer.sh --name myproject --temp-ext angular tailwindcss dotnet --verbose

set -e

# Default values
CONTAINER_NAME="custom-devcontainer"
TEMP_EXT=()
VERBOSE=false
CLEAN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    --temp-ext)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        TEMP_EXT+=("$1")
        shift
      done
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    *)
      echo "❌ Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Clean previous setup
if $CLEAN; then
  rm -rf .devcontainer .vscode
  echo "🧹 Cleaned previous setup"
fi

if [[ ${#TEMP_EXT[@]} -eq 0 ]]; then
  echo "❌ Please provide at least one value for --temp-ext"
  exit 1
fi

# Base GitHub raw URL
BASE_URL="https://raw.githubusercontent.com/hstha/config/main"
VSCODE_URL="${BASE_URL}/.vscode"

# Core extensions
CORE_EXTENSIONS=(
  "streetsidesoftware.code-spell-checker"
  "github.copilot"
  "github.copilot-chat"
  "donjayamanne.githistory"
  "eamodio.gitlens"
  "vscode-icons-team.vscode-icons"
  "gruntfuggly.todo-tree"
)

# Frontend extensions
FRONTEND_EXTENSIONS=(
  "dbaeumer.vscode-eslint"
  "esbenp.prettier-vscode"
)

# Function to map tech to extensions
get_extensions_for() {
  case "$1" in
    angular) echo "ms-vscode.vscode-typescript-next angular.ng-template";;
    tailwindcss) echo "bradlc.vscode-tailwindcss";;
    springboot) echo "vscjava.vscode-java-pack pivotal.vscode-spring-boot redhat.java";;
    react) echo "ms-vscode.vscode-typescript-next";;
    vue) echo "vue.volar";;
    node) echo "ms-vscode.node-debug2";;
    python) echo "ms-python.python ms-toolsai.jupyter";;
    dotnet) echo "ms-dotnettools.csharp ms-dotnettools.csdevkit ms-vscode.vscode-dotnet-pack formulahendry.dotnet-test-explorer jmrog.vscode-nuget-package-manager ms-dotnettools.razor";;
    java) echo "vscjava.vscode-java-pack" "redhat.java" "vscjava.vscode-maven" "pivotal.vscode-spring-boot" "visualstudioexptteam.vscodeintellicode";;
    csharp) echo "ms-dotnettools.csharp" "ms-dotnettools.csdevkit" "formulahendry.dotnet-test-explorer" "jmrog.vscode-nuget-package-manager";;
    *) echo ""; echo "⚠️ Warning: Unknown temp-ext '$1' — skipping";;
  esac
}

# Detect frontend tech
IS_FRONTEND=false
for ext in "${TEMP_EXT[@]}"; do
  case "$ext" in
    angular|react|vue|tailwindcss)
      IS_FRONTEND=true
      break
      ;;
  esac
done

# Collect extensions
EXTENSIONS=("${CORE_EXTENSIONS[@]}")
if $IS_FRONTEND; then
  EXTENSIONS+=("${FRONTEND_EXTENSIONS[@]}")
fi

for ext in "${TEMP_EXT[@]}"; do
  EXT_LIST=$(get_extensions_for "$ext")
  for e in $EXT_LIST; do
    EXTENSIONS+=("$e")
  done
done

# Create devcontainer folder
mkdir -p .devcontainer
curl -sSL "${BASE_URL}/Dockerfile" -o .devcontainer/Dockerfile
$VERBOSE && echo "📦 Dockerfile downloaded"

# Generate devcontainer.json
cat > .devcontainer/devcontainer.json <<EOF
{
  "name": "${CONTAINER_NAME}",
  "build": {
    "dockerfile": "Dockerfile",
    "context": "."
  },
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.shell.linux": "/bin/bash"
      },
      "extensions": [
        $(printf '"%s",\n' "${EXTENSIONS[@]}" | sed '$ s/,$//')
      ]
    }
  },
  "postCreateCommand": "echo '🚀 Devcontainer ready with: core + ${TEMP_EXT[*]}'"
}
EOF
$VERBOSE && echo "🛠 devcontainer.json created"

# Pull VS Code settings
mkdir -p .vscode
curl -sSL "${VSCODE_URL}/settings.json" -o .vscode/settings.json
curl -sSL "${VSCODE_URL}/launch.json" -o .vscode/launch.json
$VERBOSE && echo "⚙️ VS Code settings downloaded"

# Copy starter templates
for ext in "${TEMP_EXT[@]}"; do
  TEMPLATE_DIR="templates/${ext}"
  if [[ -d "$TEMPLATE_DIR" ]]; then
    cp -r "$TEMPLATE_DIR/"* .
    $VERBOSE && echo "📁 Starter files copied from $TEMPLATE_DIR"
  fi
done

echo "✅ Devcontainer \"${CONTAINER_NAME}\" created with core + ${TEMP_EXT[*]} extensions"
