#!/bin/bash

# Navigate to the app directory
cd /app || exit

# Prompt the user for the command to autorun
echo "Please enter the command you want to autorun on reboot:"
read -r command_input

# Create a script for the command
echo "#!/bin/bash" > /app/autorun_command.sh
echo "$command_input" >> /app/autorun_command.sh

# Make the script executable
chmod +x /app/autorun_command.sh

# Create a service file to run the script on reboot
cat <<EOF > /etc/systemd/system/autorun.service
[Unit]
Description=Autorun Command at Reboot

[Service]
ExecStart=/app/autorun_command.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload the systemd daemon to apply the new service
systemctl daemon-reload

# Enable the service so it runs on startup
systemctl enable autorun.service

echo "The command has been set to autorun on reboot!"
