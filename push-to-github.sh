#!/bin/bash
# Script to commit and push the final version to GitHub

# Ensure necessary directories exist
mkdir -p public
mkdir -p uploads
mkdir -p work

# Save the HTML file to public/index.html
cat > public/index.html << 'EOT'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CrossSign Certificate Tool</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .container {
            background-color: #f9f9f9;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        input[type="file"], input[type="password"] {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        button {
            background-color: #4CAF50;
            color: white;
            padding: 12px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #45a049;
        }
        .status {
            margin-top: 20px;
            padding: 15px;
            border-radius: 4px;
            display: none;
        }
        .success {
            background-color: #dff0d8;
            border: 1px solid #d6e9c6;
            color: #3c763d;
        }
        .error {
            background-color: #f2dede;
            border: 1px solid #ebccd1;
            color: #a94442;
        }
        .info-panel {
            margin-top: 30px;
            background-color: #e7f3fe;
            border-left: 4px solid #2196F3;
            padding: 15px;
        }
    </style>
</head>
<body>
    <h1>CrossSign Certificate Tool</h1>
    
    <div class="container">
        <form id="certificateForm">
            <div class="form-group">
                <label for="pfxFile">PFX File (Your Organization's CA):</label>
                <input type="file" id="pfxFile" name="pfxFile" accept=".pfx,.p12" required>
            </div>
            
            <div class="form-group">
                <label for="pfxPassword">PFX Password:</label>
                <input type="password" id="pfxPassword" name="pfxPassword" placeholder="Enter password (leave empty if none)">
            </div>
            
            <div class="form-group">
                <label for="csrFile">CSR File to Sign:</label>
                <input type="file" id="csrFile" name="csrFile" accept=".csr" required>
            </div>
            
            <div class="form-group">
                <label for="validityDays">Validity Period (days):</label>
                <input type="number" id="validityDays" name="validityDays" value="3660" min="1" max="7320">
            </div>
            
            <button type="submit">Process Certificate</button>
        </form>
        
        <div id="statusMessage" class="status"></div>
    </div>
    
    <div class="info-panel">
        <h3>About This Tool</h3>
        <p>This web interface allows you to:</p>
        <ul>
            <li>Upload a PFX/P12 file containing your organization's CA certificate and private key</li>
            <li>Provide the password for the PFX file (if required)</li>
            <li>Upload a Certificate Signing Request (CSR) file that needs to be cross-signed</li>
            <li>Set the validity period for the signed certificate</li>
        </ul>
        <p>After processing, you will be able to download the signed certificate in PEM format.</p>
    </div>
    
    <script>
        document.getElementById('certificateForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const pfxFile = document.getElementById('pfxFile').files[0];
            const pfxPassword = document.getElementById('pfxPassword').value;
            const csrFile = document.getElementById('csrFile').files[0];
            const validityDays = document.getElementById('validityDays').value;
            
            const statusMessage = document.getElementById('statusMessage');
            
            // Validate inputs
            if (!pfxFile || !csrFile) {
                statusMessage.textContent = 'Please select both a PFX file and a CSR file.';
                statusMessage.className = 'status error';
                statusMessage.style.display = 'block';
                return;
            }
            
            // Create a FormData object to send files to the backend
            const formData = new FormData();
            formData.append('pfxFile', pfxFile);
            formData.append('csrFile', csrFile);
            formData.append('pfxPassword', pfxPassword);
            formData.append('validityDays', validityDays);
            
            statusMessage.textContent = 'Files uploaded. Processing certificate...';
            statusMessage.className = 'status success';
            statusMessage.style.display = 'block';
            
            // Send the files to our backend API
            fetch('/api/upload', {
                method: 'POST',
                body: formData
            })
            .then(response => {
                if (!response.ok) {
                    return response.json().then(err => {
                        throw new Error(err.details || 'Certificate processing failed');
                    });
                }
                return response.json();
            })
            .then(data => {
                statusMessage.textContent = 'Certificate successfully signed! You can download it now.';
                
                // Create download link for the certificate
                const downloadLink = document.createElement('a');
                downloadLink.textContent = 'Download Signed Certificate';
                downloadLink.href = `/api/download/${data.certificateId}`;
                downloadLink.className = 'download-link';
                downloadLink.style.display = 'block';
                downloadLink.style.marginTop = '15px';
                downloadLink.style.textAlign = 'center';
                
                statusMessage.appendChild(document.createElement('br'));
                statusMessage.appendChild(downloadLink);
            })
            .catch(error => {
                console.error('Error:', error);
                statusMessage.textContent = `Error: ${error.message}`;
                statusMessage.className = 'status error';
            });
        });
    </script>
