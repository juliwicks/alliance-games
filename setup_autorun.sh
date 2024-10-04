#!/bin/bash

# Define color codes
INFO='\033[0;36m'  # Cyan
BANNER='\033[0;35m' # Magenta
WARNING='\033[0;33m'
ERROR='\033[0;31m'
SUCCESS='\033[0;32m'
NC='\033[0m' # No Color

# Display banner
echo -e "${BANNER}=========================================================================${NC}"
echo -e "${BANNER}           _ _ _                         _____                           ${NC}"
echo -e "${BANNER}     /\\   | | (_)                       / ____|                          ${NC}"
echo -e "${BANNER}    /  \\  | | |_  __ _ _ __   ___ ___  | |  __  __ _ _ __ ___   ___  ___ ${NC}"
echo -e "${BANNER}   / /\\ \\ | | | |/ _\` | '_ \\ / __/ _ \\ | | |_ |/ _\` | '_ \` _ \\ / _ \\/ __|${NC}"
echo -e "${BANNER}  / ____ \\| | | | (_| | | | | (_|  __/ | |__| | (_| | | | | | |  __/\\__ \\ ${NC}"
echo -e "${BANNER} /_/    \\_\\_|_|_|\\__,_|_| |_|\\___\\___|  \\_____|\\__,_|_| |_| |_|\\___||___/${NC}"
echo -e "${BANNER}                                                                         ${NC}"
echo -e "${BANNER}                            Setup_Autorun.sh                             ${NC}"
echo -e "${BANNER}                          by Nodebot (Juliwicks)                         ${NC}"
echo -e "${BANNER}=========================================================================${NC}"

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please run with sudo."
    exit 1
fi

# Define the location of the autorun script and systemd service file
autorun_script="/usr/local/bin/docker_autorun.sh"
service_file="/etc/systemd/system/docker_autorun.service"

# Prompt for device name and custom run script
read -p "Enter device name: " device_name
read -p "Enter custom run script to execute: " custom_run_script

# Create a unique autorun script for the specific device
unique_autorun_script="/usr/local/bin/docker_autorun_${device_name}.sh"
cat <<EOL | tee "$unique_autorun_script" > /dev/null
#!/bin/bash

# Start the Docker container and execute the custom command
docker start "$device_name" && docker exec "$device_name" /bin/bash -c "sleep 2 && echo '$custom_run_script' && $custom_run_script"
EOL

# Make the unique autorun script executable
chmod +x "$unique_autorun_script"

# Create a unique systemd service file
unique_service_file="/etc/systemd/system/docker_autorun_${device_name}.service"
cat <<EOL | tee "$unique_service_file" > /dev/null
[Unit]
Description=Docker Autorun Service for $device_name
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=$unique_autorun_script
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# Reload the systemd daemon to recognize the new service
systemctl daemon-reload

# Enable the unique service to start on boot
systemctl enable "docker_autorun_${device_name}.service"

echo -e "${WARNING}Autorun script created at $unique_autorun_script${NC}"
echo -e "${WARNING}Systemd service created at $unique_service_file${NC}"
echo -e "${SUCCESS}The service has been enabled to run on startup.${NC}"
