#!/usr/bin/env bash

# setup-devcontainer.sh
# Usage: ./setup-devcontainer.sh --name myproject --angular --tailwindcss --verbose

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
    --verbose)
      VERBOSE=true
      shift
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    --angular|--tailwindcss|--springboot|--react|--vue|--node|--python)
      TEMP_EXT+=("${1/--/}")
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
  echo "❌ Please provide at least one tech stack flag"
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

# Extension map
declare -A EXTENSION_MAP
EXTENSION_MAP["angular"]="ms-vscode.vscode-typescript-next angular.ng-template"
EXTENSION_MAP["tailwindcss"]="bradlc.vscode-tailwindcss"
EXTENSION_MAP["springboot"]="vscjava.vscode-java-pack pivotal.vscode-spring-boot redhat.java"
EXTENSION_MAP["react"]="ms-vscode.vscode-typescript-next"
EXTENSION_MAP["vue"]="vue.volar"
EXTENSION_MAP["node"]="ms-vscode.node-debug2"
EXTENSION_MAP["python"]="ms-python.python ms-toolsai.jupyter"

# Detect frontend tech
IS_FRONTEND=false
for ext in "${TEMP_EXT[@]}"; do
  if [[ "$ext" =~ ^(angular|react|vue|tailwindcss)$ ]]; then
    IS_FRONTEND=true
    break
  fi
done

# Collect extensions
EXTENSIONS=("${CORE_EXTENSIONS[@]}")
if $IS_FRONTEND; then
  EXTENSIONS+=("${FRONTEND_EXTENSIONS[@]}")
fi

for ext in "${TEMP_EXT[@]}"; do
  if [[ -n "${EXTENSION_MAP[$ext]}" ]]; then
    for e in ${EXTENSION_MAP[$ext]}; do
      EXTENSIONS+=("$e")
    done
  else
    echo "⚠️ Warning: Unknown tech '$ext' — skipping"
  fi
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
  "settings": {
    "terminal.integrated.shell.linux": "/bin/bash"
  },
  "extensions": [
    $(printf '"%s",\n' "${EXTENSIONS[@]}" | sed '$ s/,$//')
  ],
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
