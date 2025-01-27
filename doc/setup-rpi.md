### Logging in to the Raspberry Pi

From the idun-shell, you can access Linux to setup networking and other services. You will be logged in as user `idun` automatically, and you will have `sudo` ability. The default password is "idun", and the default root password is "Commodore".

The idun-cartridge ships with `ssh` and the idun-filebrowser enabled. You should attach the cartridge to your network using wired Ethernet and/or setup the WiFi connection.

If your network supports `.local` host names, then your cartridge should appear on the network as host "idunpi" or "idunpi.local". If not, then use the Linux prompt to discover the cartridge ip address. Then, use `ssh` or browse to port 8080 for the idun-filebrowser.

### Resize file system / extend root partition

After imaging the minimal image, use one of:
1. Arch Linux "Disks" GUI
2. Linux "GParted" GUI
3. Linux `fdisk` and `resize2fs` tools.
4. "GParted Live" boot disk on PC

In all cases, BE VERY CAREFUL! It is easy to lose all the data on your device if you mess up using `fdisk` or another partition tool.

It IS POSSIBLE to expand the file system on the idun-cartridge directly, using the Linux terminal and `fdisk` + `resize2fs`, which are included with the minimal image. Try this at your own RISK!

1. First, use `fdisk` to delete the 2nd partition, and re-create the 2nd partition using the maximum available space on your SD card.
2. `sudo fdisk /dev/mmcblk0`
3. At the fdisk prompt, type "d"<return>, then "2"<return> to delete 2nd partition.
4. Then "n"<return>, "p"<return>, "2"<return> to re-create a primary partition #2. Choose the default starting and ending blocks AND select "N" to NOT REMOVE the partition's signature.
5. Finally "w" to write the updated partition table to disk. You must reboot for the change to take effect.
6. `sudo reboot now`
7. After the reboot and back at the Linux terminal: `sudo resize2fs /dev/mmcblk0p2`.
8. If all went well, then `df -h` should show max. space available for your SD card on the root partition.

### Configure Networking after connecting cartridge to Commodore

Enable wired USB Ethernet
```
ping www.google.com
ping idunpi (from another host on the LAN)
networkctl list
ip link set up enuX
```
[Networking Wiki](https://wiki.archlinux.org/title/Network_configuration)

Enable Wi-Fi
```
sudo systemctl enable connman
sudo systemctl start connman
```
Use connmanctl CLI command to configure wi-fi

[Connman Wiki](https://wiki.archlinux.org/title/ConnMan)


### Build open source code (optional)

1. Clone this repository to your idun home directory: `git clone https://github.com/idun-project/idun-cartridge`
2. `cd idun-cartridge && ./setup.sh` -installs additional packages such as acme and idun-zcc.
3. `cd cbm && make` -builds cartridge software and updates the `sys` directroy (`z:` device in the idun-shell)

### Emulation of the cartridge on the Raspberry Pi (optional)

1. Install patched VICE emulator- `sudo pacman -Sy idun-vice`, and see [idun-vice](https://github.com/idun-project/idun-vice).
