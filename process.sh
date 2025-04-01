#!/bin/sh
mkdir -p newcerts
touch certindex
echo 'a000' > serialfile
openssl pkcs12 -in CA.pfx -out root.key -nodes -nocerts -passin file:password.txt
openssl pkcs12 -in CA.pfx -out root.cer -nokeys -passin file:password.txt
openssl ca -batch -config myca.conf -notext -days 7320 -in iag_ca.csr -out iag_ca.cer
rm password.txt