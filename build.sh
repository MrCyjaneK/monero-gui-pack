#!/bin/bash
set -x
TAG=$1
ARCH=$2
echo "==== Installing required software"
apt update
apt install git curl apt-transport-https ca-certificates curl gnupg lsb-release -y
if [[ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]];
then
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
fi
echo "==== Cloning monero's repo"
git clone --branch $TAG --recursive --depth=1 https://github.com/monero-project/monero-gui.git
cd monero-gui
sed 's/x86_64/*/g' Dockerfile.linux
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" >> /etc/apt/sources.list.d/docker.list

if [[ "$ARCH" == "x86_64" ]];
then
    DOCKERARCH="amd64"
    COMBOARCH="amd64"
fi
if [[ "$ARCH" == "aarch64" ]];
then
    DOCKERARCH="arm64"
    COMBOARCH="arm64"
fi
apt update
apt install -y docker-ce docker-ce-cli containerd.io
echo "ARCH: $ARCH; DOCKERARCH:$DOCKERARCH; TAG:$TAG"
echo "==== Building docker image"
IMGNAME=monero:build-env-linux-$ARCH-$TAG
export DOCKER_CLI_EXPERIMENTAL=enabled
docker buildx create --use --name monero
docker buildx use monero
docker buildx build --load --platform linux/$DOCKERARCH --tag $IMGNAME --build-arg THREADS=4 --file Dockerfile.linux .
docker run --platform linux/$DOCKERARCH --rm -it -v /home/abstruse/tmp/monero-gui-pack/monero-gui:/monero-gui -w /monero-gui $IMGNAME sh -c 'make release-static -j4'

cd build/release/bin

mkdir -p /archive/$ARCH/$TAG
cp monero-blockchain-ancestry monero-blockchain-depth monero-blockchain-export monero-blockchain-import monero-blockchain-mark-spent-outputs monero-blockchain-prune monero-blockchain-prune-known-spent-data monero-blockchain-stats monero-blockchain-usage monerod monero-gen-ssl-cert monero-gen-trusted-multisig monero-wallet-cli monero-wallet-gui monero-wallet-rpc /archive/$ARCH/$TAG
set -e
for i in monero-blockchain-ancestry monero-blockchain-depth monero-blockchain-export monero-blockchain-import monero-blockchain-mark-spent-outputs monero-blockchain-prune monero-blockchain-prune-known-spent-data monero-blockchain-stats monero-blockchain-usage monerod monero-gen-ssl-cert monero-gen-trusted-multisig monero-wallet-cli monero-wallet-gui monero-wallet-rpc;
do
    echo -n -e ".PHONY: install\n" > Makefile
    echo -n -e "install:\n" >> Makefile
    echo -n -e "\tmkdir -p /bin || true\n" >> Makefile
    echo -n -e "\tcp $i /bin/$i\n" >> Makefile
    if [[ "$i" == "monero-wallet-gui" ]];
    then
        echo pwd
        pwd
        echo -n -e "\tmkdir -p /usr/share/icons/hicolor || true\n"
        echo -n -e "\tcp ../../../../icons/128x128-monero-wallet-gui.png /usr/share/icons/hicolor/128x128/apps/monero-wallet-gui.png\n"
        echo -n -e "\tcp ../../../../icons/16x16-monero-wallet-gui.png /usr/share/icons/hicolor/16x16/apps/monero-wallet-gui.png\n"
        echo -n -e "\tcp ../../../../icons/24x24-monero-wallet-gui.png /usr/share/icons/hicolor/24x24/apps/monero-wallet-gui.png\n"
        echo -n -e "\tcp ../../../../icons/256x256-monero-wallet-gui.png /usr/share/icons/hicolor/256x256/apps/monero-wallet-gui.png\n"
        echo -n -e "\tcp ../../../../icons/32x32-monero-wallet-gui.png /usr/share/icons/hicolor/32x32/apps/monero-wallet-gui.png\n"
        echo -n -e "\tcp ../../../../icons/48x48-monero-wallet-gui.png /usr/share/icons/hicolor/48x48/apps/monero-wallet-gui.png\n"
        echo -n -e "\tcp ../../../../icons/64x64-monero-wallet-gui.png /usr/share/icons/hicolor/64x64/apps/monero-wallet-gui.png\n"
        echo -n -e "\tcp ../../../../icons/96x96-monero-wallet-gui.png /usr/share/icons/hicolor/96x96/apps/monero-wallet-gui.png\n"
    fi
    goprod \
        -binname="$i" \
        -buildcmd="true" \
        -combo="linux/$COMBOARCH" \
        -version=${TAG:1}
done
set +e
mkdir -p /apt/$ARCH/$TAG
cp $(find . -name "*.deb") /apt/$ARCH/$TAG
