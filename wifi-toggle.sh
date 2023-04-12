#!/bin/bash

# Define variables
PLIST_FILE="com.wifi-toggle.plist"
PLIST_PATH="/Library/LaunchDaemons/$PLIST_FILE"
DAEMON_NAME="wifi-toggle"
LOG_FILE="/var/log/wifi-toggle/wifi-toggle.log"


# Create the LaunchDaemon plist file
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Label</key>
<string>com.${DAEMON_NAME}</string>
<key>ProgramArguments</key>
<array>
<string>/usr/local/bin/wifi-toggle.sh</string>
</array>
<key>RunAtLoad</key>
<true/>
<key>WatchPaths</key>
<array>
<string>/var/tmp/ethernet_status.txt</string>
</array>
<key>KeepAlive</key>
<true/>
<key>UserName</key>
<string>root</string>
<key>StandardOutPath</key>
<string>/var/log/wifi-toggle/wifi-toggle.out.log</string>
<key>StandardErrorPath</key>
<string>/var/log/wifi-toggle/wifi-toggle.err.log</string>
</dict>
</plist>
EOF

Set the ownership and permissions on the LaunchDaemon plist file
chown root:wheel "$PLIST_PATH"
chmod 644 "$PLIST_PATH"

Load the LaunchDaemon
launchctl load "$PLIST_PATH"

####

# Create the script file
cat << EOF > /usr/local/bin/wifi-toggle.sh
#!/bin/bash

# Set toggle for found IP on an interface to FALSE to start
IPFOUND=
# Get list of possible wired ethernet interfaces
INTERFACES=\`networksetup -listnetworkserviceorder | grep "Hardware Port" | grep "Ethernet" | awk -F ": " '{print \$3}'  | sed 's/)//g'\`
INTERFACES=("\${INTERFACES[@]}" \`networksetup -listnetworkserviceorder | grep "Hardware Port" | grep "Thunderbolt Bridge" | awk -F ": " '{print \$3}'  | sed 's/)//g'\`)

# Get list of Wireless Interfaces
WIFIINTERFACES=\`networksetup -listallhardwareports | tr '
' ' ' | sed -e 's/Hardware Port:/'\$'
/g' | grep Wi-Fi | awk '{print \$3}'\`

# Look for an IP on all Ethernet interfaces.  If found set variable IPFOUND to true.
for INTERFACE in \$INTERFACES
do
  # Get Wired LAN IP (If there is one other then the loopback and the self assigned.)
  IPCHECK=\`ifconfig \$INTERFACE | egrep 'inet [0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}' | egrep -v '127.0.0.1|169.254.' | awk '{print \$2}'\`
  if [ \$IPCHECK ]; then
    IPFOUND=true
  fi
done

if [ \$IPFOUND ]; then
  /usr/sbin/networksetup -setairportpower \$WIFIINTERFACES off || exit 1
  echo "Turning OFF wireless on card \$WIFIINTERFACES."
  echo "$(date): Turning OFF wireless on card $WIFIINTERFACES." >> "$LOG_FILE"
else
  /usr/sbin/networksetup -setairportpower \$WIFIINTERFACES on || exit 1
  echo "Turning ON wireless on card \$WIFIINTERFACES."
  echo "$(date): Turning ON wireless on card $WIFIINTERFACES." >> "$LOG_FILE"
fi
EOF

# Make the script executable
chmod +x /usr/local/bin/wifi-toggle.sh

# Load the LaunchDaemon
launchctl load /Library/LaunchDaemons/${PLIST_FILE}

# Start the LaunchDaemon
launchctl start ${DAEMON_NAME}