# <img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/ico/kinozal-bot-256px.png" width="25" /> Kinozal-Bot

![GitHub release (with filter)](https://img.shields.io/github/v/release/lifailon/kinozal-bot?color=<green>)
![GitHub top language](https://img.shields.io/github/languages/top/lifailon/kinozal-bot)
![GitHub last commit (by committer)](https://img.shields.io/github/last-commit/lifailon/kinozal-bot)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/lifailon/kinozal-bot)
![GitHub License](https://img.shields.io/github/license/lifailon/kinozal-bot?color=<green>) \
[![Kinozal-News](https://img.shields.io/github/v/release/lifailon/kinozal-bot?label=Telegram+Kinozal-News&logo=Telegram&style=social)](https://t.me/kinozal_news)

🔈 **[Описание на русском](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/README_RU.md)**

📝 **[Публикация на Habr](https://habr.com/ru/articles/782028/)**

🍿 Project purpose:

- Generation of new posts with sending to Telegram channel based on new publications in tracker **[Kinozal](https://kinozal.tv)** with filtering by rating and year of release.
- Automation of the process of delivering content to the TV using only the phone. Selection (proposed from the post of the channel or manual search in the bot) and downloading of a suitable torrent-file (using the proposed recommended links to each publication), setting to download in qBittorrent with the ability to manage and track the status, as well as changing the priority of downloading files, and synchronization of content with Plex Media Server, as well as viewing the contents of sections and directories.

## 📚 Stack

- **Kinozal**: read RSS feed, retrieve data from html (no api), search and filter content, download torrent files;
- **Telegram api**: sending messages to the channel, reading (commands only) and sending reply messages in menu format (keyboard);
- **qBittorrent api**: download data from torrent files and manage data (pause, delete, change priority);
- **Plex Media Server api**: synchronize data and get information about content of sections and child files.

**Optional:**

- Any **VPN client application and/or proxy server** for access to Kinozal;
- **[Kinopoisk API](https://github.com/mdwitr0/kinopoiskdev)**: get information about the movie and trailers in youtube (**Description Kinopoisk** button), actor links in Kinopoisk and filmography from Kinozal (added in version 0.4.2);
- **[WinAPI](https://github.com/Lifailon/WinAPI)**: stop and start Plex and qBittorrent applications, manage directories and files, get system health metrics (to be added in the next version).

## 🎉 Example

An active channel with publications: 📢 **[Kinozal-News](https://t.me/kinozal_news)** 

<img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.2/1-kinozal-info.jpg" width="400"/></a>
<img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.2/8-plex-content.jpg" width="400"/></a>
<img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.2/2-kinopoisk-description.jpg" width="400"/></a>
<img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.2/7-kinozal-profile-and-torrent-files.jpg" width="400"/></a>
<img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.2/3-actor-list.jpg" width="400"/></a>
<img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.2/4-actor-info.jpg" width="400"/></a>
<img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.2/5-torrent-status.jpg" width="400"/></a>
<img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.2/6-torrent-files.jpg" width="400"/></a>

## 🚀 Install

For the bot to work, you need to prepare your own environment. All settings of connection and filtering of new publications are set in the configuration file: **kinozal-bot.conf** 📑.

1. Register an account in **Kinozal** and fill in the parameters in the configuration:

`KZ_PROFILE="id_you_profile"` - used to get information from the profile \
`KZ_USER="LOGIN"` - used at the stage of torrent file downloading and obtaining information in the profile \
`KZ_PASS="PASSWORD"`

2. If you do not have direct access to Kinozal, you can use a VPN or proxy server (I use **Handy Cache** in conjunction with **VPN Hotspot Shield in Split Tunneling mode** based on the Windows operating system) through which the bot can proxy its requests.

`PROXY="True"` - enable the use of a proxy server in curl-requests when accessing Kinozal \
`PROXY_ADDR="http://192.168.3.100:9090"` \
`PROXY_USER="LOGIN"` \
`PROXY_PASS="PASSWORD"`

3. Create a bot in **[@botfather](https://t.me/BotFather)** using an intuitive interface and get its API token. Also create your channel for new publications in Kinozal and separately start your chat with the previously created bot to interact with the services. Get the id of the channel (starts with "-") and chat using the bot: **[Get My ID](https://t.me/getmyid_arel_bot)** and fill in the parameters:

`TG_TOKEN="6873341222:AAFnVgfavenjwbKutRwROQQBya_XXXXXXXX"` - used to read and send messages to Telegram chatbot \
`TG_CHANNEL="-1002064864175"` - used to send messages to the channel \
`TG_CHAT="8888888888,999999999"` - id of all chat rooms for access to the bot (to be filled in with commas), further id can be obtained in the log output from requests of new clients requests \
`TG_BOT_NAME="lifailon_ps_bot"` - used to link to the bot from the channel

4. Install torrent client **qBittorrent** and enable **Web interface** in the settings.

`QB_ADDR="http://192.168.3.100:8888"` - specify the final URL, which specifies the IP address of the machine running qBittorrent and port (set in the settings) \
`QB_USER="LOGIN"` - is specified in the **Authentication** field in the **Web Interface** settings \
`QB_PASS="PASSWORD"`

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/settings/qbittorrent-settings.jpg)

> Add a directory with the contents of the Plex contact to be downloaded by default in qBittorrent

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/settings/qbittorrent-default-directory.jpg)

5. Install **Plex Media Server** (in my case installed where the qBittorrent client is on my Windows machine) and **get the key/token** to access the REST API. I couldn't find a way to get the key in the web interface, so I captured the token in the network log url request (X-Plex-Token=) during authorization using **Development Tools** (no time limit).

`PLEX_ADDR="http://192.168.3.100:32400"` \
`PLEX_TOKEN="TOKEN"`

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/settings/plex-token.jpg)

> Add the content directory to the Plex server to which the qBittorrent client is configured by default

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/settings/plex-add-directory.jpg)

6. **Get your API token to access the Kinopoisk database** (unofficial, from IMDb), using a Telegram bot **[@kinopoiskdev_bot](https://t.me/kinopoiskdev_bot)** (200 requests per day in the free version).

`KINOPOISK_API="True"` - information about the actor will be retrieved from the Kinopoisk database (if **False**, the link to Kinozal will be retrieved). \
`KINOPOISK_TOKEN="XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX"`

## 🐧 Start

Check that you have **[jq](https://github.com/jqlang/jq)** installed:

```bash
apt install jq
jq --version
jq-1.6
```

To run the bot on a remote machine (I use Ubuntu Server 22.04) place the configuration file **kinozal-bot.conf** next to the script (the paths for storing the log file, cookies and torrent files are set in the configuration) and use the 🐧 interpreter to run it (root privileges are not required):

```bash
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh
```

On startup, the path to the log will be given. There are 2 main threads (processes) and up to 20 child threads running.

**Stop the service:**

```bash
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh stop
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh status
```

## 📌 Commands

A list of all available commands (except `/search`) are automated through the bot menu.

`/search` - Search in Kinozal by title (takes the year of release for filtering at the beginning of the query) \
`/profile ` - Profile Kinozal (the number of available for download torrent files, download and upload statistics, time sid and peer) \
`/torrent_files` - List of downloaded torrent files (with the ability to delete files) \
`/status` - qBittorrent manager (list and status of all current torrents added to the torrent client) \
`/plex_info` - Plex content (list of available sections for selection) \
`/download_torrent` - Download torrent file (pass two parameters: id and file name without spaces) \
`/delete_torrent_file_id` - Delete torrent file by id \
`/find_kinozal_id` - Search in Kinozal by id \
`/download_video_id` - Add to qBittorrent to download from torrent file \
`/info` - Download status of the specified torrent (pass parameter: torrent hash) \
`/torrent_content` - Contents (files) of the torrent (pass parameter: torrent hash) \
`/file_torrent` - Status of selected torrent file (pass parameter: file index) \
`/torrent_priority` - Change the priority of the selected file in /file_torrent (pass parameter: priority number) \
`/pause` - Set to pause (pass parameter: torrent hash) \
`/resume` - Restore download (pass parameter: torrent hash) \
`/delete_torrent` - Remove torrent from download (pass parameter: torrent hash) \
`/delete_video` - Delete with video data (pass parameter: hash of torrent) \
`/plex_status_key` - Information about the selected section in Plex (pass parameter: section key) \
`/plex_sync_key` - Synchronize the specified section in Plex (pass parameter: section key) \
`/plex_folder_key` - Get the list of directories and files in the selected section \
`/find` - Search for content in Plex by path (pass parameter: endpoint)

### Added in version 0.4.1:

`/plex_last_views` - List of last views (date of viewing and stop time) \
`/plex_last_added` - List of last added files \
`/kinozal_description` - Movie description from Kinozal (pass parameter: id kinozal)

### Added in version 0.4.2:

`/kinozal_actors` - List of actors from Kinozal (pass parameter: id kinozal) \
`/actor` - Description and search for the actor and his filmography from Kinozal and link to Kinopoisk (pass parameter: actor name) \
`/kinopoisk_movie` - Movie information from Kinopoisk by kinopoisk id (pass parameter: kinozal id)

### Example commands:

`/search Rocky 2` - Search all movies (up to 50 movie buttons with movie link) \
`/search 1979 Rocky` - Search for a movie filtered by year of release \
`/actor Sylvester Stallone` - Search by actor
