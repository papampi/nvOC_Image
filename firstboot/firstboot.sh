#!/bin/bash

export DISPLAY=:0             # needed by dconf in profile-select.sh
export FIRSTBOOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export SMALLFAT="/media/m1/12D3-A869"

( # logging start

  echo "$(date) - nvOC FirstBoot start"
  echo ""
  
  # TODO: loop waiting for internet connectivity
  
  echo " + Looking for the small fat partition"
  if ! mountpoint "${SMALLFAT}"
  then
    echo "  ++ mounting fat partition"
    sudo mkdir -p ${SMALLFAT}
    sudo mount /dev/sda1 ${SMALLFAT}
  fi
  echo ""
  
  echo " + Parsing firstboot.json"
  NVOC_BRANCH="release"
  NVOC="/home/m1/NVOC/mining"
  AUTO_EXPAND="false"
  RECOMPILE_MINERS="false"
  if [[ ! -e ${SMALLFAT}/firstboot.json ]] && jq . ${SMALLFAT}/firstboot.json
  then
    echo "  ++ firstboot.json not found or content is invalid, falling back to defaults"
  else
    if [[ $(jq -r .nvoc_branch ${SMALLFAT}/firstboot.json) != "" ]]
    then
      NVOC_BRANCH="$(jq -r .nvoc_branch ${SMALLFAT}/firstboot.json)"
    fi
    if [[ $(jq -r .recompile_miners ${SMALLFAT}/firstboot.json) != "" ]]
    then
      RECOMPILE_MINERS=$(jq -r .recompile_miners ${SMALLFAT}/firstboot.json)
    fi
    if [[ $(jq -r .auto_expand ${SMALLFAT}/firstboot.json) != "" ]]
    then
      AUTO_EXPAND=$(jq -r .auto_expand ${SMALLFAT}/firstboot.json)
    fi
    if [[ $(jq -r .nvoc_path ${SMALLFAT}/firstboot.json) != "" ]] && mkdir -p "$(jq -r .nvoc_path ${SMALLFAT}/firstboot.json)"
    then
      NVOC=$(jq -r .nvoc_path ${SMALLFAT}/firstboot.json)
    fi
  fi
  echo "  ++ selected branch: '${NVOC_BRANCH}'"
  echo "  ++ nvOC will install to: '${NVOC}'"
  echo ""
  
  echo " + Setting 2unix as custom-command for gnome-terminal 'mining' profile"
  bash ./profile-manager.sh set-by-name mining custom-command "'bash \'${NVOC}/2unix\''"
  echo ""
  
  echo " + Cloning '${NVOC_BRANCH}' nvOC branch into ${NVOC}"
  NVOC_REPO="https://github.com/papampi/nvOC_by_fullzero_Community_Release"
  echo "  ++ Checking if selected branch actually exists..."
  if ! git ls-remote --exit-code --heads  ${NVOC_REPO} ${NVOC_BRANCH}
  then
    echo "   +++ Selected branch not found, falling back to 'release'"
    NVOC_BRANCH="release"
  fi
  rm -rf ${NVOC}
  git clone --depth 1 --branch ${NVOC_BRANCH} ${NVOC_REPO} ${NVOC}
  cd $NVOC
  git submodule update --init --depth 1 --remote miners
  cd miners
  if [[ $RECOMPILE_MINERS == false ]]
  then
    bash nvOC_miner_update.sh --no-recompile
  else
# DO NOT INDENT - BEGIN
    bash nvOC_miner_update.sh <<EOF
y${RECOMPILE_MINERS}
EOF
# DO NOT INDENT - END
  fi
  cd $FIRSTBOOT
  echo ""
  
  echo " + Looking for your customized 1bash"
  if [[ -e "${SMALLFAT}/1bash" ]]
  then
    sudo cp "${SMALLFAT}/1bash" "${NVOC}/1bash"
    sudo dos2unix ${NVOC}/1bash
  else
    echo "  ++ Cannot find your 1bash, will use the default template instead"
    cp "${NVOC}/1bash.template" "${NVOC}/1bash"
  fi
  echo ""
  
  if [[ $AUTO_EXPAND == true ]]
  then
    echo " + Preparing root partition expansion"
    sudo bash ./expand_rootfs.sh
    echo ""
  fi
  
  echo " + Determining if firstboot can be disabled"
  if [[ -e ${NVOC}/2unix && -e ${NVOC}/1bash ]]
  then
    echo "  ++ SUCCESS: switching default gnome-terminal profile from 'firstboot' to 'mining'"
    echo "  ++ This script won't run again. Good luck!"
    bash ./profile-manager.sh switch-by-name mining
  else
    echo "  ++ FAILURE: keeping firstboot as default gnome-terminal profile"
    echo "  ++ This script will run again on the next reboot."
    echo "  ++ Check your fat partition contents or internet connectivity."
  fi
  echo ""
  
  echo "$(date) - Done. Rebooting in 5 seconds.."

) | tee -a firstboot.log # logging end

cp -f firstboot.log ${SMALLFAT}/firstboot.log
sleep 5
sudo reboot