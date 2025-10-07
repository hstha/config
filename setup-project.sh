#!/usr/bin/env bash

# setup-devcontainer.sh
# Usage: ./setup-devcontainer.sh --name myproject --temp-ext angular tailwindcss dotnet csharp java --verbose

set -euo pipefail

# Default values
CONTAINER_NAME="custom-devcontainer"
TEMP_EXT=()
VERBOSE=false
CLEAN=false

# Helper
verbose() {
  if $VERBOSE; then
    echo "$@"
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      CONTAINER_NAME="${2:-}"
      if [[ -z "$CONTAINER_NAME" ]]; then
        echo "❌ --name requires a value"
        exit 1
      fi
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

# Core extensions (one per element)
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

# Function to map tech to extensions; prints nothing on unknown but returns non-zero
get_extensions_for() {
  local tech="$1"
  case "$tech" in
    angular) printf "%s\n" "ms-vscode.vscode-typescript-next" "angular.ng-template"; return 0;;
    tailwindcss) printf "%s\n" "bradlc.vscode-tailwindcss"; return 0;;
    springboot) printf "%s\n" "vscjava.vscode-java-pack" "pivotal.vscode-spring-boot" "redhat.java"; return 0;;
    react) printf "%s\n" "ms-vscode.vscode-typescript-next"; return 0;;
    vue) printf "%s\n" "vue.volar"; return 0;;
    node) printf "%s\n" "ms-vscode.node-debug2"; return 0;;
    python) printf "%s\n" "ms-python.python" "ms-toolsai.jupyter"; return 0;;
    dotnet) printf "%s\n" "ms-dotnettools.csharp" "ms-dotnettools.csdevkit" "ms-vscode.vscode-dotnet-pack" "formulahendry.dotnet-test-explorer" "jmrog.vscode-nuget-package-manager" "ms-dotnettools.razor"; return 0;;
    csharp) printf "%s\n" "ms-dotnettools.csharp" "ms-dotnettools.csdevkit" "formulahendry.dotnet-test-explorer" "jmrog.vscode-nuget-package-manager"; return 0;;
    java) printf "%s\n" "vscjava.vscode-java-pack" "redhat.java" "vscjava.vscode-maven" "pivotal.vscode-spring-boot" "visualstudioexptteam.vscodeintellicode"; return 0;;
    *)
      # Unknown tech: emit a single warning and return non-zero
      echo "⚠️ Warning: Unknown temp-ext '$tech' — skipping" >&2
      return 1
      ;;
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

# Collect extensions into an array (preserve order)
EXTENSIONS=("${CORE_EXTENSIONS[@]}")
if $IS_FRONTEND; then
  EXTENSIONS+=("${FRONTEND_EXTENSIONS[@]}")
fi

# Add tech-specific extensions (read line-by-line to avoid word splitting)
for ext in "${TEMP_EXT[@]}"; do
  while IFS= read -r e; do
    # only add non-empty lines
    [[ -n "${e:-}" ]] && EXTENSIONS+=("$e")
  done < <(get_extensions_for "$ext" || true)
done

# Remove duplicates while preserving order
dedupe_extensions() {
  declare -A seen=()
  local out=()
  for e in "$@"; do
    if [[ -z "${seen[$e]:-}" ]]; then
      seen[$e]=1
      out+=("$e")
    fi
  done
  printf "%s\n" "${out[@]}"
}

mapfile -t EXT_UNIQUE < <(dedupe_extensions "${EXTENSIONS[@]}")

# Create devcontainer folder and download Dockerfile
mkdir -p .devcontainer
if curl -fsSL "${BASE_URL}/Dockerfile" -o .devcontainer/Dockerfile; then
  verbose "📦 Dockerfile downloaded"
else
  echo "❌ Failed to download Dockerfile from ${BASE_URL}/Dockerfile"
  exit 1
fi

# Build the extensions JSON array string safely
extensions_json="$(printf '%s\n' "${EXT_UNIQUE[@]}" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "\"%s\",", $0} END{print ""}' )"
# remove trailing comma
extensions_json="$(echo "$extensions_json" | sed 's/,$//')"

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

# Copy starter templates (if present)
for ext in "${TEMP_EXT[@]}"; do
  TEMPLATE_DIR="templates/${ext}"
  if [[ -d "$TEMPLATE_DIR" ]]; then
    cp -r "$TEMPLATE_DIR/"* .
    verbose "📁 Starter files copied from $TEMPLATE_DIR"
  fi
done

echo "✅ Devcontainer \"${CONTAINER_NAME}\" created with core + ${TEMP_EXT[*]} extensions"
