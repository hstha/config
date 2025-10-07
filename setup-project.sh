#!/usr/bin/env bash

# setup-devcontainer.sh
# Usage: bash ./setup-devcontainer.sh --name myproject --temp-ext angular tailwindcss dotnet csharp java --verbose
# Notes: Run explicitly with bash (macOS default bash is 3.2 but this script avoids mapfile and associative arrays)

set -euo pipefail

# Default values
CONTAINER_NAME="custom-devcontainer"
TEMP_EXT=()
VERBOSE=false
CLEAN=false

# Helper: verbose logging
verbose() {
  if $VERBOSE; then
    echo "$@"
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      if [[ $# -lt 2 ]]; then
        echo "❌ --name requires a value"
        exit 1
      fi
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

# Map tech token to extension list (one per line output)
get_extensions_for() {
  tech="$1"
  case "$tech" in
    angular)
      printf "%s\n" "ms-vscode.vscode-typescript-next" "angular.ng-template"
      return 0
      ;;
    tailwindcss)
      printf "%s\n" "bradlc.vscode-tailwindcss"
      return 0
      ;;
    springboot)
      printf "%s\n" "vscjava.vscode-java-pack" "pivotal.vscode-spring-boot" "redhat.java"
      return 0
      ;;
    react)
      printf "%s\n" "ms-vscode.vscode-typescript-next"
      return 0
      ;;
    vue)
      printf "%s\n" "vue.volar"
      return 0
      ;;
    node)
      printf "%s\n" "ms-vscode.node-debug2"
      return 0
      ;;
    python)
      printf "%s\n" "ms-python.python" "ms-toolsai.jupyter"
      return 0
      ;;
    dotnet)
      printf "%s\n" "ms-dotnettools.csharp" "ms-dotnettools.csdevkit" "ms-vscode.vscode-dotnet-pack" "formulahendry.dotnet-test-explorer" "jmrog.vscode-nuget-package-manager" "ms-dotnettools.razor"
      return 0
      ;;
    csharp)
      printf "%s\n" "ms-dotnettools.csharp" "ms-dotnettools.csdevkit" "formulahendry.dotnet-test-explorer" "jmrog.vscode-nuget-package-manager"
      return 0
      ;;
    java)
      printf "%s\n" "vscjava.vscode-java-pack" "redhat.java" "vscjava.vscode-maven" "pivotal.vscode-spring-boot" "visualstudioexptteam.vscodeintellicode"
      return 0
      ;;
    *)
      # Unknown token: single warning and skip
      echo "⚠️ Warning: Unknown temp-ext '$tech' — skipping" >&2
      return 1
      ;;
  esac
}

# Detect whether any frontend tech is requested
IS_FRONTEND=false
for ext in "${TEMP_EXT[@]}"; do
  case "$ext" in
    angular|react|vue|tailwindcss)
      IS_FRONTEND=true
      break
      ;;
  esac
done

# Collect extensions preserving order
EXTENSIONS=("${CORE_EXTENSIONS[@]}")
if $IS_FRONTEND; then
  EXTENSIONS+=("${FRONTEND_EXTENSIONS[@]}")
fi

for ext in "${TEMP_EXT[@]}"; do
  # read each line emitted by get_extensions_for and append to EXTENSIONS
  if get_extensions_for "$ext" >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -n "${line:-}" ]] && EXTENSIONS+=("$line")
    done < <(get_extensions_for "$ext")
  else
    # the function already printed a warning to stderr; continue
    true
  fi
done

# Remove duplicates while preserving order (portable)
EXT_UNIQUE=()
for e in "${EXTENSIONS[@]}"; do
  skip=false
  for u in "${EXT_UNIQUE[@]}"; do
    if [[ "$e" == "$u" ]]; then
      skip=true
      break
    fi
  done
  if ! $skip; then
    EXT_UNIQUE+=("$e")
  fi
done

# Create .devcontainer and download Dockerfile (fail on error)
mkdir -p .devcontainer
if curl -fsSL "${BASE_URL}/Dockerfile" -o .devcontainer/Dockerfile; then
  verbose "📦 Dockerfile downloaded"
else
  echo "❌ Failed to download Dockerfile from ${BASE_URL}/Dockerfile"
  exit 1
fi

# Build extensions JSON array safely without mapfile/associative arrays
extensions_json=""
first=true
for ext in "${EXT_UNIQUE[@]}"; do
  # escape backslashes and quotes
  esc="$(printf '%s' "$ext" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  if $first; then
    extensions_json="\"${esc}\""
    first=false
  else
    extensions_json+=",\"${esc}\""
  fi
done

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
        ${extensions_json}
      ]
    }
  },
  "postCreateCommand": "echo '🚀 Devcontainer ready with: core + ${TEMP_EXT[*]}'"
}
EOF
verbose "🛠 devcontainer.json created"

# Pull VS Code settings (best-effort)
mkdir -p .vscode
if curl -fsSL "${VSCODE_URL}/settings.json" -o .vscode/settings.json; then
  verbose "⚙️ VS Code settings.json downloaded"
else
  verbose "⚠️ Could not download settings.json from ${VSCODE_URL}/settings.json"
fi

if curl -fsSL "${VSCODE_URL}/launch.json" -o .vscode/launch.json; then
  verbose "⚙️ VS Code launch.json downloaded"
else
  verbose "⚠️ Could not download launch.json from ${VSCODE_URL}/launch.json"
fi

# Copy starter templates if present
for ext in "${TEMP_EXT[@]}"; do
  TEMPLATE_DIR="templates/${ext}"
  if [[ -d "$TEMPLATE_DIR" ]]; then
    cp -r "${TEMPLATE_DIR}/"* .
    verbose "📁 Starter files copied from $TEMPLATE_DIR"
  fi
done

echo "✅ Devcontainer \"${CONTAINER_NAME}\" created with core + ${TEMP_EXT[*]} extensions"
