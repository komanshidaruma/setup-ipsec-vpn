#!/bin/bash

wget https://git.io/vpnsetup -O vpnsetup.sh

cat vpnsetup.sh | \
sed -z "s/{VPN_XAUTH_POOL:-'192.168.43.10-192.168.43.250'}/{VPN_XAUTH_POOL:-'192.168.43.10-192.168.43.250'}\nOPENVPN_NET=\${VPN_OPENVPN_NET:-'10.8.0.0\/24'}/g" | \
sed -z 's/iptables -I INPUT 6 -p udp --dport 1701 -j DROP/iptables -I INPUT 6 -p udp --dport 1701 -j DROP\n  iptables -I INPUT 7 -p tcp --dport 443 -j ACCEPT/g' | \
sed -z 's/iptables -I FORWARD 6 -s "$XAUTH_NET" -o "$NET_IFACE" -j ACCEPT/iptables -I FORWARD 6 -s "$XAUTH_NET" -o "$NET_IFACE" -j ACCEPT\n  iptables -I FORWARD 7 -i "$NET_IFACE" -d "$OPENVPN_NET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT\n  iptables -I FORWARD 8 -s "$OPENVPN_NET" -o "$NET_IFACE" -j ACCEPT/g' | \
sed -z 's/iptables -t nat -I POSTROUTING -s "$L2TP_NET" -o "$NET_IFACE" -j MASQUERADE/iptables -t nat -I POSTROUTING -s "$L2TP_NET" -o "$NET_IFACE" -j MASQUERADE\n  iptables -t nat -I POSTROUTING -s "$OPENVPN_NET" -o "$NET_IFACE" -j MASQUERADE/g' | \
sed -z 's/+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT/+ -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT/g' | \
sed -z 's/" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT/" -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT/g' | \
#sed -e "s/YOUR_IPSEC_PSK=''/YOUR_IPSEC_PSK='xxxxxxxx'/g" | \
#sed -e "s/YOUR_USERNAME=''/YOUR_USERNAME='xxxxxxxx'/g" | \
#sed -e "s/YOUR_PASSWORD=''/YOUR_PASSWORD='xxxxxxxx'/g" > vpnsetup_MOD.sh

sudo sh vpnsetup_MOD.sh

######################## STEP1
sudo apt update
echo Y | sudo apt install openvpn
wget -P ~/ https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz
cd ~
tar xvf EasyRSA-3.0.4.tgz

######################## STEP2
mv EasyRSA-3.0.4 EasyRSA-3.0.4_CA
cd ~/EasyRSA-3.0.4_CA/
cp -p vars.example vars
./easyrsa init-pki
echo | ./easyrsa build-ca nopass

##################### STEP3 
cd ~
tar xvf EasyRSA-3.0.4.tgz
mv EasyRSA-3.0.4 EasyRSA-3.0.4_SERVER
cd ~/EasyRSA-3.0.4_SERVER/
./easyrsa init-pki
echo | ./easyrsa gen-req server nopass

sudo cp -p ~/EasyRSA-3.0.4_SERVER/pki/private/server.key /etc/openvpn/
cd ~/EasyRSA-3.0.4_CA/
./easyrsa import-req ~/EasyRSA-3.0.4_SERVER/pki/reqs/server.req server
echo yes | ./easyrsa sign-req server server

sudo cp -p pki/issued/server.crt /etc/openvpn/
sudo cp -p pki/ca.crt /etc/openvpn/
cd ~/EasyRSA-3.0.4_SERVER/
./easyrsa gen-dh
openvpn --genkey --secret ta.key
sudo cp -p ./ta.key /etc/openvpn/
sudo cp -p ./pki/dh.pem /etc/openvpn/

