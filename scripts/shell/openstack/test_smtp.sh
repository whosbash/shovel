#!/bin/sh

### Utility Functions
# Function to validate SMTP server connectivity
validate_smtp_server() {
    local server=$1
    if ping -c 1 "$server" >/dev/null 2>&1; then
        echo "SMTP server $server is reachable."
    else
        echo "Error: Unable to reach SMTP server $server. Please check the server address."
        exit 1
    fi
}

# Function to validate SMTP port
validate_smtp_port() {
    local server=$1
    local port=$2
    if nc -z "$server" "$port" >/dev/null 2>&1; then
        echo "SMTP port $port is open on $server."
    else
        echo "Error: SMTP port $port is not reachable on $server. Please check the port."
        exit 1
    fi
}

# Function to send a test email using swaks
test_smtp() {
    local from_email=$1
    local to_email=$2
    local server=$3
    local port=$4
    local user=$5
    local pass=$6
    local subject=$7
    local body=$8

    echo "Sending test email..."

    swaks \
        --to "$to_email" \
        --from "$from_email" \
        --server "$server" \
        --port "$port" \
        --auth LOGIN --auth-user "$user" \
        --auth-password "$pass" \
        --tls \
        --header "Subject: $subject" \
        --header "Content-Type: text/html; charset=UTF-8" \
        --data "Content-Type: text/html; charset=UTF-8\n\n$body" > /dev/null

    if [ $? -eq 0 ]; then
        echo "Test email sent successfully."
    else
        echo "Error: Failed to send test email. Check your SMTP configuration."
        exit 1
    fi
}

### Configuration Section
MESSAGE_BODY="<html>
<head>
  <style>
    body {
      font-family: Arial, sans-serif;
      background-color: #f4f4f9;
      margin: 0;
      padding: 0;
      color: #333333;
    }
    .container {
      margin: 20px auto;
      padding: 20px;
      max-width: 600px;
      background-color: #ffffff;
      border-radius: 8px;
      box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
    }
    .header {
      text-align: center;
      padding-bottom: 10px;
      border-bottom: 2px solid #4caf50;
    }
    .header img {
      max-width: 100px;
    }
    h1 {
      color: #4caf50;
      margin: 20px 0;
    }
    p {
      color: #555555;
      line-height: 1.6;
      margin: 10px 0;
    }
    .button {
      display: inline-block;
      margin: 20px 0;
      padding: 10px 20px;
      background-color: #4caf50;
      color: #ffffff;
      text-decoration: none;
      border-radius: 5px;
      font-size: 16px;
      text-align: center;
    }
    .button:hover {
      background-color: #45a049;
    }
    .footer {
      margin-top: 20px;
      text-align: center;
      font-size: 12px;
      color: #aaaaaa;
      border-top: 1px solid #dddddd;
      padding-top: 10px;
    }
    a {
      color: #4caf50;
      text-decoration: none;
    }
    .social-icons {
      margin-top: 10px;
    }
    .social-icons img {
      width: 24px;
      margin: 0 5px;
      vertical-align: middle;
    }
  </style>
</head>
<body>
  <div class='container'>
    <div class='header'>
      <img src='https://via.placeholder.com/100x100' alt='Logo'>
      <h1>Welcome to StackSetup</h1>
    </div>
    <p>We are thrilled to have you onboard!</p>
    <p>This email showcases how beautiful and interactive HTML emails can be.</p>
    <a href='https://www.stacksetup.com' class='button'>Learn More</a>
    <p>Feel free to reply to this email for any assistance.</p>
    <div class='footer'>
      <p>Sent using a Shell Script and the swaks tool.</p>
      <div class='social-icons'>
        <a href='https://facebook.com'><img src='https://via.placeholder.com/24x24' alt='Facebook'></a>
        <a href='https://x.com'><img src='https://via.placeholder.com/24x24' alt='Twitter'></a>
        <a href='https://linkedin.com'><img src='https://via.placeholder.com/24x24' alt='LinkedIn'></a>
      </div>
    </div>
  </div>
</body>
</html>"


EMAIL_SUBJECT="Testing Email from OpenStack"
FROM_EMAIL_ADDRESS="brunolnetto@gmail.com"
TO_EMAIL_ADDRESS="brunolnetto@gmail.com"
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="brunolnetto@gmail.com"
SMTP_PASS="nfkp xxbp zzoc vfko"

### Execution Section
# Validate SMTP server and port
validate_smtp_server "$SMTP_SERVER"
validate_smtp_port "$SMTP_SERVER" "$SMTP_PORT"

# Send a test email
test_smtp "$FROM_EMAIL_ADDRESS" "$TO_EMAIL_ADDRESS" \
          "$SMTP_SERVER" "$SMTP_PORT" \
          "$SMTP_USER" "$SMTP_PASS" \
          "$EMAIL_SUBJECT" "$MESSAGE_BODY"

          
