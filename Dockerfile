FROM debian:bullseye-slim

# Install OpenSSL
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Create directory structure
RUN mkdir -p CrossSign/newcerts
WORKDIR /app/CrossSign

# Create certindex file
RUN touch certindex

# Create serialfile with initial serial number
RUN echo "a000" > serialfile

# Create configuration file
RUN cat > myca2.conf << 'EOF'
[ca]
default_ca = rootca

[crl_ext]
#issuerAltName=issuer:copy  #this would copy the issuer name to altname
authorityKeyIdentifier=keyid:always

[rootca]
new_certs_dir = newcerts
unique_subject = no
certificate = root.cer  #Your organization's CA certificate
database = certindex
private_key = root.key  #Your organization's CA private key
serial = serialfile
default_days = 3660     #Should be at least two years from the date of cross-signing
default_md = sha256     #sha256 is required.
policy = myca_policy
x509_extensions = myca_extensions

[ myca_policy ]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = supplied
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[ myca_extensions ]     #These extensions are required.
basicConstraints = CA:true
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
keyUsage = keyCertSign, cRLSign
EOF

# The CSR files and PFX file need to be copied from the host
# Create placeholders for the COPY commands that will be needed
# Note: These files need to be in the same directory as the Dockerfile when building

# Copy CSR files
COPY cloud_ca.csr /app/CrossSign/
COPY iag_ca.csr /app/CrossSign/

# Copy PFX file
COPY SubCACRL.pfx /app/CrossSign/

# Extract private key and certificate from PFX
RUN openssl pkcs12 -in SubCACRL.pfx -out root.key -nodes -nocerts -passin pass:
RUN openssl pkcs12 -in SubCACRL.pfx -out root.cer -nokeys -passin pass:

# Run the CA command to sign the CSR
# Note: This is commented out to allow manual execution after container starts
# as there might be interactive steps or you might want to verify before signing
# RUN openssl ca -batch -config myca2.conf -notext -days 7320 -in iag_ca.csr -out iag_ca.cer

# Set entrypoint to bash to keep container running
ENTRYPOINT ["/bin/bash"]
