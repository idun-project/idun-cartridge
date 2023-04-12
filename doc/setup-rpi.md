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


### Download (or `git clone`) open source code

1. `wget https://github.com/idun-project/idun-cartridge/archive/refs/tags/latest.tar.gz` -or- `git clone https://github.com/idun-project/idun-cartridge`
2. `tar xvfz latest.tar.gz`, if you downloaded the archive.
3. `cd idun-cartridge && ./build.sh`

### (Optional)

1. Install patched VICE emulator from [idun-vice](https://github.com/idun-project/idun-vice).
