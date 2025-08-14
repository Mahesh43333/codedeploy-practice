#!/bin/bash

# Create temporary directory
TEMP_DIR=$(mktemp -d)

# Create directory structure
mkdir -p "${TEMP_DIR}/my-codedeploy-demo/scripts"

# Create appspec.yml
cat > "${TEMP_DIR}/my-codedeploy-demo/appspec.yml" << 'EOL'
version: 0.0
os: linux
files:
  - source: app.js
    destination: /home/ec2-user/myapp
hooks:
  ApplicationStop:
    - location: scripts/stop_server.sh
      timeout: 300
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
  AfterInstall:
    - location: scripts/start_server.sh
      timeout: 300
  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 300
  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 300
EOL

# Create app.js
cat > "${TEMP_DIR}/my-codedeploy-demo/app.js" << 'EOL'
const http = require('http');
const port = 8080;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('Hello from AWS CodeDeploy!\nVersion 1.0\n');
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
EOL

# Create stop_server.sh
cat > "${TEMP_DIR}/my-codedeploy-demo/scripts/stop_server.sh" << 'EOL'
#!/bin/bash
echo "Stopping any existing Node.js server..."
pkill -f "node app.js" || echo "No existing server found"
EOL

# Create install_dependencies.sh
cat > "${TEMP_DIR}/my-codedeploy-demo/scripts/install_dependencies.sh" << 'EOL'
#!/bin/bash
echo "Installing dependencies..."
curl -sL https://rpm.nodesource.com/setup_14.x | sudo bash -
sudo yum install -y nodejs
EOL

# Create start_server.sh
cat > "${TEMP_DIR}/my-codedeploy-demo/scripts/start_server.sh" << 'EOL'
#!/bin/bash
echo "Starting application..."
cd /home/ec2-user/myapp
nohup node app.js > /dev/null 2> /dev/null < /dev/null &
EOL

# Create validate_service.sh
cat > "${TEMP_DIR}/my-codedeploy-demo/scripts/validate_service.sh" << 'EOL'
#!/bin/bash
echo "Validating service..."
max_retries=5
retry_count=0

while [ $retry_count -lt $max_retries ]; do
  response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
  if [ "$response" == "200" ]; then
    echo "Service is running successfully!"
    exit 0
  fi
  echo "Attempt $((retry_count+1)): Service not responding (Status: $response)"
  retry_count=$((retry_count+1))
  sleep 5
done

echo "Validation failed after $max_retries attempts"
exit 1
EOL

# Make scripts executable
chmod +x "${TEMP_DIR}/my-codedeploy-demo/scripts"/*.sh

# Create ZIP file
cd "${TEMP_DIR}" && zip -r my-codedeploy-demo.zip my-codedeploy-demo

# Move ZIP to current directory
mv "${TEMP_DIR}/my-codedeploy-demo.zip" .

# Cleanup
rm -rf "${TEMP_DIR}"

echo "Created my-codedeploy-demo.zip in current directory"