####################### STEP4 
mkdir -p ~/client-configs/keys
chmod -R 700 ~/client-configs
cd ~/EasyRSA-3.0.4_SERVER/
echo | ./easyrsa gen-req client1 nopass
echo | ./easyrsa gen-req client2 nopass
echo | ./easyrsa gen-req client3 nopass
echo | ./easyrsa gen-req client4 nopass
echo | ./easyrsa gen-req client5 nopass
cp -p pki/private/client1.key ~/client-configs/keys/
cp -p pki/private/client2.key ~/client-configs/keys/
cp -p pki/private/client3.key ~/client-configs/keys/
cp -p pki/private/client4.key ~/client-configs/keys/
cp -p pki/private/client5.key ~/client-configs/keys/
cd ~/EasyRSA-3.0.4_CA/
./easyrsa import-req ~/EasyRSA-3.0.4_SERVER/pki/reqs/client1.req client1
echo yes |./easyrsa sign-req client client1
./easyrsa import-req ~/EasyRSA-3.0.4_SERVER/pki/reqs/client2.req client2
echo yes |./easyrsa sign-req client client2
./easyrsa import-req ~/EasyRSA-3.0.4_SERVER/pki/reqs/client3.req client3
echo yes |./easyrsa sign-req client client3
./easyrsa import-req ~/EasyRSA-3.0.4_SERVER/pki/reqs/client4.req client4
echo yes |./easyrsa sign-req client client4
./easyrsa import-req ~/EasyRSA-3.0.4_SERVER/pki/reqs/client5.req client5
echo yes |./easyrsa sign-req client client5

cd ~/EasyRSA-3.0.4_SERVER/
cp -p ~/EasyRSA-3.0.4_CA/pki/issued/client1.crt ~/client-configs/keys/
cp -p ~/EasyRSA-3.0.4_CA/pki/issued/client2.crt ~/client-configs/keys/
cp -p ~/EasyRSA-3.0.4_CA/pki/issued/client3.crt ~/client-configs/keys/
cp -p ~/EasyRSA-3.0.4_CA/pki/issued/client4.crt ~/client-configs/keys/
cp -p ~/EasyRSA-3.0.4_CA/pki/issued/client5.crt ~/client-configs/keys/
cp -p ~/EasyRSA-3.0.4_SERVER/ta.key ~/client-configs/keys/
sudo cp -p /etc/openvpn/ca.crt ~/client-configs/keys/

####################### STEP5 

sudo cp -p /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
sudo gzip -d /etc/openvpn/server.conf.gz
sed -e 's/dh dh2048.pem/dh dh.pem/g' \
 -e 's/;user nobody/user nobody/g' \
 -e 's/;group nogroup/group nogroup/g' \
 -e 's/;push "redirect-gateway def1 bypass-dhcp"/push "redirect-gateway def1 bypass-dhcp"/g' \
 -e 's/port 1194/port 443/g' \
 -e 's/proto udp/proto tcp/g' \
 -e 's/explicit-exit-notify 1/explicit-exit-notify 0/g'  /etc/openvpn/server.conf > /tmp/server.conf
echo >> /tmp/server.conf
echo >> /tmp/server.conf
echo "auth SHA256" >> /tmp/server.conf
sudo mv /tmp/server.conf /etc/openvpn/server.conf

####################### STEP7
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server


####################### STEP8 
mkdir -p ~/client-configs/files
cp -p /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/client-configs/base.conf
PUBLIC_IP=$(wget -t 3 -T 15 -qO- http://ipv4.icanhazip.com)
sed \
 -e 's/proto udp/proto tcp/g' \
 -e 's/remote my-server-1 1194/remote '$PUBLIC_IP' 443/g' \
 -e 's/;user nobody/user nobody/g' \
 -e 's/;group nogroup/group nogroup/g' \
 -e 's/ca ca.crt/;ca ca.crt/g' \
 -e 's/cert client.crt/;cert client.crt/g' \
 -e 's/key client.key/;key client.key/g' \
 -e 's/tls-auth ta.key 1/;tls-auth ta.key 1/g' \
 ~/client-configs/base.conf > /tmp/base.conf
echo >> /tmp/base.conf
echo auth SHA256 >> /tmp/base.conf
echo key-direction 1 >> /tmp/base.conf
sudo mv /tmp/base.conf ~/client-configs/base.conf


KEY_DIR=~/client-configs/keys
OUTPUT_DIR=~/client-configs/files
BASE_CONFIG=~/client-configs/base.conf
TARGET=client1
cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${TARGET}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${TARGET}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${TARGET}.ovpn

TARGET=client2
cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${TARGET}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${TARGET}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${TARGET}.ovpn

TARGET=client3
cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${TARGET}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${TARGET}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${TARGET}.ovpn

TARGET=client4
cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${TARGET}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${TARGET}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${TARGET}.ovpn

TARGET=client5
cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${TARGET}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${TARGET}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${TARGET}.ovpn

#######################
echo Y | sudo apt install apache2
sudo cp -p  ~/client-configs/files/client*.ovpn /var/www/html
