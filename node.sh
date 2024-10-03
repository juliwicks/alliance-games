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
echo -e "${BANNER}               Alliance Games Docker Setup Script v1.0                   ${NC}"
echo -e "${BANNER}                            by Node Farmer                               ${NC}"
echo -e "${BANNER}=========================================================================${NC}"

# Function to ensure a non-empty value
get_non_empty_input() {
    local prompt="$1"
    local input=""
    while [ -z "$input" ]; do
        read -p "$prompt" input
        if [ -z "$input" ]; then
            echo -e "${ERROR}Error: This field cannot be empty.${NC}"
        fi
    done
    echo "$input"
}

# Function to generate a random MAC address
generate_mac_address() {
    echo "02:$(od -An -N5 -tx1 /dev/urandom | tr ' ' ':' | cut -c2-)"
}

# Function to generate a new UUID for the fake product_uuid
generate_uuid() {
    uuid=$(cat /proc/sys/kernel/random/uuid)
    echo $uuid
}

# Get the parameters with validation
device_name=$(get_non_empty_input "Enter device_name: ")
device_name_lower=$(echo "$device_name" | tr '[:upper:]' '[:lower:]')  # Create lower-case version

# Create a directory for this device's configuration
device_dir="./$device_name"
if [ ! -d "$device_dir" ]; then
    mkdir "$device_dir"
    echo -e "${INFO}Created directory for $device_name at $device_dir${NC}"
fi

# Proxy configuration
read -p "Do you want to use a proxy? (Y/N): " use_proxy

proxy_type=""
proxy_ip=""
proxy_port=""
proxy_username=""
proxy_password=""

if [[ "$use_proxy" == "Y" || "$use_proxy" == "y" ]]; then
    read -p "Enter proxy type (http/socks5): " proxy_type
    read -p "Enter proxy IP: " proxy_ip
    read -p "Enter proxy port: " proxy_port
    read -p "Enter proxy username (leave empty if not required): " proxy_username
    read -p "Enter proxy password (leave empty if not required): " proxy_password
    if [[ "$proxy_type" == "http" ]]; then
        proxy_type="http-connect"
    fi
fi

# Step 1: Create the Dockerfile
echo -e "${INFO}Creating the Dockerfile...${NC}"
cat << 'EOL' > "$device_dir/Dockerfile"
FROM ubuntu:latest
WORKDIR /app
RUN apt-get update && apt-get install -y bash curl jq make gcc bzip2 lbzip2 vim git lz4 telnet build-essential net-tools wget tcpdump systemd dbus redsocks iptables iproute2 nano
RUN curl -L https://github.com/Impa-Ventures/coa-launch-binaries/raw/main/linux/amd64/compute/launcher -o launcher && \
    curl -L https://github.com/Impa-Ventures/coa-launch-binaries/raw/main/linux/amd64/compute/worker -o worker
RUN chmod +x ./launcher && chmod +x ./worker
EOL

if [[ "$use_proxy" == "Y" || "$use_proxy" == "y" ]]; then
    cat <<EOL >> "$device_dir/Dockerfile"
COPY redsocks.conf /etc/redsocks.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOL
fi

cat <<EOL >> "$device_dir/Dockerfile"
CMD ["/bin/bash", "-c", "exec /bin/bash"]
EOL

# Create the redsocks configuration file only if proxy is used
if [[ "$use_proxy" == "Y" || "$use_proxy" == "y" ]]; then
    cat <<EOL > "$device_dir/redsocks.conf"
base {
    log_debug = off;
    log_info = on;
    log = "file:/var/log/redsocks.log";
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 12345;
    ip = $proxy_ip;
    port = $proxy_port;
    type = $proxy_type;
EOL

    # Append login and password if provided
    if [[ -n "$proxy_username" ]]; then
        cat <<EOL >> "$device_dir/redsocks.conf"
    login = "$proxy_username";
EOL
    fi

    if [[ -n "$proxy_password" ]]; then
        cat <<EOL >> "$device_dir/redsocks.conf"
    password = "$proxy_password";
EOL
    fi

    cat <<EOL >> "$device_dir/redsocks.conf"
}
EOL

    # Create the entrypoint script
    cat <<EOL > "$device_dir/entrypoint.sh"
#!/bin/sh

echo "Starting redsocks..."
redsocks -c /etc/redsocks.conf &
echo "Redsocks started."

# Give redsocks some time to start
sleep 5

echo "Configuring iptables..."
# Configure iptables to redirect HTTP and HTTPS traffic through redsocks
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 12345
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 12345
echo "Iptables configured."

# Execute the user's command
echo "Executing user command..."
exec "\$@"
EOL
fi

# Step 4: Generate a fake product_uuid and store it in a file inside the device directory
fake_product_uuid_file="$device_dir/fake_uuid.txt"
if [ ! -f "$fake_product_uuid_file" ]; then
    generated_uuid=$(generate_uuid)
    echo "$generated_uuid" > "$fake_product_uuid_file"
fi

# Ask the user for the custom command to run at startup
custom_command=$(get_non_empty_input "Enter the command to run on startup: ")

# Create an autorun script that will execute the custom command
autorun_script="$device_dir/autorun.sh"
cat <<EOL > "$autorun_script"
#!/bin/bash
# Wait for a short period before running the Docker commands
sleep 5
# Start the Docker container
echo "Starting Docker container: $device_name"
docker start "$device_name_lower"
# Execute a shell inside the Docker container
docker exec -it "$device_name_lower" /bin/bash
# Wait for the Docker commands to finish before executing the custom command
sleep 2
# Execute the user-provided command
echo "Executing startup command: $custom_command"
$custom_command
EOL

# Make the autorun script executable
chmod +x "$autorun_script"

# Add the autorun script to the Dockerfile
cat <<EOL >> "$device_dir/Dockerfile"
COPY autorun.sh /usr/local/bin/autorun.sh
RUN chmod +x /usr/local/bin/autorun.sh
ENTRYPOINT ["/usr/local/bin/autorun.sh"]
EOL

# Step 5: Run the Docker build and create the container
echo -e "${INFO}Building Docker image...${NC}"
docker build -t "$device_name_lower" "$device_dir"

# Run the Docker container
echo -e "${INFO}Running Docker container...${NC}"
docker run -d --name "$device_name_lower" --privileged --network host -v "$fake_product_uuid_file:/sys/class/dmi/id/product_uuid" "$device_name_lower"

echo -e "${SUCCESS}Setup complete. The Docker container is now running with the autorun script configured.${NC}"
