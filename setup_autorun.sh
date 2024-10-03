#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please run with sudo."
    exit 1
fi

# Function to create an autorun script and systemd service
create_autorun() {
    local device_name="$1"
    local custom_run_script="$2"
    
    # Define unique locations for each autorun script and systemd service
    local autorun_script="/usr/local/bin/docker_autorun_$device_name.sh"
    local service_file="/etc/systemd/system/docker_autorun_$device_name.service"

    # Create the autorun script that will be executed on startup
    cat <<EOL | tee "$autorun_script" > /dev/null
#!/bin/bash

# Start the Docker container and execute the custom command
docker start "$device_name" && docker exec "$device_name" /bin/bash -c "sleep 2 && echo '$custom_run_script' && $custom_run_script"
EOL

    # Make the autorun script executable
    chmod +x "$autorun_script"

    # Create the systemd service file
    cat <<EOL | tee "$service_file" > /dev/null
[Unit]
Description=Docker Autorun Service for $device_name
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=$autorun_script
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    # Enable the service to start on boot
    systemctl enable "docker_autorun_$device_name.service"

    echo "Autorun script created at $autorun_script"
    echo "Systemd service created at $service_file"
    echo "The service has been enabled to run on startup."
}

# Loop to allow multiple autorun entries
while true; do
    read -p "Enter device name (or type 'exit' to finish): " device_name
    if [[ "$device_name" == "exit" ]]; then
        break
    fi

    read -p "Enter custom run script to execute for $device_name: " custom_run_script

    # Call the function to create an autorun entry
    create_autorun "$device_name" "$custom_run_script"
done

# Reload the systemd daemon to recognize the new services
systemctl daemon-reload

echo "All autorun configurations have been set up."
