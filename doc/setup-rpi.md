### Logging in to the Raspberry Pi

From the Idun shell, you can access Linux to setup networking and other services. You will be logged in as user `idun` automatically, and you will have `sudo` ability. The default password is "idun", and the default root password is "Commodore".

The idun-cartridge ships with `ssh` and the idun-filebrowser enabled. You should attach the cartridge to your network using wired Ethernet and/or setup the WiFi connection.

If your network supports `.local` host names, then your cartridge should appear on the network as host "idunpi" or "idunpi.local". If not, then use the Linux prompt to discover the cartridge ip address (`ip addr`). Then, use `ssh` or browse to `http://idunpi.local:80` for the idun-filebrowser.

### Resize file system / extend root partition

Idun includes a command to expand your filesystem to use the full space on your SD card. It is a two step process that automatically reboots the RasPi.

1. Run `sudo resize-fs` from the shell.
2. Wait for the reboot to complete, which will leave you at the BASIC prompt.
3. Reset the cartridge. The disk space displayed on the shell screen should reflect the change.

### Configure Networking after connecting cartridge to Commodore

1. If you have an Ethernet port on your Pi, or use a USB dongle that provides one, the networking over wired Ethernet should "just work." You can check the status and see your DHCP assigned IP with the command `ip addr`.
2. If you intend to use WiFi, you can set it up by running `sudo setup interfaces` from the shell. The interface you want is `wlan0`. It will show a list of access points and prompt you for your WiFi password. _Note_: You sometimes need to do a reboot (`sudo reboot`) after you complete the setup to ensure you are connected.

### Build open source code (optional)

1. Clone this repository to your idun home directory: `git clone https://github.com/idun-project/idun-cartridge`
2. `cd idun-cartridge && ./setup.sh` -installs additional packages such as bastext and idun-zcc
3. `cd cbm && make` -builds cartridge software
4. `sudo make install` from `cbm` directory to make it active

### Emulation of the cartridge on the Raspberry Pi (optional)

Install the modified idun-vice emulator using `sudo apk add idun-vice`, and see [idun-vice](https://github.com/idun-project/idun-vice).