</body>
</html>
EOT

# Create server.js with the final working version
cat > server.js << 'EOT'
// server.js
const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const app = express();
const PORT = process.env.PORT || 3000;

// Set up storage for uploaded files
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Use original filenames for easier reference in Docker commands
    cb(null, file.originalname);
  }
});

const upload = multer({ storage });

// Serve static files from the 'public' directory
app.use(express.static('public'));
app.use(express.json());

// Upload endpoint that accepts PFX and CSR files
app.post('/api/upload', upload.fields([
  { name: 'pfxFile', maxCount: 1 },
  { name: 'csrFile', maxCount: 1 }
]), (req, res) => {
  try {
    if (!req.files || !req.files.pfxFile || !req.files.csrFile) {
      return res.status(400).json({ error: 'Missing required files' });
    }

    const pfxPath = req.files.pfxFile[0].path;
    const csrPath = req.files.csrFile[0].path;
    const pfxPassword = req.body.pfxPassword || '';
    const validityDays = req.body.validityDays || 3660;

    // Create a unique working directory for this request
    const sessionId = Date.now().toString();
    const workDir = path.join(__dirname, 'work', sessionId);
    fs.mkdirSync(workDir, { recursive: true });

    console.log(`Created working directory: ${workDir}`);

    // Copy files to working directory
    fs.copyFileSync(pfxPath, path.join(workDir, 'CA.pfx'));
    fs.copyFileSync(csrPath, path.join(workDir, 'iag_ca.csr'));
    
    console.log(`Copied files to working directory`);
    
    // Write password to a file
    const passwordFile = path.join(workDir, 'password.txt');
    fs.writeFileSync(passwordFile, pfxPassword);
    
    // Create a shell script to run the commands
    const scriptFile = path.join(workDir, 'process.sh');
    const scriptContent = `#!/bin/sh
set -e
echo "Starting certificate processing"

echo "Current working directory: \$(pwd)"
echo "Directory contents:"
ls -la
echo ""

echo "Creating directories and files"
# Work directory is already where we are - no need to change
mkdir -p newcerts
touch certindex
echo 'a000' > serialfile

echo "Extracting private key from PFX"
# Using full paths to reference files in our mounted volume
openssl pkcs12 -in ./CA.pfx -out ./root.key -nodes -nocerts -passin file:./password.txt
if [ ! -f ./root.key ]; then
  echo "ERROR: Failed to extract private key"
  exit 1
fi

echo "Extracting certificate from PFX"
openssl pkcs12 -in ./CA.pfx -out ./root.cer -nokeys -passin file:./password.txt
if [ ! -f ./root.cer ]; then
  echo "ERROR: Failed to extract certificate"
  exit 1
fi

echo "Directory contents before signing:"
ls -la
echo ""

# Use the config file from the container
echo "Config file content:"
cat /app/CrossSign/myca.conf
echo ""

echo "Running CA command to sign certificate"
openssl ca -batch -config /app/CrossSign/myca.conf -notext -days ${validityDays} -in ./iag_ca.csr -out ./iag_ca.cer

# Get the serial number from serialfile and use it for the output certificate name
SERIAL=\$(cat serialfile)
echo "Serial number is: \$SERIAL"

# Convert certificate to PEM format
openssl x509 -in ./iag_ca.cer -out "./\$SERIAL.pem" -outform PEM

echo "Directory contents after signing:"
ls -la
echo ""

echo "Checking for output certificate"
if [ ! -f "./\$SERIAL.pem" ]; then
  echo "ERROR: PEM Certificate file not generated"
  exit 1
fi

echo "Cleaning up"
rm ./password.txt
echo "Certificate processing complete"
`;
    fs.writeFileSync(scriptFile, scriptContent);
    fs.chmodSync(scriptFile, '755'); // Make executable
    
    console.log(`Created process script`);

    // Run Docker container with the script and capture output
    const dockerCmd = `docker run --rm -v "${workDir}:/app/CrossSign/work" --workdir "/app/CrossSign/work" crosssign ./process.sh`;
    
    console.log(`Executing Docker: ${dockerCmd}`);

    exec(dockerCmd, (error, stdout, stderr) => {
      console.log("Docker stdout:", stdout);
      console.log("Docker stderr:", stderr);
      
      if (error) {
        console.error(`Docker execution error: ${error}`);
        return res.status(500).json({ 
          error: 'Certificate processing failed',
          details: stderr || stdout
        });
      }

      // Get the serial number from the stdout to find our PEM file
      const serialMatch = stdout.match(/Serial number is: ([a-fA-F0-9]+)/);
      const serial = serialMatch ? serialMatch[1] : 'a000';
      
      // Check if certificate was generated
      const certPath = path.join(workDir, `${serial}.pem`);
      console.log(`Checking for certificate at: ${certPath}`);
      console.log(`Files in directory:`, fs.readdirSync(workDir));
      
      if (fs.existsSync(certPath)) {
        console.log(`Certificate found, preparing for download`);
        // Save certificate path for download
        req.app.locals.certificates = req.app.locals.certificates || {};
        req.app.locals.certificates[sessionId] = certPath;

        res.json({
          success: true,
          message: 'Certificate successfully signed',
          certificateId: sessionId,
          serialNumber: serial
        });
      } else {
        console.error(`Certificate file not found after processing`);
        return res.status(500).json({
          error: 'Certificate generation failed',
          details: 'Certificate file not found after processing. Check server logs for more information.'
        });
      }
    });
  } catch (err) {
    console.error('Error during processing:', err);
    res.status(500).json({ 
      error: 'Server error',
      details: err.message
    });
  }
});

