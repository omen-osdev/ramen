#!/bin/bash

#set repo_url to the repository url
repo_url="git@github.com:omen-osdev/omen.git"
branch="develop"
vm_port="6644"

echo "██▀███   ▄▄▄       ███▄ ▄███▓▓█████  ███▄    █  "
echo "▓██ ▒ ██▒▒████▄    ▓██▒▀█▀ ██▒▓█   ▀  ██ ▀█   █ "
echo "▓██ ░▄█ ▒▒██  ▀█▄  ▓██    ▓██░▒███   ▓██  ▀█ ██▒"
echo "▒██▀▀█▄  ░██▄▄▄▄██ ▒██    ▒██ ▒▓█  ▄ ▓██▒  ▐▌██▒"
echo "░██▓ ▒██▒ ▓█   ▓██▒▒██▒   ░██▒░▒████▒▒██░   ▓██░"
echo "░ ▒▓ ░▒▓░ ▒▒   ▓▒█░░ ▒░   ░  ░░░ ▒░ ░░ ▒░   ▒ ▒ "
echo "  ░▒ ░ ▒░  ▒   ▒▒ ░░  ░      ░ ░ ░  ░░ ░░   ░ ▒░"
echo "  ░░   ░   ░   ▒   ░      ░      ░      ░   ░ ░ "
echo "   ░           ░  ░       ░      ░  ░         ░ "
echo ""
echo "RAMEN: OMEN OS Development Environment"
echo "By Tretorn"
echo ""
echo "Current repository: $repo_url [$branch]"
echo "VMPORT: $vm_port"

#check if running with privileges, if so warn the user that it's not necessary
if [ "$EUID" -eq 0 ]; then
  echo "You are running this script as root, this is not necessary and can cause problems."
  read -p "Do you want to continue? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

#check if the flag -h is present
if [ "$1" == "-h" ]; then
  echo "Usage: ./ramen.sh [options]"
  echo "Options:"
  echo "  -h  Show this help message and exit"
  echo "  -d  Run the image in debug mode"
  echo "  -c  Clean up the environment"
fi

#check if the flag -d is present
if [ "$1" == "-d" ]; then
  debug="true"
else
  debug="false"
fi

#check if the flag -c is present
if [ "$1" == "-c" ]; then
  echo "Cleaning up..."
  sudo rm -rf $(pwd)/build
  sudo rm -rf $(pwd)/omen

  if [ -d "$(pwd)/build" ]; then
    echo "\e[1;31mError: build folder could not be deleted.\e[0m" >&2
    exit 1
  fi

  if [ -d "$(pwd)/omen" ]; then
    echo "\e[1;31mError: omen folder could not be deleted.\e[0m" >&2
    exit 1
  fi

  stop_containers=$(docker ps -a | grep 'omen' | awk '{print $1}')
  if [ -n "$stop_containers" ]; then
    echo "Stopping containers... $stop_containers"
    docker stop $(docker ps -a | grep 'omen' | awk '{print $1}')
  fi

  delete_images=$(docker images | grep 'omen')
  if [ -n "$delete_images" ]; then
    echo "Deleting images... $delete_images"
    docker rmi $(docker images | grep 'omen' | awk '{print $3}')
  fi

  echo -e "\e[1;34mOK\e[0m"
  exit 0
fi

echo "Checking for dependencies (git, docker, md5sum, losetup)..."
if ! [ -x "$(command -v git)" ]; then
  echo "\e[1;31mError: git is not installed.\e[0m" >&2
  exit 1
fi

if ! [ -x "$(command -v docker)" ]; then
  echo "\e[1;31mError: docker is not installed.\e[0m" >&2
  exit 1
fi

if ! [ -x "$(command -v md5sum)" ]; then
  echo "\e[1;31mError: md5sum is not installed.\e[0m" >&2
  exit 1
fi

if ! [ -x "$(command -v losetup)" ]; then
  echo "\e[1;31mError: losetup is not installed.\e[0m" >&2
  if [ -x "/sbin/losetup" ]; then
    echo "losetup exists in /sbin/losetup, creating a symlink..."
    sudo ln -s /sbin/losetup /usr/bin/losetup
  else
    exit 1
  fi
  exit 1
fi

#Print ok in blue
echo -e "\e[1;34mOK\e[0m"

echo "Cleaning up..."
sudo rm -rf $(pwd)/build

#make sure the buld and omen folders are deleted
if [ -d "$(pwd)/build" ]; then
  echo "\e[1;31mError: build folder could not be deleted.\e[0m" >&2
  exit 1
