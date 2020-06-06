#!/bin/bash

set -e

#resources folder
refo=resources

#boot.tar.gz will stay the same so i am leaving the sum here
bootsum=7523e8cd9c3e97bc3200d9948b7ab36373c754130767d19faf57a748bb49a38e

function help()
{
   echo "This simple script will convert any OTA to one with a new update engine, SSH key, and build number. Experimental."
   echo "[-h|-o {dir}|-n {dir}]"
   echo "-h         This message"
   echo "-n {dir}   directory to any latest.ota over 1.0/under 1.6. will turn into a 1.8.0.4000d which will work with chipper-dev"
   echo "-t {dir}   directory to any latest.ota you want to just beta test. it will only edit update engine/ssh key and won't mess with version number."
   echo "-m {dir}   directory to any latest.ota you want to mount"
   echo "-b {dir}   directory to an apq8009-robot-sysfs.img you want to build"
   echo "-mn {dir} this will mount an OTA's sysfs and copy over update-engine, ssh key, and version stuff"
   echo "-mt {dir} this will mount an OTA's sysfs and copy over update-engine and ssh key"
   exit 0
}

trap ctrl_c INT                                                                 
                                                                                
function ctrl_c() {
    echo -e "\n\nStopping"
    exit 1 
}

function copytest()
{
  echo "Copying files over"
  sudo cp ${refo}/update-engine ${dir}edits/anki/bin/
  sudo cp ${refo}/authorized_keys ${dir}edits/etc/ssh/
}

function copynew()
{
  sudo cp ${refo}/update-engine ${dir}edits/anki/bin/
  sudo cp ${refo}/authorized_keys ${dir}edits/etc/ssh/
  sudo cp ${refo}/os-version ${dir}edits/etc/
  sudo cp ${refo}/os-version-base ${dir}edits/etc/
  sudo cp ${refo}/os-version-code ${dir}edits/etc/
  sudo cp ${refo}/version ${dir}edits/anki/etc/
  sudo cp ${refo}/build.prop ${dir}edits/
}

function mount()
{
  echo "Converting OTA in $dir!"
  sudo mv ${dir}latest.ota ${dir}latest.tar
  sudo tar -xf ${dir}latest.tar --directory ${dir}
  sudo mkdir ${dir}edits
  sudo openssl enc -d -aes-256-ctr -pass file:${refo}/ota.pas -md md5 -in ${dir}apq8009-robot-sysfs.img.gz -out ${dir}apq8009-robot-sysfs.img.dec.gz
  echo "Decompressing. This may take a minute."
  sudo gzip -d ${dir}apq8009-robot-sysfs.img.dec.gz
  echo "Rename img.dec to mountable img"
  sudo mv ${dir}apq8009-robot-sysfs.img.dec ${dir}apq8009-robot-sysfs.img
  echo "Mounting IMG"
  sudo mount -o loop,rw,sync ${dir}apq8009-robot-sysfs.img ${dir}edits
  echo "Deleting GZ file for build function to work"
  sudo rm ${dir}apq8009-robot-sysfs.img.gz
}

function build()
{
  echo "Compressing. This may take a minute."
  sudo gzip -k ${dir}apq8009-robot-sysfs.img
  sudo mkdir ${dir}final
  sudo openssl enc -e -aes-256-ctr -pass file:${refo}/ota.pas -md md5 -in ${dir}apq8009-robot-sysfs.img.gz -out ${dir}final/apq8009-robot-sysfs.img.dec.gz
  sudo mv ${dir}final/apq8009-robot-sysfs.img.dec.gz ${dir}/final/apq8009-robot-sysfs.img.gz
  sudo umount ${dir}edits
  echo "Figuring out SHA256 sum and putting it into manifest."
  sysfssum=$(sha256sum ${dir}apq8009-robot-sysfs.img | head -c 64)
  sudo printf '%s\n' '[META]' 'manifest_version=1.0.0' 'update_version=1.8.0.4000d' 'ankidev=1' 'num_images=2' '[BOOT]' 'encryption=1' 'delta=0' 'compression=gz' 'wbits=31' 'bytes=13795328' 'sha256='${bootsum} '[SYSTEM]' 'encryption=1' 'delta=0' 'compression=gz' 'wbits=31' 'bytes=608743424' 'sha256='${sysfssum} >${refo}/manifest.ini
  echo "Putting into tar."
  sudo tar -C ${refo} -cvf ${refo}/temp.tar manifest.ini
  sudo tar -C ${refo} -rf ${refo}/temp.tar apq8009-robot-boot.img.gz
  sudo cp ${refo}/temp.tar ${dir}final/
  sudo tar -C ${dir}final -rf ${dir}final/temp.tar apq8009-robot-sysfs.img.gz
  sudo mv ${dir}final/temp.tar ${dir}final/latest.ota
  echo "Removing some temp files."
  sudo rmdir ${dir}edits
  sudo rm ${dir}apq8009-robot-sysfs.img.gz
  sudo rm ${dir}apq8009-robot-boot.img.gz
  sudo rm ${dir}manifest.ini
  sudo rm ${dir}manifest.sha256
  sudo rm ${dir}final/apq8009-robot-sysfs.img.gz
  sudo rm ${refo}/manifest.ini
  sudo rm ${refo}/temp.tar
  echo "Renaming original OTA back to OTA"
  sudo mv ${dir}latest.tar ${dir}latest.ota
  echo "Done! Output should be in ${dir}final/latest.ota!"
}

if [ $# -gt 0 ]; then
    case "$1" in
	-h)
	    help
            ;;
        -n)
            dir=$2
	    mount
            copynew
            build
            ;;
	-t) 
	    dir=$2
	    mount
	    copytest
            build
	    ;;
	-m) 
	    dir=$2
	    mount
	    ;;
	-b) 
	    dir=$2
	    build
	    ;;
	-mn) 
	    dir=$2
	    mount
	    copynew
	    ;;
	-mt) 
	    dir=$2
	    mount
            copytest
	    ;;
    esac
fi