// Download endpoint for the generated certificate
app.get('/api/download/:id', (req, res) => {
  const certificateId = req.params.id;
  const certificates = req.app.locals.certificates || {};
  
  if (!certificates[certificateId]) {
    return res.status(404).json({ error: 'Certificate not found' });
  }

  const certPath = certificates[certificateId];
  const fileName = path.basename(certPath);
  
  res.download(certPath, fileName, (err) => {
    if (err) {
      console.error('Download error:', err);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Download failed' });
      }
    }
  });
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOT

# Create Dockerfile
cat > Dockerfile << 'EOT'
FROM debian:bullseye-slim

# Install OpenSSL
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Set shell to sh for better compatibility
SHELL ["/bin/sh", "-c"]

# Set up working directory
WORKDIR /app

# Create directory structure
RUN mkdir -p CrossSign/newcerts
WORKDIR /app/CrossSign

# Create certindex file
RUN touch certindex

# Create serialfile with initial serial number
RUN echo "a000" > serialfile

# Create configuration file - escaping special characters
RUN echo "[ca]" > myca.conf && \
    echo "default_ca = rootca" >> myca.conf && \
    echo "" >> myca.conf && \
    echo "[crl_ext]" >> myca.conf && \
    echo "#issuerAltName=issuer:copy  #this would copy the issuer name to altname" >> myca.conf && \
    echo "authorityKeyIdentifier=keyid:always" >> myca.conf && \
    echo "" >> myca.conf && \
    echo "[rootca]" >> myca.conf && \
    echo "new_certs_dir = newcerts" >> myca.conf && \
    echo "unique_subject = no" >> myca.conf && \
    echo "certificate = root.cer  #Your organization's CA certificate" >> myca.conf && \
    echo "database = certindex" >> myca.conf && \
    echo "private_key = root.key  #Your organization's CA private key" >> myca.conf && \
    echo "serial = serialfile" >> myca.conf && \
    echo "default_days = 3660     #Should be at least two years from the date of cross-signing" >> myca.conf && \
    echo "default_md = sha256     #sha256 is required." >> myca.conf && \
    echo "policy = myca_policy" >> myca.conf && \
    echo "x509_extensions = myca_extensions" >> myca.conf && \
    echo "" >> myca.conf && \
    echo "[ myca_policy ]" >> myca.conf && \
    echo "countryName = optional" >> myca.conf && \
    echo "stateOrProvinceName = optional" >> myca.conf && \
    echo "localityName = optional" >> myca.conf && \
    echo "organizationName = supplied" >> myca.conf && \
    echo "organizationalUnitName = optional" >> myca.conf && \
    echo "commonName = supplied" >> myca.conf && \
    echo "emailAddress = optional" >> myca.conf && \
    echo "" >> myca.conf && \
    echo "[ myca_extensions ]     #These extensions are required." >> myca.conf && \
    echo "basicConstraints = CA:true" >> myca.conf && \
    echo "subjectKeyIdentifier = hash" >> myca.conf && \
    echo "authorityKeyIdentifier = keyid:always" >> myca.conf && \
    echo "keyUsage = keyCertSign, cRLSign" >> myca.conf

# Set entrypoint to sh for better compatibility
ENTRYPOINT ["/bin/sh"]
EOT

# Create package.json
cat > package.json << 'EOT'
{
  "name": "crosssign-web",
  "version": "1.0.0",
  "description": "Web interface for cross-signing certificates",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "multer": "^1.4.5-lts.1"
  },
  "devDependencies": {
    "nodemon": "^2.0.22"
  }
}
EOT

