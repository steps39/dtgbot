# DTGBOT Telegram Bot for Domoticz

This branch is the version of DTGBOT with much more errorchecking to increase stability and logging.<br>
It combines the Menus at the Bottom and the Inline Menu versions.<br>
It now uses standard ssl and LUA install packages in stead of the previous compiled usr versions.<br>
Works much more stable and installs on the new Debian version. 

## Setup

### Debian & Ubuntu

   1. LUA:  sudo apt install lua5.2
   1. JSON: sudo apt install lua-json
   1. HTTP: sudo apt install lua-socket
   1. HTTPS: sudo apt install lua-sec

### Windows

   1. JSON: download **dkjson.lua** from http://dkolf.de/src/dkjson-lua.fsl/home and rename it to **json.lua**
   1. HTTPS: ??

### Service setup for DTGBOT

   1. Edit systemd-dtgbot.sh:
      * Fill the proper info in the different fields
   1. copy dtgbot.service to /etc/systemd/system/dtgbot.service
   1. enable the service:sudo systemctl enable dtgbot
   1. start the service: sudo systemctl start dtgbot

## DTGMenu screenshots:

  ![Alt text](/img/Menu1.jpg?raw=true "DTGMenu")
  ![Alt text](/img/Menu2.jpg?raw=true "DTGMenu")
