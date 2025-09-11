#!/bin/bash

# setup-project --name myproject --temp-ext angular tailwindcss

TEMP_EXT=()
CONTAINER_NAME="custom-devcontainer"

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
    *)
      echo "❌ Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ ${#TEMP_EXT[@]} -eq 0 ]]; then
  echo "❌ Please provide at least one value for --temp-ext"
  exit 1
fi

# Base GitHub raw URL
BASE_URL="https://raw.githubusercontent.com/hstha/config/main"
VSCODE_URL="${BASE_URL}/.vscode"

# Core extensions (always included)
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

# Extension sets for temp-ext values
declare -A EXTENSION_MAP
EXTENSION_MAP["angular"]="ms-vscode.vscode-typescript-next dbaeumer.vscode-eslint angular.ng-template"
EXTENSION_MAP["tailwindcss"]="bradlc.vscode-tailwindcss"
EXTENSION_MAP["springboot"]="vscjava.vscode-java-pack pivotal.vscode-spring-boot redhat.java"

# Detect if frontend tech is present
IS_FRONTEND=false
for ext in "${TEMP_EXT[@]}"; do
  if [[ "$ext" == "angular" || "$ext" == "react" || "$ext" == "vue" || "$ext" == "tailwindcss" ]]; then
    IS_FRONTEND=true
    break
  fi
done

# Collect all extensions
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
    echo "⚠️ Warning: Unknown temp-ext '$ext' — skipping"
  fi
done

# Create .devcontainer and download Dockerfile
mkdir -p .devcontainer
curl -sSL "${BASE_URL}/Dockerfile" -o .devcontainer/Dockerfile

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

# Pull .vscode settings
mkdir -p .vscode
curl -sSL "${VSCODE_URL}/settings.json" -o .vscode/settings.json
curl -sSL "${VSCODE_URL}/launch.json" -o .vscode/launch.json

echo "✅ Devcontainer \"${CONTAINER_NAME}\" created with core + ${TEMP_EXT[*]} extensions"