# Create README.md
cat > README.md << 'EOT'
# CrossSign Certificate Tool

This tool provides a web interface for uploading PFX/P12 files and CSR files to create cross-signed certificates.

## Features

- User-friendly web interface
- Upload PFX/P12 files with password protection
- Upload CSR files for signing
- Customize certificate validity period
- Download signed certificates in PEM format

## Prerequisites

- Docker
- Node.js (v14 or higher)
- npm (v6 or higher)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/mauaksu/crosssign-tool.git
   cd crosssign-tool
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Build the Docker container:
   ```
   docker build -t crosssign -f Dockerfile .
   ```

4. Create required directories:
   ```
   mkdir -p uploads work
   ```

5. Start the application:
   ```
   npm start
   ```

6. Open your browser and navigate to:
   ```
   http://localhost:3000
   ```

## Usage

1. Access the web interface in your browser
2. Upload your PFX/P12 file containing your CA certificate and private key
3. Enter the PFX password (if applicable)
4. Upload the CSR file that needs to be signed
5. Set the validity period for the signed certificate
6. Click "Process Certificate"
7. Download the signed certificate when processing is complete

## Directory Structure

- `public/` - Static web files
- `uploads/` - Temporary storage for uploaded files
- `work/` - Working directories for certificate processing
- `server.js` - Backend API
- `Dockerfile` - Docker configuration for certificate processing

## Security Considerations

- This tool handles sensitive cryptographic material. Run it in a secure environment.
- PFX passwords are handled in memory and not stored permanently.
- Files are processed in isolated Docker containers.
- Password files are deleted after use.
- Consider implementing additional security measures for production use.

## License

MIT

## Support

For issues or questions, please open an issue on the GitHub repository.
EOT

# Create .gitignore
cat > .gitignore << 'EOT'
# Node.js
node_modules/
npm-debug.log
yarn-error.log
package-lock.json
yarn.lock

# Runtime data
uploads/
work/

# Environment variables
.env

# Logs
logs
*.log

# OS specific files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOT

# Git operations
echo "Handling git operations..."

# Check if .git directory exists
if [ ! -d .git ]; then
  git init
  git remote add origin https://github.com/mauaksu/crosssign-tool.git
fi

# Fetch latest from remote
git fetch origin

# Clean pull and reset to avoid merge conflicts
if git branch -r | grep -q 'origin/main'; then
  # If main branch exists on remote, pull latest
  git checkout main 2>/dev/null || git checkout -b main
  git reset --hard origin/main
else
  # If main branch doesn't exist, create it
  git checkout -b main
fi

# Add all files
git add .

# Commit with detailed message
git commit -m "Complete implementation of CrossSign certificate tool

- Added functional web interface for certificate signing
- Implemented Docker container for OpenSSL operations
- Set up certificate signing with PEM output format
- Added serial number based certificate naming
- Fixed paths and configuration issues"

# Try to push, handle potential issues
if ! git push -u origin main; then
  echo "Push failed. You might need to force push if you want to overwrite remote content."
  echo "To force push, use: git push -f origin main"
  echo "WARNING: This will overwrite any changes on the remote repository."
fi

echo "Git operations completed. Please check output for any errors."
echo "Next steps:"
echo "1. npm install"
echo "2. docker build -t crosssign ."
echo "3. npm start"