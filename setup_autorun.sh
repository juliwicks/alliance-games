#!/bin/bash

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

echo "Autorun script created at $unique_autorun_script"
echo "Systemd service created at $unique_service_file"
echo "The service has been enabled to run on startup."
