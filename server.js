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

    // Copy files to working directory
    fs.copyFileSync(pfxPath, path.join(workDir, 'SubCACRL.pfx'));
    fs.copyFileSync(csrPath, path.join(workDir, 'iag_ca.csr'));

    // Run Docker container to process the files
    const dockerCmd = `docker run --rm -v "${workDir}:/app/CrossSign" -e PFX_PASSWORD="${pfxPassword}" -e VALIDITY_DAYS="${validityDays}" crosssign /bin/bash -c "
      mkdir -p newcerts
      touch certindex
      echo 'a000' > serialfile
      openssl pkcs12 -in SubCACRL.pfx -out root.key -nodes -nocerts -passin pass:${pfxPassword}
      openssl pkcs12 -in SubCACRL.pfx -out root.cer -nokeys -passin pass:${pfxPassword}
      openssl ca -batch -config myca2.conf -notext -days ${validityDays} -in iag_ca.csr -out iag_ca.cer
    "`;

    exec(dockerCmd, (error, stdout, stderr) => {
      if (error) {
        console.error(`Docker execution error: ${error}`);
        return res.status(500).json({ 
          error: 'Certificate processing failed',
          details: stderr
        });
      }

      // Check if certificate was generated
      const certPath = path.join(workDir, 'iag_ca.cer');
      if (fs.existsSync(certPath)) {
        // Save certificate path for download
        req.app.locals.certificates = req.app.locals.certificates || {};
        req.app.locals.certificates[sessionId] = certPath;

        res.json({
          success: true,
          message: 'Certificate successfully signed',
          certificateId: sessionId
        });
      } else {
        res.status(500).json({
          error: 'Certificate generation failed',
          details: 'Certificate file not found after processing'
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

  res.download(certificates[certificateId], 'signed_certificate.cer', (err) => {
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
