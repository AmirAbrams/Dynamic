RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m'

PROJECT="dynamic"
PROJECT_FOLDER="/root/dynamic"

DAEMON_BINARY="dynamicd"

DAEMON_BINARY_PATH="/root/dynamic/src/dynamicd"
CLI_BINARY="/root/dynamic/src/dynamic-cli"
CONF_FILE="/root/.dynamic/dynamic.conf"
P2P_PORT="33300"
RPC_PORT="33301"

DAEMON_START="/root/dynamic/src/dynamicd -daemon"
CRONTAB_LINE="@reboot $DAEMON_START"

GITHUB_REPO="https://github.com/duality-solutions/dynamic.git"
GITHUB_BRANCH="master"

function get_shared_key() 
{
  echo -e "Enter your ${RED}Dynode Private Key${NC}:"
  read -e COINKEY
}

function checks() 
{
  if [[ $(lsb_release -d) >= *16.04* ]]; then
    echo -e "${RED}You are not running Ubuntu 16.04 or above. Installation is cancelled.${NC}"
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "${RED}$0 must be run as root.${NC}"
     exit 1
  fi
}

function show_header()
{
  clear
  echo -e "${RED}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
  echo -e "${YELLOW}$Dynode Installer ${NC}"
  echo -e "${RED}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
  echo
  echo -e "${BLUE}This script will automate the UPDATE of your ${YELLOW}$PROJECT ${BLUE}dynode along with the server configuration."
  echo -e "It will:"
  echo
  echo -e " ${YELLOW}■${NC} Prepare your system with any missing dependencies"
  echo -e " ${YELLOW}■${NC} Rebuild the new project from GitHUB in a temp folder"
  echo -e " ${YELLOW}■${NC} Copy the new binaries to the project folder and remove the temp folder"
  echo -e " ${YELLOW}■${NC} Modify syntax and naming conventions."
  echo -e " ${YELLOW}■${NC} Check if you have Brute-Force protection. If not install fail2ban."
  echo -e " ${YELLOW}■${NC} Update the system firewall to only allow SSH, the dynode ports and outgoing connections"
  echo -e " ${YELLOW}■${NC} Add or modify the schedule entry for the service to restart automatically on power cycles/reboots."
  echo
  read -e -p "$(echo -e ${YELLOW}Continue with installation? [Y/N] ${NC})" CHOICE

if [[ ("$CHOICE" == "n" || "$CHOICE" == "N") ]]; then
  exit 1
fi
}

function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcport=RPC_PORT
port=P2P_PORT
dynodepairingkey=$COINKEY
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
daemon=1
server=1
listen=1
dynode=1
EOF
}

function create_swap()
{
  fallocate -l 3G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo
  echo -e "/swapfile none swap sw 0 0 \n" >> /etc/fstab
}

function clone_github()
{
  echo
  echo -e "${BLUE}Cloning GitHUB${NC}"
  cd /root/
  git clone $GITHUB_REPO $PROJECT_FOLDER
  if [ $? -eq 0 ]; then
    echo -e "${BLUE}GitHUB Cloned - Proceeding to next step. ${NC}"
    echo
  else
    RETVAL=$?
    echo -e "${RED}Git Clone has failed. Please see error above : $RETVAL ${NC}"
    exit 1
  fi
}

function install_prerequisites()
{
  echo
  echo -e "${BLUE}Installing Pre-requisites${NC}"
  sudo apt-get install -y pkg-config
  sudo apt-get install -y build-essential libtool autotools-dev autoconf automake pkg-config libssl-dev libboost-all-dev libprotobuf-dev protobuf-compiler libcrypto++-dev libevent-dev
  sudo add-apt-repository ppa:bitcoin/bitcoin -y
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo apt-get install -y libdb4.8-dev libdb4.8++-dev
}

function build_project()
{
  cd $PROJECT_FOLDER
  echo
  echo -e "${BLUE}Compiling the wallet (this can take 20 minutes)${NC}"
  sudo ./autogen.sh
  sudo ./configure
  sudo make
  if [ -f $DAEMON_BINARY_PATH ]; then
    echo -e "${BLUE}$PROJECT_NAME Daemon and CLI installed, proceeding to next step...${NC}"
    echo
  else
    RETVAL=$?
    echo -e "${RED}installation has failed. Please see error above : $RETVAL ${NC}"
    exit 1
  fi
}

function configure_firewall()
{
  echo
  echo -e "${BLUE}setting up firewall...${NC}"
  sudo apt-get install -y ufw
  sudo apt-get update -y
  
  #configure ufw firewall
  sudo ufw default allow outgoing
  sudo ufw default deny incoming
  sudo ufw allow ssh/tcp
  sudo ufw limit ssh/tcp
  sudo ufw allow $MN_PORT/tcp
  sudo ufw logging on
}

function add_cron()
{
(crontab -l; echo "$CRONTAB_LINE") | crontab -
}

function start_wallet()
{
  echo
  echo -e "${BLUE}Re-Starting the wallet...${NC}"
  if [ -f $DAEMON_BINARY_PATH ]; then
    $DAEMON_START
    echo
    echo -e "${BLUE}Congratulations, you've installed your dynode!${NC}"
    echo -e "${YELLOW}On your Windows/Mac wallet:${NC}"
    echo -e "${BLUE}Please go to your Dynodes tab, click on your dynode and press on ${YELLOW}Start Alias${NC}"
  
  echo
    echo -e "${RED}---===>>> NEXT STEPS <<<===---${NC}"
    echo -e "${BLUE}Wait 10-20 minutes for the dynode to announce itself then:${NC}"
    echo -e "${BLUE}type this in the VPN:${NC}"
    echo -e "${GREEN}~/dynamic/src/dynamic-cli stop${NC}"
    echo -e "${GREEN}~/dynamic/src/dynamicd -daemon${NC}"
    echo -e "${BLUE}(or simply reboot your server)${NC}"
    echo -e "${BLUE}Your wallet timer on your Windows/Mac wallet will start counting up shortly after${NC}"
    echo -e "${BLUE}and rewards will resume after maturity.${NC}"
    echo
    echo -e "${YELLOW}OR${NC}"
    echo
    echo -e "${BLUE}Would you like me to wait 15 minutes and do this for you?${NC}"
    read -e -p "$(echo -e ${YELLOW}[Y/N] ${NC})" CHOICE
    if [[ ("$CHOICE" == "n" || "$CHOICE" == "N") ]]; then
      exit 1
    fi
    echo -e "${BLUE}Waiting 15 minutes...${NC}"
    echo
    sleep 900
    echo -e "${BLUE}Restarting Dynode...${NC}"
    $CLI_BINARY stop
    $DAEMON_START
    echo -e "${BLUE}Your QT wallet should update in a few minutes.${NC}"
    $CLI_BINARY dynode status
    echo -e "${BLUE}End of Upgrade.${NC}"
  else
    RETVAL=$?
    echo -e "${RED}Binary not found! Please scroll up to see errors above : $RETVAL ${NC}"
    exit 1
  fi
}

function deploy()
{
  checks
  show_header
  get_shared_key
  create_swap
  install_prerequisites
  clone_github
  create_config
  build_project
  configure_firewall
  add_cron
  start_wallet
}

deploy