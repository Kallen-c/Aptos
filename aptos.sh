#!/bin/bash
exists()
{
  command -v "$1" >/dev/null 2>&1
}
if exists curl; then
	echo ''
else
  sudo apt install curl -y < "/dev/null"
fi
curl -s curl -s https://raw.githubusercontent.com/Kallen-c/utils/main/logo.sh | bash && sleep 2

sudo apt update && sudo apt install git -y
cd $HOME
rm -rf aptos-core
sudo mkdir -p /opt/aptos/etc/ /opt/aptos/data .aptos/config .aptos/key
git clone https://github.com/aptos-labs/aptos-core.git
cd aptos-core
git checkout origin/devnet &>/dev/null
echo y | ./scripts/dev_setup.sh
source ~/.cargo/env
cargo build -p aptos-node --release
cargo build -p aptos-operational-tool --release
mv  ~/aptos-core/target/release/aptos-node /usr/local/bin
mv  ~/aptos-core/target/release/aptos-operational-tool /usr/local/bin
#/usr/local/bin/aptos-operational-tool generate-key --encoding hex --key-type x25519 --key-file ~/.aptos/key/private-key.txt
if [ -f ~/.aptos/key/private-key.txt ]; then
    echo ""
else 
    /usr/local/bin/aptos-operational-tool generate-key --encoding hex --key-type x25519 --key-file ~/.aptos/key/private-key.txt
fi

if [ -f ~/.aptos/config/peer-info.yaml ]; then
    echo ""
else 
    /usr/local/bin/aptos-operational-tool extract-peer-from-file --encoding hex --key-file ~/.aptos/key/private-key.txt --output-file ~/.aptos/config/peer-info.yaml &>/dev/null
fi

#/usr/local/bin/aptos-operational-tool extract-peer-from-file --encoding hex --key-file ~/.aptos/key/private-key.txt --output-file ~/.aptos/config/peer-info.yaml &>/dev/null
cp ~/aptos-core/config/src/config/test_data/public_full_node.yaml ~/.aptos/config/
wget -q -O /opt/aptos/etc/genesis.blob https://devnet.aptoslabs.com/genesis.blob
wget -q -O /opt/aptos/etc/waypoint.txt https://devnet.aptoslabs.com/waypoint.txt
PRIVKEY=$(cat ~/.aptos/key/private-key.txt)
PEER=$(sed -n 2p ~/.aptos/config/peer-info.yaml | sed 's/.$//')
sed -i "s/genesis_file_location: .*/genesis_file_location: \"\/opt\/aptos\/etc\/genesis.blob\"/" $HOME/.aptos/config/public_full_node.yaml
sed -i "s/from_file: .*/from_file: \"\/opt\/aptos\/etc\/waypoint.txt\"/" $HOME/.aptos/config/public_full_node.yaml
sleep 2 
sed -i.bak -e "s/127.0.0.1/0.0.0.0/" $HOME/.aptos/config/public_full_node.yaml
sed -i '/listen_address: \"*\"/a\
      identity:\
        type: "from_config"\
        key: "'$PRIVKEY'"\
        peer_id: "'$PEER'"' $HOME/.aptos/config/public_full_node.yaml


echo "[Unit]
Description=Aptos
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=/usr/local/bin/aptos-node -f $HOME/.aptos/config/public_full_node.yaml
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > $HOME/aptosd.service
mv $HOME/aptosd.service /etc/systemd/system/
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable aptosd
sudo systemctl restart aptosd
echo "==================================================="
echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service aptosd status | grep active` =~ "running" ]]; then
  echo -e "Your Aptos node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice aptosd status\e[0m"
  echo -e "Press \e[7mQ\e[0m for exit from status menu"
else
  echo -e "Your Aptos node \e[31mwas not installed correctly\e[39m, please reinstall."
