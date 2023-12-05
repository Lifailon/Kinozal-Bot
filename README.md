# <img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/kinozal-bot-ico-256px.png" width="25" /> Kinozal-Bot

📢 **[Описание на русском](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/README_RU.md)**

🍿 Project purpose:

- Generation of new posts with sending to Telegram channel based on new publications in tracker **[Kinozal](https://kinozal.tv)** with filtering by rating and year of release.
- Automation of the process of delivering content to the TV using only the phone. Selection (proposed from the post of the channel or manual search in the bot) and downloading of a suitable torrent-file (using the proposed recommended links to each publication), setting to download in qBittorrent with the ability to manage and track the status, as well as changing the priority of downloading files, and synchronization of content with Plex Media Server.

### 📚 Stack

- **Kinozal**: read RSS feed, retrieve data from html (no api), search and filter content, download torrent files;
- **Optional**: any VPN client application and/or proxy server for access to Kinozal;
- **Telegram api**: sending messages to the channel, reading (commands only) and sending reply messages in menu format (keyboard);
- **qBittorrent api**: download data and torrent files and manage data (pause, delete, change priority);
- **Plex Media Server api**: synchronize data and get information about content of sections and child files.

> It is planned to add additional information using third-party api (e.g. tmdb or videocdn) and disk size (e.g. Open Hardware Monitor via web api).

### 🎉 Example

<a href="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/status_torrent_and_search_kinozal.jpg"><img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/status_torrent_and_search_kinozal.jpg" width="400"/></a>
<a href="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/info_torrent.jpg"><img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/info_torrent.jpg" width="400"/></a>
<a href="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/find_kinozal.jpg"><img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/find_kinozal.jpg" width="400"/></a>
<a href="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/plex_folder.jpg"><img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/plex_folder.jpg" width="400"/></a>

![](image/telegram-example.mp4)

### 🚀 Install

All settings are set in the configuration file: **kinozal-bot.conf** 📑.

1. Register an account in **Kinozal** and fill in the parameters in the configuration:

`KZ_PROFILE="id_you_profile"` - used to get information from the profile \
`KZ_USER="LOGIN"` - used at the stage of torrent file downloading and obtaining information in the profile \
`KZ_PASS="PASSWORD"`

2. If you do not have direct access to Kinozal, you can use a VPN or proxy server (I use **Handy Cache** in conjunction with **VPN Hotspot Shield** in Split Tunneling mode on Windows) through which the bot can proxy its requests.

`PROXY="True"` - enable the use of a proxy server in curl-requests when accessing Kinozal \
`PROXY_ADDR="http://192.168.3.100:9090"` \
`PROXY_USER="LOGIN"` \
`PROXY_PASS="PASSWORD"`

3. Install torrent client **qBittorrent**, enable **Web interface** in the settings.

`QB_ADDR="http://192.168.3.100:8888"` - specify the final URL, which specifies the IP address of the machine running qBittorrent and port (set in the settings) \
`QB_USER="LOGIN"` - is specified in the **Authentication** field in the **Web Interface** settings \
`QB_PASS="PASSWORD"`

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/qbittorrent-settings.jpg)

4. Install **Plex Media Server** (in my case installed where the qBittorrent client is on my Windows machine) and **get the key/token** to access the REST API. I couldn't find a way to get the key in the web interface, so I captured the token in the network log url request (X-Plex-Token=) during authorization using **Development Tools** (no time limit).

`PLEX_ADDR="http://192.168.3.100:32400"` \
`PLEX_TOKEN="TOKEN"`

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/plex-token.jpg)

5. To run the bot, place the **kinozal-bot.conf** configuration file next to the script (log, cookie and torrent file storage paths are set in the configuration) and use the interpreter 🐧 to run it (root privileges are not required):

```bash
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh
```

On startup, the path to the log will be given. There are 2 main threads (processes) and up to 20 child threads running.

**Stop the service:**

```bash
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh stop
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh status
```
