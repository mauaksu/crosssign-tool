# CrossSign Certificate Tool

This tool provides a web interface for uploading PFX/P12 files and CSR files to create cross-signed certificates.

## Features

- User-friendly web interface
- Upload PFX/P12 files with password protection
- Upload CSR files for signing
- Customize certificate validity period
- Download signed certificates

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
- Consider implementing additional security measures for production use.

## License

MIT

## Support

For issues or questions, please open an issue on the GitHub repository.
