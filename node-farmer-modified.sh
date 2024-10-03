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

# Include auto_start.sh in the Dockerfile
cat <<EOL >> "$device_dir/Dockerfile"
COPY auto_start.sh /app/auto_start.sh
RUN chmod +x /app/auto_start.sh
CMD ["/bin/bash", "/app/auto_start.sh"]
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

# Step 2: Create the auto_start.sh script
echo -e "${INFO}Creating auto_start.sh script...${NC}"
cat << 'EOL' > "$device_dir/auto_start.sh"
#!/bin/bash

# Prompt the user for the command to autorun
echo "Please enter the command you want to autorun on container start:"
read -r command_input

# Save the command to a script
echo "#!/bin/bash" > /app/autorun_command.sh
echo "$command_input" >> /app/autorun_command.sh

# Make the autorun command script executable
chmod +x /app/autorun_command.sh

# Run the command
echo "Running the saved command..."
/app/autorun_command.sh

# Exit the script to prevent staying in the interactive shell
exit 0
EOL

# Step 4: Generate a fake product_uuid and store it in a file inside the device directory
fake_product_uuid_file="$device_dir/fake_uuid.txt"
if [ ! -f "$fake_product_uuid_file" ]; then
    generated_uuid=$(generate_uuid)
    echo "$generated_uuid" > "$fake_product_uuid_file"
fi

# Step 5: Run the Docker container with the user-provided settings and mount the UUID
mac_address=$(generate_mac_address)
echo -e "${INFO}Starting Docker container...${NC}"
docker build -t "alliance_games_docker_$device_name" "$device_dir"

if [[ "$use_proxy" == "Y" || "$use_proxy" == "y" ]]; then
    docker run -it --cap-add=NET_ADMIN --mac-address="$mac_address" -v "$fake_product_uuid_file:/sys/class/dmi/id/product_uuid" --name="$device_name" "alliance_games_docker_$device_name"
else
    docker run -it --mac-address="$mac_address" -v "$fake_product_uuid_file:/sys/class/dmi/id/product_uuid" --name="$device_name" "alliance_games_docker_$device_name"
fi
