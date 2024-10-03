#!/bin/bash

# Define the location of the autorun script and systemd service file
autorun_script="/usr/local/bin/docker_autorun.sh"
service_file="/etc/systemd/system/docker_autorun.service"

# Prompt for device name and custom run script
read -p "Enter device name: " device_name
read -p "Enter custom run script to execute: " custom_run_script

# Create the autorun script that will be executed on startup
cat <<EOL > "$autorun_script"
#!/bin/bash

# Start the Docker container and execute the custom command
docker start "$device_name" && docker exec -it "$device_name" /bin/bash -c "sleep 2 && echo '$custom_run_script' && $custom_run_script"
EOL

# Make the autorun script executable
chmod +x "$autorun_script"

# Create the systemd service file
cat <<EOL > "$service_file"
[Unit]
Description=Docker Autorun Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=$autorun_script
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# Reload the systemd daemon to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start on boot
sudo systemctl enable docker_autorun.service

echo "Autorun script created at $autorun_script"
echo "Systemd service created at $service_file"
echo "The service has been enabled to run on startup."
