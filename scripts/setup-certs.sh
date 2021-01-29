#!/usr/bin/env bash
# Copied from https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate

NAME=planet4.test

######################
# Become a Certificate Authority
######################

echo 'You will get a lot of prompts. Most can use default value (leave empty), except Common Name and pass phrase.'
echo '===== Generate CA private key '
openssl genrsa -out certs/myCA.key 2048
echo '===== Generate CA root certificate '
openssl req -x509 -new -nodes \
  -key certs/myCA.key \
  -sha256 \
  -days 825 \
  -out certs/myCA.pem

######################
# Create CA-signed certs
######################

echo '===== Generate domain private key'
openssl genrsa -out certs/$NAME.key 2048

echo "===== Create a certificate-signing request for $NAME"
openssl req -new -key certs/$NAME.key -out certs/$NAME.csr

echo '===== Create a config file for the extensions'
>certs/$NAME.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $NAME # Be sure to include the domain name here because Common Name is not so commonly honoured by itself
DNS.2 = www.$NAME # Optionally, add additional domains (I've added a subdomain here)
EOF

echo '===== Create the signed certificate'
openssl x509 -req \
  -in certs/$NAME.csr \
  -CA certs/myCA.pem \
  -CAkey certs/myCA.key \
  -CAcreateserial \
  -out certs/$NAME.crt \
  -days 825 \
  -sha256 \
  -extfile certs/$NAME.ext

echo '===== Removing CA key, otherwise can be used to forge new certificates your browser will trust.'
rm certs/myCA.key certs/myCA.srl

echo '===== Certificates were generated. You can now import the certs/myCA.pem file into trusted CAs of your browser.'