fi

echo -e "\e[1;34mOK\e[0m"

echo "Making sure the repository exists..."
if [ ! -d "$(pwd)/omen" ]; then
  echo "The repository doesn't exist, cloning it..."
  git clone $repo_url $(pwd)/omen --depth 1 --branch $branch

  if [ ! -d "$(pwd)/omen/.git" ]; then
    echo "\e[1;31mError: omen folder does not exist or does not contain a .git folder.\e[0m" >&2
    exit 1
  fi
fi

if [ ! -d "$(pwd)/omen/.git" ]; then
  echo "\e[1;31mError: omen folder does not exist or does not contain a .git folder.\e[0m" >&2
  exit 1
fi

echo -e "\e[1;34mOK\e[0m"

echo "Creating build environment..."
docker build -t omen/builder -f Dockerfile.builder .

if [ $? -ne 0 ]; then
  echo "\e[1;31mError: Docker image was not built.\e[0m" >&2
  exit 1
fi

echo -e "\e[1;34mOK\e[0m"

echo "Building image"
mkdir -p $(pwd)/build
echo "" > $(pwd)/build/omen.img
echo "" > $(pwd)/build/kernel.elf
loop=$(losetup -f)
if [ -z "$loop" ]; then
  echo "\e[1;31mError: Can't build, no loop devices available.\e[0m" >&2
  exit 1
fi
echo -e "\e[1;33m[INFO] Using loop device $loop\e[0m"

docker run --privileged -v /dev:/dev --rm -v $(pwd)/omen:/omen -v $(pwd)/build/omen.img:/build/omen.img -v $(pwd)/build/kernel.elf:/build/kernel.elf omen/builder

if [ $? -ne 0 ]; then
  echo "\e[1;31mError: Image was not built.\e[0m" >&2
  exit 1
fi

if [ ! -f "$(pwd)/build/omen.img" ]; then
  echo "\e[1;31mError: omen.img does not exist.\e[0m" >&2
  exit 1
fi

if [ ! -f "$(pwd)/build/kernel.elf" ]; then
  echo "\e[1;31mError: kernel.elf does not exist.\e[0m" >&2
  exit 1
fi

if [ "$(md5sum $(pwd)/build/omen.img | awk '{print $1}')" == "68b329da9893e34099c7d8ad5cb9c940" ]; then
  echo "\e[1;31mError: Image is empty.\e[0m" >&2
  exit 1
fi

echo -e "\e[1;34mOK\e[0m"

echo "Creating the images..."
docker build -t omen/debugenv -f Dockerfile.debugenv .

if [ $? -ne 0 ]; then
  echo "\e[1;31mError: Dockerfile.debugenv image was not built.\e[0m" >&2
  exit 1
fi

docker build -t omen/runenv -f Dockerfile.runenv .

if [ $? -ne 0 ]; then
  echo "\e[1;31mError: Dockerfile.runenv image was not built.\e[0m" >&2
  exit 1
fi

echo -e "\e[1;34mOK\e[0m"

echo "Running the image..."

if [ "$debug" == "true" ]; then
  docker run --detach --name omen-debugenv --rm --privileged -e BOOT_MODE='uefi' -e ARGUMENTS='-cpu qemu64 -d cpu_reset -no-reboot -no-shutdown -machine q35 -m 4G -S -s' -p $vm_port:8006 --device=/dev/kvm --cap-add NET_ADMIN --volume "./build/omen.img:/boot.img:rw"  --volume "./build/kernel.elf:/kernel.elf:ro" --volume "./omen:/omen:ro" omen/debugenv
else
  docker run --detach --name omen-runenv --rm -e BOOT_MODE='uefi' -e ARGUMENTS='-cpu qemu64 -d cpu_reset -no-reboot -no-shutdown -machine q35 -m 4G' -p $vm_port:8006 --device=/dev/kvm --cap-add NET_ADMIN --volume "./build/omen.img:/boot.img:rw" omen/runenv
fi

if [ $? -ne 0 ]; then
  echo "\e[1;31mError: Image is not running.\e[0m" >&2
  exit 1
fi

echo -e "\e[1;34mOK\e[0m"
echo "Image running, go to http://localhost:$vm_port to access it"

if [ "$debug" == "true" ]; then
  echo "Launching the debugger..."
  docker exec -it omen-debugenv gdb --nx --command=/debug.gdb
fi

#remove docker container
if [ "$debug" == "true" ]; then
  docker stop omen-debugenv
else
  #wait for enter
  read -p "Press enter to stop the container"
  docker stop omen-runenv
fi