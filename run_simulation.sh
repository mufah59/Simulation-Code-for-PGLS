#!/bin/bash

##########################################################
# GATE PET Simulation Runner
# Interactive script to select simulation type and phantom
##########################################################

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    GATE PET Simulation Configuration${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

##########################################################
# Step 1: Choose Visualization or Production Mode
##########################################################
echo -e "${GREEN}Step 1: Select Simulation Mode${NC}"
echo "1) Production (main.mac)"
echo "2) Visualization (main_visu.mac)"
echo ""
read -p "Enter your choice (1 or 2): " mode_choice

if [ "$mode_choice" == "1" ]; then
  MODE="production"
  MAIN_MAC="main.mac"
  echo -e "${YELLOW}Selected: Production Mode${NC}"
elif [ "$mode_choice" == "2" ]; then
  MODE="visualization"
  MAIN_MAC="main_visu.mac"
  echo -e "${YELLOW}Selected: Visualization Mode${NC}"
else
  echo -e "${RED}Invalid choice. Exiting.${NC}"
  exit 1
fi

echo ""

##########################################################
# Step 2: Choose Phantom/Source Configuration
##########################################################
echo -e "${GREEN}Step 2: Select Phantom and Source${NC}"
echo "1) Sensitivity Test - 70cm Line Source"
echo "2) Sensitivity Test - 200cm Extended Line Source"
echo "3) Count Rate Test - 70cm Scatter Phantom"
echo "4) Count Rate Test - 175cm Extended Scatter Phantom"
echo "5) Spatial Resolution - Point Sources"
echo "6) Mini-Derenzo Phantom"
echo "7) NEMA IEC Image Quality Phantom"
echo "8) Custom (specify your own phantom/source files)"
echo ""
read -p "Enter your choice (1-8): " phantom_choice

case $phantom_choice in
1)
  PHANTOM="mac/phantom_sensitivity_70cm.mac"
  SOURCE="mac/source_sensitivity_70cm.mac"
  TEST_NAME="Sensitivity_70cm"
  echo -e "${YELLOW}Selected: 70cm Sensitivity Test${NC}"
  ;;
2)
  PHANTOM="mac/phantom_sensitivity_200cm.mac"
  SOURCE="mac/source_sensitivity_200cm.mac"
  TEST_NAME="Sensitivity_200cm"
  echo -e "${YELLOW}Selected: 200cm Extended Sensitivity Test${NC}"
  ;;
3)
  PHANTOM="mac/phantom_necr_70cm.mac"
  SOURCE="mac/source_necr_70cm.mac"
  TEST_NAME="Count_Rate_70cm"
  echo -e "${YELLOW}Selected: 70cm Count Rate Test${NC}"
  ;;
4)
  PHANTOM="mac/phantom_necr_175cm.mac"
  SOURCE="mac/source_necr_175cm.mac"
  TEST_NAME="Count_Rate_175cm"
  echo -e "${YELLOW}Selected: 175cm Extended Count Rate Test${NC}"
  ;;
5)
  PHANTOM="none"
  SOURCE="mac/source_spatial_resolution.mac"
  TEST_NAME="Spatial_Resolution"
  echo -e "${YELLOW}Selected: Spatial Resolution Test (Point Sources)${NC}"
  ;;
6)
  PHANTOM="mac/phantom_mini_derenzo.mac"
  SOURCE="mac/source_mini_derenzo.mac"
  TEST_NAME="Mini_Derenzo"
  echo -e "${YELLOW}Selected: Mini-Derenzo Phantom${NC}"
  ;;
7)
  PHANTOM="mac/phantom_nema_iec.mac"
  SOURCE="mac/source_nema_iec.mac"
  TEST_NAME="NEMA_IEC"
  echo -e "${YELLOW}Selected: NEMA IEC Image Quality Phantom${NC}"
  ;;
8)
  read -p "Enter phantom file path (or 'none'): " PHANTOM
  read -p "Enter source file path: " SOURCE
  read -p "Enter test name: " TEST_NAME
  echo -e "${YELLOW}Selected: Custom Configuration${NC}"
  ;;
*)
  echo -e "${RED}Invalid choice. Exiting.${NC}"
  exit 1
  ;;
esac

echo ""

##########################################################
# Step 3: Create temporary main.mac with selected phantom/source
##########################################################
echo -e "${GREEN}Step 3: Preparing Simulation Configuration${NC}"

# Create organized output directory structure
# Format: output/TestName/Mode/run_001_YYYY-MM-DD_HH-MM-SS/
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BASE_DIR="output/${TEST_NAME}/${MODE}"

