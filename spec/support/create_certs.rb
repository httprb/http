require 'fileutils'
require 'certificate_authority'

FileUtils.mkdir_p(certs_dir)

#
# Certificate Authority
#

ca = CertificateAuthority::Certificate.new

ca.subject.common_name  = 'honestachmed.com'
ca.serial_number.number = 1
ca.key_material.generate_key
ca.signing_entity = true

ca.sign! 'extensions' => {'keyUsage' => {'usage' => %w[critical keyCertSign]}}

ca_cert_path = File.join(certs_dir, 'ca.crt')
ca_key_path  = File.join(certs_dir, 'ca.key')

File.write ca_cert_path, ca.to_pem
File.write ca_key_path,  ca.key_material.private_key.to_pem

#
# Server Certificate
#

server_cert = CertificateAuthority::Certificate.new
server_cert.subject.common_name  = '127.0.0.1'
server_cert.serial_number.number = 1
server_cert.key_material.generate_key
server_cert.parent = ca
server_cert.sign!

server_cert_path = File.join(certs_dir, 'server.crt')
server_key_path  = File.join(certs_dir, 'server.key')

File.write server_cert_path, server_cert.to_pem
File.write server_key_path,  server_cert.key_material.private_key.to_pem

#
# Client Certificate
#

client_cert = CertificateAuthority::Certificate.new
client_cert.subject.common_name  = '127.0.0.1'
client_cert.serial_number.number = 1
client_cert.key_material.generate_key
client_cert.parent = ca
client_cert.sign!

client_cert_path = File.join(certs_dir, 'client.crt')
client_key_path  = File.join(certs_dir, 'client.key')

File.write client_cert_path, client_cert.to_pem
File.write client_key_path,  client_cert.key_material.private_key.to_pem
