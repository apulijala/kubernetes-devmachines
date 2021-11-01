#!/bin/bash 

function  log() {

   if [[ $# ==  1 ]]; then
        LOGLEVEL="DEBUG"
    else 
        LOGLEVEL="$1"
        shift
   fi
   
   echo "$LOGLEVEL :$@" >> "./kubelog"
   return 1
}

if [ ! -f "/opt/homebrew/bin/brew" ]
then
    echo "brew not found . Installing"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/arvindpulijala/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/arvindpulijala/.bash_prorfile
# Set the bash environment for brewß
eval "$(/opt/homebrew/bin/brew shellenv)"

# install virtualbox.
# brew install --cask virtualbox

log "Clear existing log"
> "./kubelog"
log "Provisioning VMs  "
# Download vagrant binary.
/opt/homebrew/bin/brew install vagrant
# Primary   Network stats
primarystats=$(netstat -rn -f inet | grep default)

# Primary network card.
networkcardtobridge=$(echo "$primarystats" | awk '{print $NF}')
networkcardtobridge="$networkcardtobridge: Wi-Fi"
echo "$networkcardtobridge"

# INTR="$networkcardtobridge" vagrant up
brew install ansible