# Find the next run number
RUN_NUM=1
if [ -d "${BASE_DIR}" ]; then
  # Get the highest run number
  LAST_RUN=$(ls -d ${BASE_DIR}/run_* 2>/dev/null | sed 's/.*run_//' | sed 's/_.*//' | sort -n | tail -1)
  if [ ! -z "$LAST_RUN" ]; then
    RUN_NUM=$((LAST_RUN + 1))
  fi
fi # Format run number with leading zeros (e.g., 001, 002, ...)
RUN_NUM_FORMATTED=$(printf "%03d" $RUN_NUM)

# Create the run directory
RUN_DIR="${BASE_DIR}/run_${RUN_NUM_FORMATTED}_${TIMESTAMP}"
mkdir -p ${RUN_DIR}

# Create TWO temporary files: one for phantom, one for source
# This is necessary because phantom must be loaded BEFORE /gate/run/initialize
# and source must be loaded AFTER /gate/run/initialize

PHANTOM_CONFIG_MAC="mac/phantom_config_temp.mac"
SOURCE_CONFIG_MAC="mac/source_config_temp.mac"

# Create phantom config file
cat >${PHANTOM_CONFIG_MAC} <<EOF
##########################################################
# Auto-generated Phantom Configuration
# Test: ${TEST_NAME}
# Generated: ${TIMESTAMP}
##########################################################
EOF

if [ "$PHANTOM" != "none" ]; then
  echo "/control/execute ${PHANTOM}" >>${PHANTOM_CONFIG_MAC}
fi

# Create source config file
cat >${SOURCE_CONFIG_MAC} <<EOF
##########################################################
# Auto-generated Source Configuration
# Test: ${TEST_NAME}
# Generated: ${TIMESTAMP}
##########################################################
/control/execute ${SOURCE}
EOF

# Copy the existing main.mac file to run directory and modify it
TEMP_MAC="${RUN_DIR}/main_run.mac"
cp ${MAIN_MAC} ${TEMP_MAC}

echo -e "${BLUE}Modifying ${MAIN_MAC} to use selected phantom and source${NC}"

# Now modify the copied main.mac to include our phantom/source config
# Replace the phantom line (before initialization) and source line (after initialization)
if [ "$MODE" == "visualization" ]; then
  # For visualization, replace the cylindrical_phantom.mac line with phantom config
  sed -i "s|/control/execute mac/cylindrical_phantom.mac|/control/execute mac/phantom_config_temp.mac|g" ${TEMP_MAC}
  # Replace sources_visu.mac line with source config
  sed -i "s|/control/execute mac/sources_visu.mac|/control/execute mac/source_config_temp.mac|g" ${TEMP_MAC}
else
  # For production, replace the cylindrical_phantom.mac line with phantom config
  sed -i "s|/control/execute mac/cylindrical_phantom.mac|/control/execute mac/phantom_config_temp.mac|g" ${TEMP_MAC}
  # Replace sources.mac line with source config
  sed -i "s|/control/execute mac/sources.mac|/control/execute mac/source_config_temp.mac|g" ${TEMP_MAC}
fi

echo ""

##########################################################
# Step 4: Display Summary and Confirm
##########################################################
echo -e "${GREEN}Step 4: Simulation Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Mode:          ${YELLOW}${MODE}${NC}"
echo -e "Test Name:     ${YELLOW}${TEST_NAME}${NC}"
echo -e "Phantom File:  ${YELLOW}${PHANTOM}${NC}"
echo -e "Source File:   ${YELLOW}${SOURCE}${NC}"
echo -e "Main File:     ${YELLOW}${TEMP_MAC}${NC}"
echo -e "Output Dir:    ${YELLOW}${RUN_DIR}${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

read -p "Do you want to start the simulation? (y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo -e "${RED}Simulation cancelled.${NC}"
  exit 0
fi

##########################################################
# Step 5: Run GATE Simulation
##########################################################
echo ""
echo -e "${GREEN}Starting GATE Simulation...${NC}"
echo ""

# Run GATE from the main directory (so relative paths work)
if [ "$MODE" == "visualization" ]; then
  Gate ${TEMP_MAC}
else
  Gate ${TEMP_MAC}
fi

# Move output files to run directory
mv output/*.root ${RUN_DIR}/ 2>/dev/null || true
mv output/*.dat ${RUN_DIR}/ 2>/dev/null || true
mv output/*.txt ${RUN_DIR}/ 2>/dev/null || true

# Clean up temporary phantom and source config files
rm -f ${PHANTOM_CONFIG_MAC}
rm -f ${SOURCE_CONFIG_MAC}

echo ""
echo -e "${GREEN}Simulation Complete!${NC}"
echo -e "Output saved in: ${YELLOW}${RUN_DIR}${NC}"
echo ""
