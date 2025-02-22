 #!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Cleaning build artifacts...${NC}"

# Clean terraform build artifacts
rm -rf dist/
mkdir -p dist/

# Clean .NET build artifacts
echo "Cleaning .NET build artifacts..."
find ../API -type d \( \
    -name "bin" -o \
    -name "obj" -o \
    -name "publish" \
    \) -exec rm -rf {} +

# Clean test artifacts
find ../Tests -type d \( \
    -name "bin" -o \
    -name "obj" \
    \) -exec rm -rf {} +

# Verify cleanup
echo -e "${GREEN}Cleaned directories:${NC}"
echo "- Removed bin/ directories"
echo "- Removed obj/ directories"
echo "- Removed publish/ directories"
echo "- Removed dist/ directory"
echo "- Removed .terraform/ directory"

echo -e "${GREEN}✅ Cleanup complete${NC}"