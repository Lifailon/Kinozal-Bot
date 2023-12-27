#!/bin/bash

# Stack:
# Kinozal: read RSS, receiving data from html (no api), filtering by rating and year, download torrent files
# Telegram api: send news to channel, message reading (only commands) and answers in menu format (keyboard)
# qBittorrent api: data download from torrent files and data managment
# Plex Media Server api: view and sync content
# Optional:
# Proxy server with VPN (Split Tunneling mode) for access to kinozal (example: HandyCache and Hotspot Shield)
# Kinopoisk unofficial (https://github.com/mdwitr0/kinopoiskdev)
# WinAPI (https://github.com/Lifailon/WinAPI): rest api server based on .NET HttpListener and PowerShell Core

# Change log:
# 16.11.2023 (0.1) - Creat kinozal news channel and Telegram bot for download torrent files and qBittorrent managment.
# 27.11.2023 (0.2) - Added Telegram keyboard menu, delete torrent files and get count downloaded to profile kinozal.
# 30.11.2023 (0.3) - Added Plex functions and commands for view and sync content.
# 04.12.2023 (0.4.0) - Added search in kinozal by name, alternative links list, get file list from torrent and set priority.
# 07.12.2023 (0.4.1) - Added description command from kinozal and debug for finding in plex
# 27.12.2023 (0.4.2) - Добавлен список актеров для каждого фильма, просмотр их фильмографии и ссылка на Кинопоиск.
# Получение дополнительной информации и список трейлеров из kinopoisk api. Фильтрация для поиска фильмов по году выхода.

# Bot commands:
# /search - Поиск в Кинозал по названию (вначале запроса принимает год выхода для фильтрации)
# /profile - Профиль Кинозал
# /torrent_files - Список загруженных торрент файлов
# /status - qBittorrent manager
# /plex_info - Plex content
# /download_torrent - Загрузить торрент файл (передать два параметра: id и имя файла без пробелов)
# /delete_torrent_file_id - Удалить торрент файл по id
# /find_kinozal_id - Поиск в Кинозал по id
# /download_video_id - Добавить в qBittorrent на загрузку из торрент файла
# /info - Статус загрузки указанного торрента (передать параметр: hash торрента)
# /torrent_content - Содержимое (файлы) торрента (передать параметр: hash торрента)
# /file_torrent - Статус выбранного торрент файла (передать параметр: порядковый индекс файла)
# /torrent_priority - Изменить приоритет выбранного файла в /file_torrent (передать параметр: номер приоритета)
# /pause - Установить на паузу (передать параметр: hash торрента)
# /resume - Восстановить загрузку (передать параметр: hash торрента)
# /delete_torrent - Удалить торрент из загрузки (передать параметр: hash торрента)
# /delete_video - Удалить вместе с видео данными (передать параметр: hash торрента)
# /plex_status_key - Информация о выбранной секции в Plex (передать параметр: ключ секции)
# /plex_sync_key - Синхронизировать указанную секцию в Plex (передать параметр: ключ секции)
# /plex_folder_key - Получить список директорий и файлов в выбранной секции
# /find - Поиск контента в Plex по пути (передать параметр: endpoint)
### 0.4.1:
# /plex_last_views - Список последних просмотров (дата просмотра и время остановки)
# /plex_last_added - Список последних добавленных файлов
# /kinozal_description - Описание фильма из Кинозал (передать параметр: id kinozal)
### 0.4.2:
# /kinozal_actors - Список актеров из Кинозал (передать параметр: id kinozal)
# /actor - Описание и поиск актера и его фильмографии из Кинозала и ссылка на Кинопоиск (передать параметр: имя актера)
# /kinopoisk_movie - Информация о фильме из Кинопоиск по id kinopoisk (передать параметр: id kinozal)
### Example commands:
# /search Рокки 2
# /search 1979 Рокки
# /actor Сильвестр Сталлоне

### Read configuration
kinozal_bot_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
conf="$kinozal_bot_path/kinozal-bot.conf"
### DEBUG to console:
#conf="/home/lifailon/kinozal-torrent/kinozal-bot.conf"
if [ -f "$conf" ]; then
    source "$conf"
    TG_CHAT_ARRAY=($(echo $TG_CHAT | tr ',' ' '))
else
    echo "Configuration file not fount: $conf"
    exit 1
fi

### Stop and status server (process threads):
### bash kinozal-news.sh stop
### bash kinozal-news.sh status
if [ -n "$1" ]; then
    process_name="kinozal"
    if [[ $1 == "stop" ]]; then
        ### Skip current stop and search process
        proc=($(ps -AF | grep "$process_name" | grep -vE "grep|stop" | awk '{print $2}'))
        if [[ ${#proc[@]} != 0 ]]; then
            for p in ${proc[@]}; do
                echo "kill $p"
                kill -9 $p
            done
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            proc=($(ps -AF | grep "$process_name" | grep -vE "grep|stop"))
            if [[ ${#proc[@]} == 0 ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Server stopped. Count running process: $(echo ${#proc[@]})" >> $path_log
            else
                echo "[ERR]  $(date '+%H:%M:%S'): Server stopped. Count running process: $(echo ${#proc[@]})" >> $path_log
            fi
        else
            echo "[WARN] $(date '+%H:%M:%S'): Server stopped. Count running process: $(echo ${#proc[@]})" >> $path_log
        fi
        cat $path_log | tail -n 1
    elif [[ $1 == "status" ]]; then
        proc=($(ps -AF | grep "$process_name" | grep -vE "grep|status" | awk '{print $2}'))
        echo "Count running process: $(echo ${#proc[@]})"
    fi
    exit 0
fi

### Logging
function log-rotate {
    byte=$((($log_size_mbyte*1024*1024)))
    if [ ! -e "$file_path" ]; then
        touch $path_log 
    elif [[ $size > $byte ]]; then
        size=$(ls -l $path_log | awk '{print $5}')
        cp $path_log $(echo "$path_log"_bak)
        rm $path_log
    fi
    echo "[OK]   $(date '+%H:%M:%S'): Server started" >> $path_log
    echo "Server started: tail -f $path_log"
}

log-rotate

###### Telegram 🔵
### API documentation: https://core.telegram.org/bots/api
function test-telegram {
    endpoint="getMe"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    curl -s $url -X "GET"
}

### Send message to Telegram
function send-telegram {
    text=$1
    chat=$2
    endpoint="sendMessage"
    mode="markdown"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    curl_response=$(curl -s $url -X "GET" \
        -d chat_id=$chat \
        -d text="$text" \
        -d "parse_mode=$mode")
    if [[ "$curl_response" =~ "error_code" ]]; then
        echo "[WARN] $(date '+%H:%M:%S'): cURL: $curl_response" >> $path_log
    else
        echo "[OK]   $(date '+%H:%M:%S'): cURL: send new message to telegram" >> $path_log
    fi
}

### Send keyboard to Telegram
function send-keyboard {
    text=$1
    chat=$2
    reply_markup=$3
    endpoint="sendMessage"
    mode="markdown"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    curl_response=$(curl -s $url -X POST \
        -d "chat_id=$chat" \
        -d "text=$text" \
        -d "parse_mode=$mode" \
        -d "reply_markup=$reply_markup")
    if [[ "$curl_response" =~ "error_code" ]]; then
        echo "[WARN] $(date '+%H:%M:%S'): cURL: $curl_response" >> $path_log
    else
        echo "[OK]   $(date '+%H:%M:%S'): cURL: send new keyboard to telegram" >> $path_log
    fi
}

### Edit last message used keyboard
function edit-keyboard {
    text=$1
    chat=$2
    reply_markup=$3
    message_id=$4
    endpoint="editMessageText"
    mode="markdown"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    curl_response=$(curl -s $url -X POST \
        -d "chat_id=$chat" \
        -d "text=$text" \
        -d "parse_mode=$mode" \
        -d "reply_markup=$reply_markup" \
        -d "message_id=$message_id")
    if [[ "$curl_response" =~ "error_code" ]]; then
        echo "[WARN] $(date '+%H:%M:%S'): cURL: $curl_response" >> $path_log
    else
        echo "[OK]   $(date '+%H:%M:%S'): cURL: send edit keyboard to telegram" >> $path_log
    fi
}

### Read messages from Telegram
function read-telegram {
    endpoint="getUpdates"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    last_update_id=$(curl -s $url -X "GET" | jq ".result[-1].update_id")
    messages=$(curl -s $url -X "GET" -d offset=$last_update_id -d limit=1)
    type="bot_command"
    ### Filtering callback query
    result=$(echo $messages | jq .result[].callback_query)
    ### Filtering messages by chat id and type message (only commands)
    for TG in ${TG_CHAT_ARRAY[@]}; do
        if [[ $result == "null" ]]; then
            selected=$(echo $messages | jq ".result[] | select(.message.chat.id == $TG and .message.entities[0].type == \"$type\")")
            if [[ -n "$selected" ]]; then
                echo $selected | jq '{
                timestamp: .message.date,
                text: .message.text,
                user: .message.from.username,
                chat: .message.chat.id,
                update_id: .update_id,
                message_id: .callback_query.message.message_id
                }' 
                break
            fi
        else
            selected=$(echo $messages | jq ".result[] | select(.callback_query.message.chat.id == $TG)")
            if [[ -n "$selected" ]]; then
                echo $selected | jq '{
                timestamp: .callback_query.message.date,
                text: .callback_query.data,
                user: .callback_query.message.from.username,
                chat: .callback_query.message.chat.id,
                update_id: .update_id,
                message_id: .callback_query.message.message_id
                }'
                break
            fi
        fi
    done
}

###### qBittorrent 🟢
### API documentation: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)
### Authorization to qBittorrent
function qbittorrent-auth {
        echo "[INFO] $(date '+%H:%M:%S'): Authorization to qBittorrent" >> $path_log
        endpoint_auth="api/v2/auth/login"
        curl -s "$QB_ADDR/$endpoint_auth" \
            --max-time 1 \
            -c $path_qb_cookies \
            --header "Referer: $QB_ADDR" \
            --data "username=$QB_USER&password=$QB_PASS" 1> /dev/null
}

### Heath check qBittorrent
function qbittorrent-test {
    qbittorrent-auth
    cookies_test=$(cat $path_qb_cookies | wc -l)
    qb_test=0
    if [[ $cookies_test -le 4 ]]; then
        qb_test=1
        echo "[ERRO] $(date '+%H:%M:%S'): qBittrrent error authorization (cookies null)" >> $path_log
        QB_IP=$(echo $QB_ADDR | sed -r "s/.+\/\/|:.+//g")
        QB_PORT=$(echo $QB_ADDR | sed -r "s/.+://")
        timeout 2 nc -zv $QB_IP $QB_PORT &> /dev/null
        if [ $? != 0 ]; then
            qb_test=2
            echo "[ERRO] $(date '+%H:%M:%S'): qBittorrent service not avaliable (tcp port)" >> $path_log
            qb_ping=$(ping $QB_IP -c 2 | grep -i ttl)
            if [ -z "$qb_ping" ]; then
                qb_test=3
                echo "[ERRO] $(date '+%H:%M:%S'): qBittorrent server not avaliable (icmp ping)" >> $path_log
            fi
        fi
    fi
    echo $qb_test
}

### Get information from qBittorrent
function qbittorrent-info {
    qbittorrent-auth
    echo "[INFO] $(date '+%H:%M:%S'): Get info (status) from qBittorrent" >> $path_log
    endpoint_info="api/v2/torrents/info"
    curl -s "$QB_ADDR/$endpoint_info" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq ".[] | {
            name: .name,
            hash: .hash,
            path: .content_path,
            state: .state,
            progress: (.progress * 100 | floor / 100 * 100 | tostring + \" %\"),
            completed_size: (.completed / 1024 / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" GB\"),
            size: (.size / 1024 / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" GB\"),
            size_total: (.total_size / 1024 / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" GB\"),
            added_date: (.added_on $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\")),
            completion_date: (.completion_on $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\")),
            last_activity_date: (.last_activity $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\")),
            time_active: (.time_active / 60 | floor / 100 * 100 | tostring + \" min\"),
            uploaded: (.uploaded / 1024 / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" GB\"),
            download_speed: (.dlspeed / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" MB/s\"),
            uploaded_speed: (.upspeed / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" MB/s\"),
            download_speed_limit: (.dl_limit / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" MB/s\"),
            uploaded_speed_limit: (.up_limit / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" MB/s\"),
            tracker_current_url: .tracker,
            trackers_count: .trackers_count
        }"
}

### Get properties torrent
function qbittorrent-properties {
    torrent_hash=$1
    qbittorrent-auth
    endpoint="api/v2/torrents/properties"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hash=$torrent_hash" | jq '{
        name: .name,
        hash: .hash,
        comment: .comment,
        seeds: .seeds,
        seeds_total: .seeds_total,
        peers: .peers,
        peers_total: .peers_total,
        download_speed: (.dl_speed / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + " MB/s"),
        download_speed_avg: (.dl_speed_avg / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + " MB/s")
        }'
}

### Get files content from torrent
function qbittorrent-files {
    torrent_hash=$1
    qbittorrent-auth
    endpoint_delete="api/v2/torrents/files"
    curl -s "$QB_ADDR/$endpoint_delete" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hash=$torrent_hash" | jq .
}

### Set torrent child file priority
function qbittorrent-priority {
    torrent_hash=$1
    file_index=$2
    priority=$3 # 0/1/6/7
    qbittorrent-auth
    endpoint_delete="api/v2/torrents/filePrio"
    curl -s "$QB_ADDR/$endpoint_delete" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hash=$torrent_hash" \
        --data "id=$file_index" \
        --data "priority=$priority"
}

### Download selected torrent file
function qbittorrent-download {
    qbittorrent-auth
    filename_id=$1
    filename=$(ls -l $path | grep -E "*\.torrent" | grep "$filename_id" | awk '{print $9}')
    file_path="$path/$filename"
    echo "[INFO] $(date '+%H:%M:%S'): Download video from file: $file_path" >> $path_log
    if [ -e $file_path ]; then
        echo "[INFO] $(date '+%H:%M:%S'): Torrent file avalible: $file_path" >> $path_log
        file_size=$(ls -lh $file_path | awk '{print $5}')
        echo "[INFO] $(date '+%H:%M:%S'): File size: $file_size" >> $path_log
        file_test=$(cat "$file_path" | grep "javascript")
        if [ -z "$file_test" ]; then
            echo "[INFO] $(date '+%H:%M:%S'): Torrent file valid (not found javascript to file)" >> $path_log
        else
            echo "[INFO] $(date '+%H:%M:%S'): Torrent file not valid (found javascript to file)" >> $path_log
        fi
    else
        echo "[INFO] $(date '+%H:%M:%S'): Torrent file not avalible: $file_path" >> $path_log
    fi
    endpoint_download="api/v2/torrents/add"
    curl -s "$QB_ADDR/$endpoint_download" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --form "file=@$file_path"
}

### Pause selected torrent file
function qbittorrent-pause {
    torrent_hash=$1
    qbittorrent-auth
    endpoint_pause="api/v2/torrents/pause"
    curl -s "$QB_ADDR/$endpoint_pause" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$torrent_hash"
}

### Resume selected torrent file
function qbittorrent-resume {
    torrent_hash=$1
    qbittorrent-auth
    endpoint_resume="api/v2/torrents/resume"
    curl -s "$QB_ADDR/$endpoint_resume" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$torrent_hash"
}

### Delete torrent
function qbittorrent-delete {
    torrent_hash=$1
    delete_type=$2
    qbittorrent-auth
    endpoint_delete="api/v2/torrents/delete"
    curl -s "$QB_ADDR/$endpoint_delete" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$torrent_hash" \
        --data "deleteFiles=$delete_type"
}

### Rename torrent
function qbittorrent-rename-torrent {
    torrent_hash=$1
    new_name_torrent=$2
    qbittorrent-auth
    endpoint="api/v2/torrents/rename"
    curl "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hash=$torrent_hash" \
        --data "deleteFiles=$delete_type" \
        --data "name=$new_name_torrent"
}
# qbittorrent-rename-torrent "23a29deb70f2d38a462575f81bb6d79ca5415673" "Rick"

### Rename file
function qbittorrent-rename-file {
    torrent_hash=$1
    new_name_file=$2
    type_file=$3
    old_torrent_path=$(qbittorrent-info | jq -r ". | select(.hash == \"$torrent_hash\").path")
    echo "[INFO] $(date '+%H:%M:%S'): Old torrent path: $old_torrent_path" # >> $path_log
    old_torrent_name=$(echo $old_torrent_path | sed -r 's/.+\\//')
    torrent_path=$(echo $old_torrent_path | sed "s/$old_torrent_name"//)
    new_torrent_path="$torrent_path$new_name_file"
    echo "[INFO] $(date '+%H:%M:%S'): New torrent path: $new_torrent_path" # >> $path_log
    old_torrent_path=$(echo $old_torrent_path | sed 's/\\/\\\\/g')
    new_torrent_path=$(echo $new_torrent_path | sed 's/\\/\\\\/g')
    endpoint="api/v2/torrents/rename$type_file"
    curl -X POST "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hash=$torrent_hash" \
        --data "oldPath=$old_torrent_path" \
        --data "newPath=$new_torrent_path"
}
# qbittorrent-rename-file "23a29deb70f2d38a462575f81bb6d79ca5415673" "Rick" "File"
# qbittorrent-rename-file "23a29deb70f2d38a462575f81bb6d79ca5415673" "Rick" "Folder"

### Get items from RSS
function qbittorrent-rss {
    type=$1
    qbittorrent-auth
    endpoint="api/v2/rss/items"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "withData=$type" | jq .
}
# qbittorrent-rss
# qbittorrent-rss true

###### Plex Media Server 🟠
### No official documentation
### All sections (root derictory) and date last scanned
function plex-sections {
    PLEX_ADDR=$PLEX_ADDR
    PLEX_TOKEN=$PLEX_TOKEN
    endpoint="library/sections"
    plex_dir=$(curl -s -X GET "$PLEX_ADDR/$endpoint" \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        -H "accept: application/json" | jq ".MediaContainer.Directory[]")
    echo $plex_dir | jq "{
        name: .title,
        key: .key,
        type: .type,
        path: .Location[].path,
        scanned: (.scannedAt $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\")),
        updated: (.updatedAt $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\")),
        created: (.createdAt $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\")),
    }"
}

### Synchronization (scanned) content by selected section
function plex-sync-section {
    key=$1
    PLEX_ADDR=$PLEX_ADDR
    PLEX_TOKEN=$PLEX_TOKEN
    endpoint="library/sections/$key/refresh"
    curl -s -X GET "$PLEX_ADDR/$endpoint" \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        -H "accept: application/json"
}

### Get folder list by selected section
# plex-folder-from-section 2
function plex-folder-from-section {
    key=$1
    PLEX_ADDR=$PLEX_ADDR
    PLEX_TOKEN=$PLEX_TOKEN
    endpoint="library/sections/$key/folder"
    plex_dir=$(curl -s -X GET "$PLEX_ADDR/$endpoint" \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        -H "accept: application/json" | jq ".MediaContainer.Metadata[]")
    echo $plex_dir | jq '{
        name: .title,
        endpoint: .key,
        type: .type
    }'
}

### Get all data by selected folder (use endpoint)
# plex-content-from-folder "/library/sections/2/folder?parent=46"
# plex-content-from-folder $(plex-folder-from-section $(plex-sections | jq -r .key) | jq -r .endpoint)
function plex-content-from-folder {
    endpoint="$1"
    PLEX_ADDR=$PLEX_ADDR
    PLEX_TOKEN=$PLEX_TOKEN
    plex_dir=$(curl -s -X GET "$PLEX_ADDR$endpoint" \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        -H "accept: application/json" | jq ".MediaContainer.Metadata[]")
    echo $plex_dir | jq "
        if .type != null then {
            name: .title,
            endpoint: .key,
            type: .type,
            path: .Media[].Part[].file,
            size: (.Media[].Part[].size / 1024 / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" GB\"),
            duration: (.Media[].duration / 1000 | strftime(\"%T\")),
            stop_time: .viewOffset,
            format: .Media[].Part[].container,
            FrameRate: .Media[].videoFrameRate,
            quality: ((.Media[].width | tostring)+\"x\"+(.Media[].height | tostring)),
            video: .Media[].videoResolution,
            video_codec: .Media[].videoCodec,
            audio_codec: .Media[].audioCodec,
            audio_channels: .Media[].audioChannels,
            year: .year,
            originally: .originallyAvailableAt,
            last_view: (.lastViewedAt $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\")),
            added: (.addedAt $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\")),
            update: (.updatedAt $DATA_TIMEZONE * 3600 | strftime(\"%H:%M:%S %d.%m.%Y\"))
        }
        else {
            name: .title,
            endpoint: .key,
            type: \"folder\"
        } end
    "
}

###### Kinozal 🟣
### Authorization and download selected torrent file
function download-torrent {
    kz_id=$1
    kz_name=$2
    url_down="https://dl.kinozal.tv/download.php?id=$kz_id"
    url_login="https://kinozal.tv/takelogin.php"
    url_refrer="https://kinozal.tv/"
    path_down="$path/$kz_id-$kz_name.torrent"
    if [[ $PROXY == "True" ]]; then
        URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
        curl -s $url_login -X POST \
            -x $URL_PROXY \
            -c $path_kz_cookies \
            -d "username=$KZ_USER&password=$KZ_PASS" 1> /dev/null
        curl -s -L $url_down -X GET \
            -x $URL_PROXY \
            -b $path_kz_cookies \
            -o $path_down \
            -H "Referer: $url_refrer" 1> /dev/null
    else
        curl -s $url_login -X POST \
            -c $path_kz_cookies \
            -d "username=$KZ_USER&password=$KZ_PASS" 1> /dev/null
        curl -s -L $url_down -X GET \
            -b $path_kz_cookies \
            -o $path_down \
            -H "Referer: $url_refrer" 1> /dev/null
    fi
}

### Daily download and other statistics to Kinozal profile
function count-torrent {
    url_profile="https://kinozal.tv/userdetails.php?id=$KZ_PROFILE"
    url_login="https://kinozal.tv/takelogin.php"
    url_refrer="https://kinozal.tv/"
    if [[ $PROXY == "True" ]]; then
        URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
        curl -s $url_login -X POST \
            -x $URL_PROXY \
            -c $path_kz_cookies \
            -d "username=$KZ_USER&password=$KZ_PASS" 1> /dev/null
        html_profile=$(curl -s -L $url_profile -X GET \
            -x $URL_PROXY \
            -b $path_kz_cookies \
            -H "Referer: $url_refrer" | iconv -f windows-1251 -t UTF-8)
    else
        curl -s $url_login -X POST \
            -c $path_kz_cookies \
            -d "username=$KZ_USER&password=$KZ_PASS" 1> /dev/null
        html_profile=$(curl -s -L $url_profile -X GET \
            -b $path_kz_cookies \
            -H "Referer: $url_refrer" | iconv -f windows-1251 -t UTF-8)
    fi
    count_torrent=$(echo "$html_profile" | cat -v | grep -oE "\( [0-9]+ \)" | sed -r "s/\(|\)//g")
    count_all=$(echo $count_torrent | awk '{print $1}')
    count_current=$(echo $count_torrent | awk '{print $2}')
    echo "[INFO] $(date '+%H:%M:%S'): Downloaded $count_current of $count_all" >> $path_log
    data_count="$count_current из $count_all"
    uploaded=$(echo "$html_profile" | grep "Залил" | sed -r "s/.+<td>//; s/<\/td>.+//")
    downloaded=$(echo "$html_profile" | grep "Скачал" | sed -r "s/.+<td>//; s/<\/td>.+//")
    sed=$(echo "$html_profile" | grep -Po "(?<=Сид</td><td>).+(?=<tr><td>Пир)")
    per=$(echo "$html_profile" | grep -Po "(?<=Пир</td><td>).+(?=<tr><td>Торренты)")
    data="*Загружено:* $data_count\n"
    data+="*Залил:* $uploaded\n"
    data+="*Скачал:* $downloaded\n"
    data+="*Сид:* $sed\n"
    data+="*Пир:* $per"
    keyboard="{
        \"inline_keyboard\":[
            [{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},
            {\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],
            [{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]
        ]
    }"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### Get data via html (no api)
function read-html {
    html=$1
    a=$2
    type_chat=$3
    id_kz=$(echo $a | sed -r 's/.+id=//')
    # Удаление в имени символа кавычек (&quot;)
    name=$(printf "%s\n" "${html[@]}" | grep "<title>" | sed -r 's/<title>//; s/ \/.+//' | sed -r 's/`|_|\"|&|;|quot//g')
    #name_down=$(echo $name | sed -r "s/ /_/g")
    rating_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+floatright">//; s/<.+//')
    rating_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r 's/.+floatright">//; s/<.+//')
    year=$(printf "%s\n" "${html[@]}" | grep -E -B 1 "class=lnks_tobrs" | head -n 1 | sed -r 's/.+<\/b> //; s/<.+//')
    if [[ $year == $(date '+%Y') ]]; then
        name="🆕 $name"
    fi
    genre=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_tobrs" | sed -r 's/.+tobrs>//; s/<.+//' | head -n 1)
    side=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_tobrs" | sed -r 's/.+tobrs>//; s/<.+//' | head -n 2 | tail -n 1)
    link_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+href="//; s/" target=.+//')
    size=$(printf "%s\n" "${html[@]}" | grep "floatright green" -m 1 | sed -r 's/.+n">//;s/\s.+//')
    length=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -A 1 | tail -n 1 | sed -r 's/.+b> //; s/<.+//')
    lang=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -A 2 | tail -n 1 | sed -r 's/.+b> //; s/<.+//')
    video=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -B 2 | tail -n 3 | head -n 1 | sed -r 's/.+b> //; s/<.+//; s/.* ([0-9]+x[0-9]+).*/\1/p' | head -n 1)
    ### Other info:
    # audio=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -B 1 | tail -n 2 | head -n 1 | sed -r 's/.+b> //; s/<.+//')
    rating_kz=$(printf "%s\n" "${html[@]}" | grep "ratingValue" | sed -r "s/.+ratingValue\">//; s/<.+//")
    rating_count_users=$(printf "%s\n" "${html[@]}" | grep "ratingValue" | sed -r "s/.+content=\"//; s/\">.+//")
    users_downloaded=$(printf "%s\n" "${html[@]}" | grep "Скачали полностью" | sed -r "s/.+Скачали полностью\s+//g; s/,.+//")
    users_download=$(printf "%s\n" "${html[@]}" | grep "Скачивают " | sed -r "s/.+Скачивают //; s/',.+//")
    # users_distributed=$(printf "%s\n" "${html[@]}" | grep "Раздают " | sed -r "s/.+Раздают //; s/',.+//")
    # file_count=$(printf "%s\n" "${html[@]}" | grep "Список файлов всего " | sed -r "s/.+Список файлов всего //; s/',.+//")
    data=$(echo "$name \n")
    data+=$(echo "*Год выхода:* $year \n")
    data+=$(echo "*Жанр:* $genre \n")
    data+=$(echo "*Страна:* $side \n")
    data+=$(echo "*Рейтинг Кинопоиск:* $rating_kp \n")
    data+=$(echo "*Рейтинг IMDb:* $rating_imdb \n")
    data+=$(echo "*Рейтинг Кинозал:* $rating_kz/10 (голосов: $rating_count_users)\n")
    data+=$(echo "*Скачивают/Скачали:* $users_download/$users_downloaded \n")
    data+=$(echo "*Размер:* $size Гб \n")
    data+=$(echo "*Продолжительность:* $length \n")
    data+=$(echo "*Перевод:* $lang \n")
    data+=$(echo "*Качество:* $video \n")
    #data+=$(echo "*Аудио:* $audio \n")
    data+=$(echo "*Кинопоиск:* $link_kp \n")
    data+=$(echo "*Кинозал:* $a \n")
    if [[ $type_chat == "Channel" ]]; then
        TG_BOT_NAME=$(echo $TG_BOT_NAME | sed -r "s/_/\\\_/g")
        data+=$(echo "@$TG_BOT_NAME: \`/find_kinozal_$id_kz\`")
    #else
        #data+=$(echo "*Для загрузки торрент файла:* \`/download_torrent $id_kz $name_down\`")
    fi
    echo $data
}

function get-kp-id {
    id_kz=$1
    id_url="https://kinozal.tv/details.php?id=$id_kz"
    if [[ $PROXY == "True" ]]; then
        URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
        html=$(curl -s -x $URL_PROXY $id_url | iconv -f windows-1251 -t UTF-8)
    else
        html=$(curl -s $id_url | iconv -f windows-1251 -t UTF-8)
    fi
    printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+film\///; s/".+//'
}

### Link list of similar torrent distribution
function get-links {
    id_find=$1
    html=$2
    type=$3
    keyboard='{"inline_keyboard":['
    if [[ $type == "find" ]]; then
        other_links=$(printf "%s\n" "${html[@]}" | grep "tables3")
        ###! Creat array from id and titel
        readarray -t lines <<< "$(echo "$other_links" | grep -Po "(?<=class='r[01]').*?</a>")"
        for line in "${lines[@]}"; do
            kz_name=$(echo "$line" | sed -r "s/.+id=[0-9]+//; s/'>//; s/<\/a>//")
            kz_name=$(echo $kz_name | awk -F "/" '{print $1,$3,$NF}'| sed -r "s/\s+/ /g" | sed -r 's/`|_|\"|&|;|quot//g')
            # Encode name to url
            encoded_kz_name=$(echo -ne "$kz_name" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
            kz_id=$(echo "$line" | grep -Po "(?<=id=)[0-9]+")
            keyboard+="[{\"text\":\"$encoded_kz_name\",\"callback_data\":\"/find_kinozal_$kz_id\"}],"
        done
    elif [[ $type == "description" ]]; then
        id_url="https://kinozal.tv/ajax/details_get.php?id=$id_find&sr=101"
        echo "[INFO] $(date '+%H:%M:%S'): Url top: $id_url" >> $path_log
        if [[ $PROXY == "True" ]]; then
            URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
            html=$(curl -s -x $URL_PROXY $id_url | iconv -f windows-1251 -t UTF-8)
        else
            html=$(curl -s $id_url | iconv -f windows-1251 -t UTF-8)
        fi
        readarray -t lines <<< "$(echo "$html" | grep -Po "(?<=class='r[01]').*?</a>")"
        for line in "${lines[@]}"; do
            kz_name=$(echo "$line" | sed -r "s/.+id=[0-9]+//; s/'>//; s/<\/a>//")
            kz_name=$(echo $kz_name | awk -F "/" '{print $1,$3,$NF}'| sed -r "s/\s+/ /g")
            # Encode name to url
            encoded_kz_name=$(echo -ne "$kz_name" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
            kz_id=$(echo "$line" | grep -Po "(?<=id=)[0-9]+")
            keyboard+="[{\"text\":\"$encoded_kz_name\",\"callback_data\":\"/find_kinozal_$kz_id\"}],"
        done
    fi
    keyboard+="[{\"text\":\"⬇️ Скачать торрент файл\",\"callback_data\":\"\/download_torrent $id_find "GLOBAL_NAME" \"},"
    keyboard+="{\"text\":\"🗑 Удалить торрент файл\",\"callback_data\":\"\/delete_torrent_file_$id_find\"}],"
    if [[ $type == "find" ]]; then
        keyboard+="[{\"text\":\"🟣 Описание Кинозал\",\"callback_data\":\"\/kinozal_description $id_find\"},"
    elif [[ $type == "description" ]]; then
        keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/find_kinozal_$id_find\"},"
    fi
    keyboard+="{\"text\":\"👥 Список актеров\",\"callback_data\":\"/kinozal_actors $id_find\"}],"
    keyboard+="[{\"text\":\"🟡 Описание Кинопоиск\",\"callback_data\":\"/kinopoisk_movie $id_find\"},"
    keyboard+="{\"text\":\"⬆️ Загрузить\",\"callback_data\":\"\/download_video_$id_find\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    echo $keyboard
}

function get-global-name {
    html=$1
    name=$(printf "%s\n" "${html[@]}" | grep "<title>" | sed -r 's/<title>//; s/ \/.+//' | sed -r 's/`|_|\"|&|;|quot//g')
    echo $name | sed -r "s/ /_/g"
}

### Switch function for encode text to url
function url-encode-ru {
    text=$1
    encoded=""
    length=${#text}
    for ((i = 0; i < length; i++)); do
        char="${text:i:1}"
        if [[ "$char" =~ [йцукенгшщзхъфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ] ]]; then
            case "$char" in
                й) encoded+="%E9" ;;
                ц) encoded+="%F6" ;;
                у) encoded+="%F3" ;;
                к) encoded+="%EA" ;;
                е) encoded+="%E5" ;;
                н) encoded+="%ED" ;;
                г) encoded+="%E3" ;;
                ш) encoded+="%F8" ;;
                щ) encoded+="%F9" ;;
                з) encoded+="%E7" ;;
                х) encoded+="%F5" ;;
                ъ) encoded+="%FA" ;;
                ф) encoded+="%F4" ;;
                ы) encoded+="%FB" ;;
                в) encoded+="%E2" ;;
                а) encoded+="%E0" ;;
                п) encoded+="%EF" ;;
                р) encoded+="%F0" ;;
                о) encoded+="%EE" ;;
                л) encoded+="%EB" ;;
                д) encoded+="%E4" ;;
                ж) encoded+="%E6" ;;
                э) encoded+="%FD" ;;
                я) encoded+="%FF" ;;
                ч) encoded+="%F7" ;;
                с) encoded+="%F1" ;;
                м) encoded+="%EC" ;;
                и) encoded+="%E8" ;;
                т) encoded+="%F2" ;;
                ь) encoded+="%FC" ;;
                б) encoded+="%E1" ;;
                ю) encoded+="%FE" ;;
                Й) encoded+="%C9" ;;
                Ц) encoded+="%D6" ;;
                У) encoded+="%D3" ;;
                К) encoded+="%CA" ;;
                Е) encoded+="%C5" ;;
                Н) encoded+="%CD" ;;
                Г) encoded+="%C3" ;;
                Ш) encoded+="%D8" ;;
                Щ) encoded+="%D9" ;;
                З) encoded+="%C7" ;;
                Х) encoded+="%D5" ;;
                Ъ) encoded+="%DA" ;;
                Ф) encoded+="%D4" ;;
                Ы) encoded+="%DB" ;;
                В) encoded+="%C2" ;;
                А) encoded+="%C0" ;;
                П) encoded+="%CF" ;;
                Р) encoded+="%D0" ;;
                О) encoded+="%CE" ;;
                Л) encoded+="%CB" ;;
                Д) encoded+="%C4" ;;
                Ж) encoded+="%C6" ;;
                Э) encoded+="%DD" ;;
                Я) encoded+="%DF" ;;
                Ч) encoded+="%D7" ;;
                С) encoded+="%D1" ;;
                М) encoded+="%CC" ;;
                И) encoded+="%C8" ;;
                Т) encoded+="%D2" ;;
                Ь) encoded+="%DC" ;;
                Б) encoded+="%C1" ;;
                Ю) encoded+="%DE" ;;
            esac
        else
                encoded+="$char"
        fi
    done
    echo "$encoded"
}

### Search in kinozal on name
function get-search {
    search_name=$1
    # Добавлена фильтрация, если вначале строки поиска идет год выхода
    # search_name="один дома"
    # search_name="1992 один дома"
    if [[ $search_name =~ ^[0-9]{4} ]]; then
        search_year=$(echo $search_name | grep -Po "^[0-9]{4}")
        search_name_no_year=$(echo $search_name | sed -r "s/$search_year //")
        search_name_encode=$(url-encode-ru "$search_name_no_year")
        search_name_replace_space=$(echo $search_name_encode | sed "s/ /+/g")
        echo "[INFO] $(date '+%H:%M:%S'): Url name: $search_name_replace_space" >> $path_log
        id_url="https://kinozal.tv/browse.php?s=$search_name_replace_space&d=$search_year"
        data="Поиск: *$search_name_no_year*\n"
        data+="Год выхода: *$search_year*\n"
    else
        search_name_encode=$(url-encode-ru "$search_name")
        search_name_replace_space=$(echo $search_name_encode | sed "s/ /+/g")
        echo "[INFO] $(date '+%H:%M:%S'): Url name: $search_name_replace_space" >> $path_log
        id_url="https://kinozal.tv/browse.php?s=$search_name_replace_space"
        data="Поиск: *$search_name*\n"
        data+="Год выхода: *все года*\n"
    fi
    if [[ $PROXY == "True" ]]; then
        URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
        html=$(curl -s -x $URL_PROXY $id_url | iconv -f windows-1251 -t UTF-8)
    else
        html=$(curl -s $id_url | iconv -f windows-1251 -t UTF-8)
    fi
    id_array=$(printf "%s\n" "${html[@]}" | grep -Po "(?<=\/details.php\?id=)[0-9]+(?=\")")
    IFS=$'\n'
    keyboard='{"inline_keyboard":['
    for id in $id_array; do
        name_from_id=$(printf "%s\n" "${html[@]}" | grep -Po "(?<=id=$id\" class=\"r[0-9]\">).+(?=</a>)")
        if [[ $name_from_id =~ "PC (Windows)" ]]; then
            continue
        fi
        name_year_quality=$(echo $name_from_id | awk -F "/" '{print $1,$3,$NF}'| sed -r "s/\s+/ /g")
        # Encode name to url
        encoded_name_year_quality=$(echo -ne "$name_year_quality" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
        keyboard+="[{\"text\":\"$encoded_name_year_quality\",\"callback_data\":\"/find_kinozal_$id\"}],"
    done
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"},"
    keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    search_count=$(echo $(( $(echo $keyboard | jq . | grep "text" | wc -l) -4 )))
    echo "[INFO] $(date '+%H:%M:%S'): Search count link: $search_count" >> $path_log
    data+="Совпадений: *$search_count*"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

function get-actor {
    actor=$1
    encode_actor=$(url-encode-ru "$actor" | sed "s/\s/+/g")
    kinozal_actor_url="https://kinozal.tv/persons.php?s=$encode_actor"
    if [[ $PROXY == "True" ]]; then
        URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
        html=$(curl -s -x $URL_PROXY $kinozal_actor_url | iconv -f windows-1251 -t UTF-8)
    else
        html=$(curl -s $kinozal_actor_url | iconv -f windows-1251 -t UTF-8)
    fi
    if [[ $KINOPOISK_API == "True" ]]; then
        kinopoisk_actor=$(get-actor-kinopoisk "$actor")
        # Получаем ссылку на актера из kinopoisk api
        kinopoisk_actor_id=$(echo $kinopoisk_actor | jq -r .docs[].id)
        kinopoisk_actor_url="https://www.kinopoisk.ru/name/$kinopoisk_actor_id"
        kinopoisk_actor_en_name=$(echo $kinopoisk_actor | jq -r .docs[].enName)
        kinopoisk_actor_date=$(echo $kinopoisk_actor | jq -r .docs[].birthday)
        kinopoisk_actor_date=$(date --date="$kinopoisk_actor_date" "+%d.%m.%Y")
        kinopoisk_actor_age=$(echo $kinopoisk_actor | jq .docs[].age)
        data=$(echo "*Имя:* $actor ($kinopoisk_actor_en_name) \n")
        data+=$(echo "*Дата рождения:* $kinopoisk_actor_date\n")
        data+=$(echo "*Возраст:* $kinopoisk_actor_age\n")
        data+=$(echo "*Кинопоиск:* $kinopoisk_actor_url\n")
    else
        actor_name=$(printf "%s\n" "${html[@]}" | grep "Имя:" | sed -r "s/.+Имя://; s/<\/b> //; s/<br.+>//")
        #actor_country=$(printf "%s\n" "${html[@]}" | grep "Место рождения:" | sed -r "s/.+Место рождения://; s/<\/b> //; s/<br.+>//")
        actor_date=$(printf "%s\n" "${html[@]}" | grep "Дата рождения:" | sed -r "s/.+Дата рождения://; s/<\/b> //; s/<br.+>//")
        sum_age=$(( $(date "+%Y") - $(echo $actor_date | grep -Eo "[0-9]{4}") ))
        data=$(echo "*Имя:* $actor ($actor_name) \n")
        #data+=$(echo "*Место рождения:* $actor_country\n")
        data+=$(echo "*Дата рождения:* $actor_date\n")
        data+=$(echo "*Возраст:* $sum_age\n")
        data+=$(echo "*Кинозал:* $kinozal_actor_url\n")
    fi
    encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
    ### Отфильтровать все описание до фильмографии и забрать только строки с годом выхода
    ###! Символ &#237; это верхняя одинарная ковычка (') и удалить вторую дату из диапазона (2010 - 2020)
    films_name_array=$(printf "%s\n" "${html[@]}" | grep -A 1000 "Фильмография" | grep -P "^[0-9]{4}" | sed -r "s/\/.+//g; s/\.\.\..+//g; s/\&\#237\;/'/g; s/\&#216\;//g; s/\&//g; s/<br|<|>//; s/ – [0-9]{4}//g")
    IFS=$'\n'
    keyboard='{"inline_keyboard":['
    temp_count=0
    for films_name in $films_name_array; do
        ### Bad Request: can't parse reply keyboard markup JSON object (проблема с синтаксисом JSON из за двойных ковычек или символа &)
        films_name=$(echo $films_name | sed "s/\"/'/g" )
        ### Уменьшаем значение callback_data до 50 символов из за ошибки BUTTON_DATA_INVALID
        ### Error: Bad Request: reply markup is too long (слишком длинное значение Text)
        ### JSON не должен привышать 10Кб, по этому ограничиваем кол-во кнопок до 70
        ### https://core.telegram.org/bots/api#inlinekeyboardbutton&:~:text=1-64%20bytes
        if [[ $temp_count -le 70 ]]; then
            text_temp=$(echo $films_name | cut -c "1-50")
            text_temp="${text_temp%?}"
            keyboard+="[{\"text\":\"$films_name\",\"callback_data\":\"/search $text_temp\"}],"
            temp_count=$(($temp_count + 1))
        else
            break
        fi
    done
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/kinozal_actors $GLOBAL_ID_FIND\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"},"
    keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard"
    fi
}

###### Kinopoisk API 🟡
### API documentation: https://api.kinopoisk.dev/documentation
function percent-encode {
    str=$1
    echo -n "$str" | iconv -t utf8 | od -An -tx1 | tr ' ' % | tr -d '\n'
}
# percent-encode "Маколей Калкин"

function percent-decode {
    encoded=$1
    url_encoded="${encoded//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}
# percent-decode "%d0%9c%d0%b0%d0%ba%d0%be%d0%bb%d0%b5%d0%b9%20%d0%9a%d0%b0%d0%bb%d0%ba%d0%b8%d0%bd"

function get-actor-kinopoisk {
    actor_name=$1
    actor_encode=$(percent-encode $actor_name)
    curl -s -X 'GET' \
        "https://api.kinopoisk.dev/v1.4/person/search?page=1&limit=1&query=$actor_encode" \
        -H "accept: application/json" \
        -H "X-API-KEY: $KINOPOISK_TOKEN" | jq .
}

### Search movie to Kinopoisk by id 🟡
function get-movie-kinopoisk-id {
    movie_id=$1
    movie_data=$(curl -s -X 'GET' \
        "https://api.kinopoisk.dev/v1.4/movie/$movie_id?page=1&limit=1" \
        -H "accept: application/json" \
        -H "X-API-KEY: $KINOPOISK_TOKEN")
    movie_name=$(echo $movie_data | jq -r .name)
    movie_alternative_name=$(echo $movie_data | jq -r .alternativeName)
    country=$(echo $movie_data | jq -r .audience[].country)
    country=$(echo $country | sed -r "s/\s/, /g")
    movie_year=$(echo $movie_data | jq -r .year)
    movie_premiere_world=$(echo $movie_data | jq -r .premiere.world) 
    movie_premiere_world=$(date -d $movie_premiere_world +"%d.%m.%Y")
    movie_premiere_russia=$(echo $movie_data | jq -r .premiere.russia)
    movie_premiere_russia=$(date -d $movie_premiere_russia +"%d.%m.%Y")
    movie_rating_kp=$(echo $movie_data | jq -r .rating.kp)
    movie_rating_imdb=$(echo $movie_data | jq -r .rating.imdb)
    movie_votes_kp=$(echo $movie_data | jq -r .votes.kp)
    movie_votes_imdb=$(echo $movie_data | jq -r .votes.imdb)
    movie_genres=$(echo $movie_data | jq -r .genres[].name)
    movie_genres=$(echo $movie_genres | sed -r "s/\s/, /g")
    movie_description=$(echo $movie_data | jq -r .description)
    movie_trailer=$(echo $movie_data | jq -r .videos.trailers[].url)
    movie_sequels=$(echo $movie_data | jq -r .sequelsAndPrequels[].name | tr '\n' ',' | sed "s/,/, /g" | sed -r "s/, $//")
    movie_similar=$(echo $movie_data | jq -r .similarMovies[].name)
    data="*Название:* $movie_name ($movie_alternative_name)\n"
    data+="*Страна:* $country\n"
    data+="*Год:* $movie_year\n"
    data+="*Премьера в Мире:* $movie_premiere_world\n"
    data+="*Премьера в России:* $movie_premiere_russia\n"
    data+="*Рейтинг Кинопоиск:* $movie_rating_kp ($movie_votes_kp)\n"
    data+="*Рейтинг IMDb:* $movie_rating_imdb ($movie_votes_imdb)\n"
    data+="*Жанр:* $movie_genres\n\n"
    data+="*Описание:* $movie_description\n\n"
    data+="*Сиквелы и Приквелы:* $movie_sequels\n\n"
    data+="*Трейлеры:*\n"
    data+="$movie_trailer"
    encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
    IFS=$'\n'
    keyboard='{"inline_keyboard":['
    for movie_sim in $movie_similar; do
        movie_callback=$(echo $movie_sim | cut -c "1-50")
        keyboard+="[{\"text\":\"$movie_sim\",\"callback_data\":\"/search $movie_callback\"}],"
    done
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/find_kinozal_$GLOBAL_ID_FIND\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"},"
    keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard"
    fi
}

###### Telegram menu 🔵
### List torrent files
function menu-files {
    TEXT=$1
    CHAT=$2
    ls=$(ls -l $path | grep -E "*\.torrent" | awk '{print $9}' | sed -r "s/.torrent//")
    wc=$(ls -l $path | grep -E "*\.torrent" | wc -l)
    echo "[INFO] $(date '+%H:%M:%S'): Torrent files count: $wc" >> $path_log
    IFS=$'\n'
    keyboard='{"inline_keyboard":['
    for l in $ls; do
        torrent_id=$(echo $l | awk -F "-" '{print $1}')
        torrent_name=$(echo $l | sed -r "s/$torrent_id-//")
        torrent_name=$(echo $torrent_name | sed -r "s/_/ /g")
        keyboard+="[{\"text\":\"$torrent_name\",\"callback_data\":\"/find_kinozal_$torrent_id\"}],"
    done
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$TEXT" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$TEXT" "$CHAT" "$keyboard"
    fi
}

### List torrent
function menu-status {
    TEXT=$1
    CHAT=$2
    qb_state=$(qbittorrent-info)
    status=$(echo $qb_state | jq -r '.name + "---" + .hash')
    IFS=$'\n'
    keyboard='{"inline_keyboard":['
    for s in $status; do
        qb_name=$(echo $s | awk -F "---" '{print $1}')
        qb_hash=$(echo $s | awk -F "---" '{print $2}')
        qb_status=$(echo $qb_state | jq -r ". | select(.hash == \"$qb_hash\").state")
        qb_progress=$(echo $qb_state | jq -r ". | select(.hash == \"$qb_hash\").progress")
        if [[ $qb_status == "completed" || $qb_progress == "100 %" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/🆗 /")
        elif [[ $qb_status =~ "stalled" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/📶 /")
        elif [[ $qb_status =~ "paused" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⏸ /")
        elif [[ $qb_status =~ "download" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⬇️ /")
        elif [[ $qb_status =~ "seeding" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⬆️ /")
        else
            qb_name=$(echo $qb_name | sed -r "s/^/ℹ️ /")
        fi
        keyboard+="[{\"text\":\"$qb_name\",\"callback_data\":\"/info $qb_hash\"}],"
    done
    keyboard+="[{\"text\":\"🔄 Обновить статус\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"},"
    keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$TEXT" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$TEXT" "$CHAT" "$keyboard"
    fi
}

### Actions for selected torrent (response on /info) and update info for /pause, /resume
function menu-info {
    qb_hash=$1
    qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
    qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
    echo "[OK]   $(date '+%H:%M:%S'): Response on /info for $qb_name ($qb_hash)" >> $path_log
    qb_status=$(echo $qb_state | jq -r ".state")
    qb_progress=$(echo $qb_state | jq -r ".progress" | sed -r "s/\..+ %/ %/")
    qb_size=$(echo $qb_state | jq -r ".size")
    qb_size_total=$(echo $qb_state | jq -r ".size_total")
    qb_completed_size=$(echo $qb_state | jq -r ".completed_size")
    qb_download_speed=$(echo $qb_state | jq -r ".download_speed")
    qb_download_speed_limit=$(echo $qb_state | jq -r ".download_speed_limit")
    qb_uploaded=$(echo $qb_state | jq -r ".uploaded")
    qb_uploaded_speed=$(echo $qb_state | jq -r ".uploaded_speed")
    qb_uploaded_speed_limit=$(echo $qb_state | jq -r ".uploaded_speed_limit")
    qb_path=$(echo $qb_state | jq -r ".path")
    qb_added_date=$(echo $qb_state | jq -r ".added_date")
    qb_completion_date=$(echo $qb_state | jq -r ".completion_date")
    qb_last_activity_date=$(echo $qb_state | jq -r ".last_activity_date")
    ### Get properties
    qb_prop=$(qbittorrent-properties $qb_hash)
    qb_prop_comment=$(echo $qb_prop | jq -r ".comment")
    kinozal_id=$(echo $qb_prop_comment | sed -r "s/.+id=//")
    qb_prop_seeds=$(echo $qb_prop | jq -r ".seeds")
    qb_prop_seeds_total=$(echo $qb_prop | jq -r ".seeds_total")
    qb_prop_peers=$(echo $qb_prop | jq -r ".peers")
    qb_prop_peers_total=$(echo $qb_prop | jq -r ".peers_total")
    qb_prop_download_speed_avg=$(echo $qb_prop | jq -r ".download_speed_avg")
    keyboard="{
        \"inline_keyboard\":[
            [{\"text\":\"🔄 Обновить\",\"callback_data\":\"\/info $qb_hash\"},
            {\"text\":\"📖 Список файлов\",\"callback_data\":\"/torrent_content $qb_hash\"}],
            [{\"text\":\"⏸ Пауза\",\"callback_data\":\"\/pause $qb_hash\"},
            {\"text\":\"▶️ Возобновить\",\"callback_data\":\"\/resume $qb_hash\"}],
            [{\"text\":\"🗑 Удалить торрент\",\"callback_data\":\"\/delete_torrent $qb_hash\"},
            {\"text\":\"❌ Удалить видео\",\"callback_data\":\"\/delete_video $qb_hash\"}],
            [{\"text\":\"🔎 Кинозал\",\"callback_data\":\"/find_kinozal_$kinozal_id\"},
            {\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],
            [{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},
            {\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]
        ]
    }"
    qb_name=$(echo $qb_name | sed -r "s/_/ /g")
    data=$(echo "*Название:* $qb_name \n")
    data+=$(echo "*Статус загрузки:* $qb_status \n")
    data+=$(echo "*Прогресс:* $qb_progress \n")
    data+=$(echo "*Размер:* $qb_size ($qb_size_total)\n")
    data+=$(echo "*Загружено:* $qb_completed_size\n")
    data+=$(echo "*Скорость загрузки:* $qb_download_speed\n")
    data+=$(echo "*Средняя скорость:* $qb_prop_download_speed_avg\n")
    #data+=$(echo "*Лимит загрузки:* $qb_download_speed_limit\n")
    data+=$(echo "*Отдано:* $qb_uploaded ($qb_uploaded_speed)\n")
    #data+=$(echo "*Лимит отдачи:* $qb_uploaded_speed_limit \n")
    data+=$(echo "*Сиды:* $qb_prop_seeds (всего $qb_prop_seeds_total)\n")
    data+=$(echo "*Пиры:* $qb_prop_peers (всего $qb_prop_peers_total)\n")
    data+=$(echo "*Дата добавления:* $qb_added_date\n")
    data+=$(echo "*Дата загрузки:* $qb_completion_date\n")
    data+=$(echo "*Дата активности:* $qb_last_activity_date\n")
    data+=$(echo "*Описание:* $qb_prop_comment")
    #data+=$(echo "*Путь:* $qb_path")
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### Menu for /torrent_content and return from /file_torrent
function menu-torrent-content {
    qb_hash=$1
    # Set global vardiable for /file_torrent
    declare -g global_hash=$qb_hash
    qb_files=$(qbittorrent-files $qb_hash)
    qb_files_array=$(echo $qb_files | jq -r .[].name)
    qb_path=$(echo $qb_files_array | sed -r "s/\/.+//")
    echo "[INFO] $(date '+%H:%M:%S'): Selected torrent name: $qb_path" >> $path_log
    TEXT="Содержимое *$qb_path*:"
    IFS=$'\n'
    keyboard='{"inline_keyboard":['
    for qb_file_name in $qb_files_array; do
        qb_file_index=$(echo $qb_files | jq ".[] | select(.name == \"$qb_file_name\").index")
        qb_file_name_replace=$(echo $qb_file_name | sed -r "s/.+\///")
        keyboard+="[{\"text\":\"$qb_file_name_replace\",\"callback_data\":\"/file_torrent $qb_file_index\"}],"
    done
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/info $global_hash\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$TEXT" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$TEXT" "$CHAT" "$keyboard"
    fi
}

### Menu for /file_torrent and update torrent file in useed /torrent_content
function menu-torrent-file {
    file_index=$1
    file_info=$(qbittorrent-files $global_hash | jq ".[] | select(.index == $file_index)")
    file_name=$(echo $file_info | jq -r .name | sed -r "s/.+\///")
    echo "[INFO] $(date '+%H:%M:%S'): Selected file name: $file_name (index: $file_index)" >> $path_log
    # Set global vardiable for /torrent_priority
    declare -g global_file_index=$file_index
    progress=$(echo $file_info | jq -r '.progress * 100 | floor / 100 * 100 | tostring + " %"' | sed -r "s/\..+ %/ %/")
    priority_int=$(echo $file_info | jq -r .priority)
    ### Error: Bad Request: BUTTON_DATA_INVALID
    ### Размер "callback_data" должен быть меньше или равен 50 символам для латиницы и 25 для кириллицы (на самом деле 64 байта)
    keyboard='{"inline_keyboard":['
    if [[ $priority_int -eq 0 ]]; then
        priority="⏸ Пропустить"
        keyboard+="[{\"text\":\"▶️ Возобновить\",\"callback_data\":\"\/torrent_priority 1\"}],"
        keyboard+="[{\"text\":\"🔼 Высокий приоритет\",\"callback_data\":\"\/torrent_priority 6\"}],"
        keyboard+="[{\"text\":\"⏫ Масимальный приоритет\",\"callback_data\":\"\/torrent_priority 7\"}],"
    elif [[ $priority_int -eq 1 ]]; then
        priority="▶️ Обычный"
        keyboard+="[{\"text\":\"⏸ Пропустить\",\"callback_data\":\"\/torrent_priority 0\"}],"
        keyboard+="[{\"text\":\"🔼 Высокий приоритет\",\"callback_data\":\"\/torrent_priority 6\"}],"
        keyboard+="[{\"text\":\"⏫ Масимальный приоритет\",\"callback_data\":\"\/torrent_priority 7\"}],"
    elif [[ $priority_int -eq 6 ]]; then
        priority="⏫ Высокий"
        keyboard+="[{\"text\":\"⏸ Пропустить\",\"callback_data\":\"\/torrent_priority 0\"}],"
        keyboard+="[{\"text\":\"▶️ Обычный приоритет\",\"callback_data\":\"\/torrent_priority 1\"}],"
        keyboard+="[{\"text\":\"⏫ Масимальный приоритет\",\"callback_data\":\"\/torrent_priority 7\"}],"
    elif [[ $priority_int -eq 7 ]]; then
        priority="⏫ Максимальный"
        keyboard+="[{\"text\":\"⏸ Пропустить\",\"callback_data\":\"\/torrent_priority 0\"}],"
        keyboard+="[{\"text\":\"▶️ Обычный приоритет\",\"callback_data\":\"\/torrent_priority 1\"}],"
        keyboard+="[{\"text\":\"🔼 Высокий приоритет\",\"callback_data\":\"\/torrent_priority 6\"}],"
    fi
    ### Error: Bad Request: can't parse entities: Can't find end of the entity starting at byte offset 84
    ### В data не должно быть символов: "_", допустимо для text в keyboard
    file_name_space=$(echo $file_name | sed -r "s/_/ /g")
    data=$(echo "*Имя файла:* $file_name_space\n")
    data+=$(echo "*Прогресс:* $progress\n")
    data+=$(echo "*Приоритет:* $priority")
    encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
    keyboard+="[{\"text\":\"⬅️ Список файлов\",\"callback_data\":\"\/torrent_content $global_hash\"},"
    keyboard+="{\"text\":\"🔄 Обновить\",\"callback_data\":\"\/file_torrent $global_file_index\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$encoded_data" "$CHAT" "$keyboard"
    fi
}

### Plex main menu for selecting section
function menu-plex-status {
    command=$1
    CHAT=$2
    section_key=$(echo $command | sed "s/\/plex_status_//")
    # Set global vardiable for /find
    declare -g global_section_key=$section_key
    plex_sections=$(plex-sections | jq ".| select(.key == \"$section_key\")")
    plex_name=$(echo $plex_sections | jq -r .name)
    echo "[OK]   $(date '+%H:%M:%S'): Response on /plex_status for $plex_name (key: $section_key)" >> $path_log
    plex_type=$(echo $plex_sections | jq -r .type)
    plex_path=$(echo $plex_sections | jq -r .path)
    plex_scanned=$(echo $plex_sections | jq -r .scanned)
    plex_updated=$(echo $plex_sections | jq -r .updated)
    plex_created=$(echo $plex_sections | jq -r .created)
    data=$(echo "*Название:* $plex_name \n")
    data+=$(echo "*Последняя синхронизация:* $plex_scanned \n")
    data+=$(echo "*Тип данных:* $plex_type \n")
    data+=$(echo "*Путь на сервере:* $plex_path \n")
    data+=$(echo "*Дата обновления контента:* $plex_updated \n")
    data+=$(echo "*Дата создания секции:* $plex_created \n")
    keyboard='{"inline_keyboard":['
    keyboard+="[{\"text\":\"♻️ Синхронизировать данные\",\"callback_data\":\"\/plex_sync_$section_key\"}],"
    keyboard+="[{\"text\":\"📋 Содержимое директории\",\"callback_data\":\"\/plex_folder_$section_key\"}],"
    keyboard+="[{\"text\":\"⏯ Последние просмотры\",\"callback_data\":\"\/plex_last_views\"}],"
    keyboard+="[{\"text\":\"*️⃣ Последние добавления\",\"callback_data\":\"\/plex_last_added\"}],"
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### Menu for searching content in Plex
function menu-plex-find {
    json_data=$1
    data=$2
    CHAT=$3
    type=$4
    ###! To create an array, take one element from each json object
    data=""
    array_data=$(echo $json_data | jq -r .endpoint)
    IFS=$'\n'
    for a in $array_data; do
        ###! Filter objects by element name unique to access its child values
        data_temp=$(echo $json_data | jq ". | select(.endpoint == \"$a\")")
        type_temp=$(echo $data_temp | jq -r .type)
        if [[ $type_temp != "folder" ]]; then
            name_temp=$(echo $data_temp | jq -r .name | sed "s/_/ /g")
            size_temp=$(echo $data_temp | jq -r .size)
            duration=$(echo $data_temp | jq -r .duration)
            video_temp=$(echo $data_temp | jq -r .video)
            quality_temp=$(echo $data_temp | jq -r .quality)
            format_temp=$(echo $data_temp | jq -r .format)
            #video_codec_temp=$(echo $data_temp | jq -r .video_codec)
            #audio_codec_temp=$(echo $data_temp | jq -r .audio_codec)
            added_temp=$(echo $data_temp | jq -r .added)
            data+=$(echo "📋 $name_temp\n")
            if [[ $type == "last_view" ]]; then
                last_view=$(echo $data_temp | jq -r .last_view)
                data+=$(echo "*Дата последнего просмотра:* $last_view\n")
                stop_time=$(echo $data_temp | jq -r ".stop_time / 1000 | strftime(\"%T\")")
                data+=$(echo "*Время просмотра:* $stop_time\n")
            fi
            data+=$(echo "*Продолжительность:* $duration\n")
            data+=$(echo "*Разрешение:* $video_temp ($quality_temp)\n")
            data+=$(echo "*Расширение:* $format_temp\n")
            data+=$(echo "*Размер:* $size_temp\n")
            #data+=$(echo "*Видео/Аудио кодек:* $video_codec_temp/$audio_codec_temp\n")
            data+=$(echo "*Дата добавления:* $added_temp\n\n")
        else
            name_temp=$(echo $data_temp | jq -r .name | sed "s/_/ /g")
            endpoint_temp=$(echo $data_temp | jq -r .endpoint)
            data+=$(echo "🗂 $name_temp\n")
            data+=$(echo "\`/find $endpoint_temp\`\n\n")
        fi
    done
    encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
    keyboard='{"inline_keyboard":['
    if [[ $type == "last_view" ]]; then
        keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/plex_status_$global_section_key\"},"
    else
        keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/plex_folder_$global_section_key\"},"
    fi
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$encoded_data" "$CHAT" "$keyboard"
    fi
}

###### Thread 1️⃣
### Chat-Bot (reading Telegram requests and sending response messages)
LOG_INTERACTIONS="False"
start_time=$(date +%s)
count_interaction=0
test_code=0
message_id_temp="null"
update_id_temp=""
while :
    do
    if [[ $LOG_INTERACTIONS == "True" ]]; then
        ((count_interaction++))
        end_time=$(date +%s)
        sum_time=$((end_time - start_time))
        if [[ $sum_time -ge 60 ]]; then
            echo "[INFO] $(date '+%H:%M:%S'): $count_interaction interactions in minute ($sum_time seconds)" >> $path_log
            start_time=$(date +%s)
            count_interaction=0
        fi
    fi
    ### Check Telegram and Internet
    if [[ $CHECK_TG_AND_INTERNET == "True" ]]; then
        tg_test=$(test-telegram)
        if [ -z "$tg_test" ]; then
            test_code=1
            echo "[ERRO] $(date '+%H:%M:%S'): Telegram api not avaliable" >> $path_log
            ping=$(ping 8.8.8.8 -c 2 | grep -i ttl)
            if [ -z "$ping" ]; then
                test_code=2
                echo "[ERRO] $(date '+%H:%M:%S'): Internet not avaliable" >> $path_log
            fi
            sleep $TIMEOUT_SEC_ERROR
            continue
        else
            if [[ $test_code == 1 ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Telegram api avaliable" >> $path_log
            elif [[ $test_code == 2 ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Internet avaliable" >> $path_log
            fi
            test_code=0
        fi
    fi
    ### Read Telegram
    last_message=$(read-telegram)
    date=$(echo $last_message | jq ".timestamp")
    update_id=$(echo $last_message | jq -r ".update_id")
    user=$(echo $last_message | jq ".user" | sed -r 's/\"//g')
    CHAT=$(echo $last_message | jq ".chat" | sed -r 's/\"//g')
    command=$(echo $last_message | jq ".text" | sed -r 's/\"//g')
    ### Check type last massage (command or keyboard)
    message_id=$(echo $last_message | jq -r ".message_id")
    if [[ -n $message_id && $message_id != "null" ]]; then
        message_id_temp="$message_id"
    else
        message_id_temp="null"
    fi
    if [[ $update_id > $update_id_temp ]]; then
        update_id_temp=$update_id
        echo "[OK]   $(date '+%H:%M:%S'): Request command from user: $user ($CHAT)" >> $path_log
        ### Request: /download_torrent id name ⬇️
        if [[ $command == /download_torrent* ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Response on /download_torrent" >> $path_log
            down_id=$(echo $command | awk '{print $2}')
            down_name=$(echo $command | awk '{print $3}')
            if [[ $down_name == "GLOBAL_NAME" ]]; then
                down_name=$global_name_down
            fi
            echo "[INFO] $(date '+%H:%M:%S'): Torrent file name: $down_id-$down_name.torrent" >> $path_log
            download-torrent "$down_id" "$down_name"
            file_path="$path/$down_id-$down_name.torrent"
            if [ -e $file_path ]; then
                echo "[INFO] $(date '+%H:%M:%S'): Torrent file downloaded: $file_path" >> $path_log
                file_size=$(ls -lh $file_path | awk '{print $5}')
                echo "[INFO] $(date '+%H:%M:%S'): File size: $file_size" >> $path_log
                file_test=$(cat "$file_path" | grep "javascript")
                if [ -z "$file_test" ]; then
                    echo "[OK]   $(date '+%H:%M:%S'): Torrent file uploaded" >> $path_log
                    data=$(echo "Торрент файл загружен успешно (размер: $file_size)")
                else
                    echo "[WARN] $(date '+%H:%M:%S'): Torrent file downloaded with error (found javascript to file)" >> $path_log
                    data=$(echo "Торрент файл загружен с ошибкой (размер: $file_size)")
                fi
                encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                keyboard="{
                    \"inline_keyboard\":[
                        [{\"text\":\"⬆️ Добавить в торрент на загрузку\",\"callback_data\":\"\/download_video_$down_id\"}],
                        [{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"}],
                        [{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],
                        [{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]
                    ]
                }"
                if [[ $message_id_temp != "null" ]]; then
                    edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
                else
                    send-keyboard "$encoded_data" "$CHAT" "$keyboard"
                fi
            else
                echo "[WARN] $(date '+%H:%M:%S'): Torrent file not uploaded (possible connection error)" >> $path_log
                send-telegram "Ошибка при загрузке торрент файла (файл не загружен)." "$CHAT"
            fi
        ### Request: /profile
        elif [[ $command == /profile ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Response on /profile" >> $path_log
            count-torrent
        ### Request: /torrent_files 📚🗂
        elif [[ $command == /torrent_files ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Response on /torrent_files" >> $path_log
            menu-files "🗂 Список загруженных торрент файлов:" $CHAT
        ### Request: /delete_torrent_file_id 📚🗂🗑
        elif [[ $command == /delete_torrent_file_* ]]; then
            filename_id=$(echo $command | sed "s/\/delete_torrent_file_//")
            filename=$(ls -l $path | grep -E "*\.torrent" | grep "$filename_id" | awk '{print $9}')
            echo "[OK]   $(date '+%H:%M:%S'): Response on /delete_torrent_file on $filename ($filename_id)" >> $path_log
            file_path="$path/$filename"
            wc_be=$(ls -l $path | grep -E "*\.torrent" | wc -l)
            rm $file_path
            wc_af=$(ls -l $path | grep -E "*\.torrent" | wc -l)
            echo "[INFO] $(date '+%H:%M:%S'): Before torrent files: $wc_be, after torrent files: $wc_af" >> $path_log
            if [[ $wc_af < $wc_be ]]; then
                menu-files "🗂 Торрент файл удален:" $CHAT
            else
                menu-files "🗂 Торрент файл не удален:" $CHAT
                echo "[ERRO] $(date '+%H:%M:%S'): Error delete torrent file" >> $path_log
            fi
        ### Request: /find_kinozal_id 🔎
        elif [[ $command == /find_kinozal_* ]]; then
            id_find=$(echo $command | sed "s/\/find_kinozal_//")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /find_kinozal for $id_find" >> $path_log
            id_url="https://kinozal.tv/details.php?id=$id_find"
            echo "[INFO] $(date '+%H:%M:%S'): Url: $id_url" >> $path_log
            if [[ $PROXY == "True" ]]; then
                URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
                html=$(curl -s -x $URL_PROXY $id_url | iconv -f windows-1251 -t UTF-8)
            else
                html=$(curl -s $id_url | iconv -f windows-1251 -t UTF-8)
            fi
            if [ -n "$html" ]; then
                data=$(read-html "$html" "$id_url" "Chat")
                encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                keyboard=$(get-links "$id_find" "$html" "find")
                # Set global vardiable for /download_torrent via menu (function get-links)
                name_down=$(get-global-name "$html")
                declare -g global_name_down=$name_down
                echo "[INFO] $(date '+%H:%M:%S'): Set name for download: $global_name_down" >> $path_log
                # Global variables to go back
                declare -g GLOBAL_ID_FIND=$id_find
                if [[ $message_id_temp != "null" ]]; then
                    edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
                else
                    send-keyboard "$encoded_data" "$CHAT" "$keyboard"
                fi
                echo "[INFO] $(date '+%H:%M:%S'): HTML data avaliable, sending data to chat: $id_url" >> $path_log
            else
                echo "[ERRO] $(date '+%H:%M:%S'): HTML data not avaliable (connection problem or torrent file invalid id): $id_url" >> $path_log
                keyboard="{
                    \"inline_keyboard\":[
                        [{\"text\":\"🗑 Удалить торрент файл\",\"callback_data\":\"\/delete_torrent_file_$id_find\"}],
                        [{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},
                        {\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]
                    ]
                }"
                if [[ $message_id_temp != "null" ]]; then
                    edit-keyboard "Торрент файл (id: $id_find) не найден в базе Кинозала (возможна проблема соединения)." "$CHAT" "$keyboard" "$message_id_temp"
                else
                    send-keyboard "Торрент файл (id: $id_find) не найден в базе Кинозала (возможна проблема соединения)." "$CHAT" "$keyboard"
                fi
            fi
        ### Request: /kinozal_description 🟣ℹ️🔗👤👥
        elif [[ $command == /kinozal_description* ]]; then
            id_find=$(echo $command | sed "s/\/kinozal_description //")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /kinozal_description for $id_find" >> $path_log
            id_url="https://kinozal.tv/details.php?id=$id_find"
            if [[ $PROXY == "True" ]]; then
                URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
                html=$(curl -s -x $URL_PROXY $id_url | iconv -f windows-1251 -t UTF-8)
            else
                html=$(curl -s $id_url | iconv -f windows-1251 -t UTF-8)
            fi
            description=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_toprs" | tail -n 1 | sed -r 's/.+<\/span><\/h2><\/div><div class="bx1 justify"><p><b>//; s/<\/p>.+//; s/.+<\/b> //')
            director=$(printf "%s\n" "${html[@]}" | grep -i "режиссер" | sed -r 's/.+toprs>//; s/<.+//')
            actors=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_toprs" | tail -n 1 | sed -r 's/.+toprs>//; s/<.+//')
            ### В тексте не должно быть символа "`"
            actors=$(echo $actors | sed "s/\`/'/g")
            data=$(echo "ℹ️ *Описание:* $description\n\n")
            data+=$(echo "👤 *Режисcер:* $director \n\n")
            data+=$(echo "👥 *Актеры:* $actors \n\n")
            data+=$(echo "🔗 *Топ по жанрам:*")
            encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
            keyboard=$(get-links "$id_find" "$html" "description")
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$encoded_data" "$CHAT" "$keyboard"
            fi
        ### Request: /kinozal_actors 👥
        elif [[ $command == /kinozal_actors* ]]; then
            id_find=$(echo $command | sed "s/\/kinozal_actors //")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /kinozal_actors for $id_find" >> $path_log
            id_url="https://kinozal.tv/details.php?id=$id_find"
            if [[ $PROXY == "True" ]]; then
                URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
                html=$(curl -s -x $URL_PROXY $id_url | iconv -f windows-1251 -t UTF-8)
            else
                html=$(curl -s $id_url | iconv -f windows-1251 -t UTF-8)
            fi
            actors=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_toprs" | tail -n 1 | sed -r 's/.+toprs>//; s/<.+//')
            actors=$(echo $actors | sed "s/\`/'/g")
            actors=$(echo $actors | sed "s/, /,/g")
            ###! Создать массив на элементы, разделенные запятой
            IFS=',' read -r -a actors_array <<< $actors
            keyboard='{"inline_keyboard":['
            for actor in "${actors_array[@]}"; do
                keyboard+="[{\"text\":\"$actor\",\"callback_data\":\"\/actor $actor\"}],"
            done
            keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/find_kinozal_$id_find\"},"
            keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
            keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
            keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
            data=$(echo "👥 *Список актеров:*")
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$data" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$data" "$CHAT" "$keyboard"
            fi
        ### Request: /search 🔎
        elif [[ $command == /search* ]]; then
            search_name=$(echo $command | sed "s/\/search //")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /search for $search_name" >> $path_log
            get-search "$search_name"
        ### Request: /actor 👥
        elif [[ $command == /actor* ]]; then
            actor_name=$(echo $command | sed "s/\/actor //")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /actor for $actor_name" >> $path_log
            get-actor "$actor_name"
        ### Request: /kinopoisk_movie 🟡
        elif [[ $command == /kinopoisk_movie* ]]; then
            id_kz_search=$(echo $command | sed "s/\/kinopoisk_movie //")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /kinopoisk_movie" >> $path_log
            echo "[OK]   $(date '+%H:%M:%S'): Search on id Kinozal: $id_kz_search" >> $path_log
            id_kp=$(get-kp-id "$id_kz_search")
            echo "[OK]   $(date '+%H:%M:%S'): Search on id Kinopoisk: $id_kp" >> $path_log
            get-movie-kinopoisk-id "$id_kp"
        ### Request: /status 🟢🐸
        elif [[ $command == /status ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Response on /status" >> $path_log
            qb_check=$(qbittorrent-test)
            if [[ $qb_check == 1 ]]; then
                send-telegram "Ошибка авторизации на сервере qBittorrent" "$CHAT"
            elif [[ $qb_check == 2 ]]; then
                send-telegram "Приложение qBittorrent недоступно" "$CHAT"
            elif [[ $qb_check == 3 ]]; then
                send-telegram "Сервер qBittorrent недоступен" "$CHAT"
            else
                menu-status "🐸 Список загружаемых торрентов:" "$CHAT"
            fi
        ### Request: /info hash 🔄
        elif [[ $command == /info* ]]; then
            qb_hash=$(echo $command | sed "s/\/info //")
            menu-info $qb_hash
        ### Request: /torrent_content hash 📖
        elif [[ $command == /torrent_content* ]]; then
            qb_hash=$(echo $command | sed "s/\/torrent_content //")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /torrent_content for torrent hash: $qb_hash" >> $path_log
            menu-torrent-content "$qb_hash"
        ### Request: /file_torrent index
        elif [[ $command == /file_torrent* ]]; then
            file_index=$(echo $command | sed "s/\/file_torrent //")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /file_torrent for torrent file index: $file_index" >> $path_log
            menu-torrent-file "$file_index"
        ### Request: /torrent_priority num_priority
        elif [[ $command == /torrent_priority* ]]; then
            num_priority=$(echo $command | sed "s/\/torrent_priority //")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /torrent_priority: $num_priority" >> $path_log
            qbittorrent-priority $global_hash $global_file_index $num_priority
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            menu-torrent-file "$global_file_index"
        ### Request: /download_video_id ⬇️
        elif [[ $command == /download_video_* ]]; then
            id_down=$(echo $command | sed "s/\/download_video_//")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /download_video for $id_down" >> $path_log
            wc_be=$(qbittorrent-info | jq .name | wc -l)
            start=$(qbittorrent-download $id_down)
            wc_af=$(qbittorrent-info | jq .name | wc -l)
            echo "[INFO] $(date '+%H:%M:%S'): Before: $wc_be, after: $wc_af" >> $path_log
            if [[ $wc_af > $wc_be ]]; then
                echo "[INFO] $(date '+%H:%M:%S'): Download started" >> $path_log
                menu-status "🐸 Торрент добавлен в загрузку:" "$CHAT"
            else
                if [[ $start == "Fails." ]]; then
                    echo "[WARN] $(date '+%H:%M:%S'): Already downloading (response: Fails)" >> $path_log
                    menu-status "🐸 Торрент уже добавлен:" "$CHAT"
                else
                    echo "[WARN] $(date '+%H:%M:%S'): Download not started (response: Null)" >> $path_log
                    menu-status "🐸 Торрент файл не добавлен (ошибка):" "$CHAT"
                fi
            fi
        ### Request: /pause hash ⏸
        elif [[ $command == /pause* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/pause //")
            qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
            qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[OK]   $(date '+%H:%M:%S'): Response on /pause for $qb_name ($qb_hash)" >> $path_log
            echo "[INFO] $(date '+%H:%M:%S'): Before status: $qb_status" >> $path_log
            qbittorrent-pause "$qb_hash"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[INFO] $(date '+%H:%M:%S'): After status: $qb_status" >> $path_log
            menu-info "$qb_hash"
        ### Request: /resume hash ▶️
        elif [[ $command == /resume* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/resume //")
            qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
            qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[OK]   $(date '+%H:%M:%S'): Response on /resume for $qb_name ($qb_hash)" >> $path_log
            echo "[INFO] $(date '+%H:%M:%S'): Before status: $qb_status" >> $path_log
            qbittorrent-resume "$qb_hash"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[INFO] $(date '+%H:%M:%S'): After status: $qb_status" >> $path_log
            menu-info "$qb_hash"
        ### Request: /delete_torrent hash 🗑
        elif [[ $command == /delete_torrent* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/delete_torrent //")
            qb_state_all=$(qbittorrent-info)
            wc_be=$(echo $qb_state_all | jq .name | wc -l)
            qb_state=$(echo $qb_state_all | jq ". | select(.hash == \"$qb_hash\")")
            qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[OK]   $(date '+%H:%M:%S'): Response on /delete_torrent for $qb_name ($qb_hash)" >> $path_log
            echo "[INFO] $(date '+%H:%M:%S'): Before count: $wc_be" >> $path_log
            qbittorrent-delete "$qb_hash" "false"
            wc_af=$(qbittorrent-info | jq .name | wc -l)
            echo "[INFO] $(date '+%H:%M:%S'): After: $wc_af" >> $path_log
            if [[ $wc_af < $wc_be ]]; then
                echo "[INFO] $(date '+%H:%M:%S'): Torrent file deleted" >> $path_log
                menu-status "🐸 Торрент файл удален:" "$CHAT"
            else
                echo "[WARN] $(date '+%H:%M:%S'): Torrent file not deleted" >> $path_log
                menu-status "🐸 Возникла ошибка при удалении:" "$CHAT"
            fi
        ### Request: /delete_video hash ❌
        elif [[ $command == /delete_video* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/delete_video //")
            qb_state_all=$(qbittorrent-info)
            wc_be=$(echo $qb_state_all | jq .name | wc -l)
            qb_state=$(echo $qb_state_all | jq ". | select(.hash == \"$qb_hash\")")
            qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[OK]   $(date '+%H:%M:%S'): Response on /delete_video for $qb_name ($qb_hash)" >> $path_log
            echo "[INFO] $(date '+%H:%M:%S'): Before count: $wc_be" >> $path_log
            qbittorrent-delete "$qb_hash" "true"
            wc_af=$(qbittorrent-info | jq .name | wc -l)
            echo "[INFO] $(date '+%H:%M:%S'): After: $wc_af" >> $path_log
            if [[ $wc_af < $wc_be ]]; then
                echo "[INFO] $(date '+%H:%M:%S'): Torrent file and video content deleted" >> $path_log
                menu-status "🐸 Торрент файл и видео контент удалены:" "$CHAT"
            else
                echo "[WARN] $(date '+%H:%M:%S'): Torrent file and video content not deleted" >> $path_log
                menu-status "🐸 Возникла ошибка при удалении:" "$CHAT"
            fi
        ### Request: /plex_info 🟠
        elif [[ $command == /plex_info ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Response on /plex_info" >> $path_log
            plex_sections=$(plex-sections | jq -r ".name,.key")
            IFS=$'\n'
            name_section=""
            key_section=""
            keyboard='{"inline_keyboard":['
            for p in $plex_sections; do
                if [ -z "$name_section" ]; then
                    name_section="$p"
                else
                    key_section="$p"
                    keyboard+="[{\"text\":\"$name_section\",\"callback_data\":\"/plex_status_$key_section\"}],"
                    name_section=""
                    key_section=""
                fi
            done
            keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
            keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
            data="🍿 Выберите секцию в plex для доступа к его контенту:"
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$data" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$data" "$CHAT" "$keyboard"
            fi
        ### Request: /plex_status_key
        elif [[ $command == /plex_status_* ]]; then
            menu-plex-status "$command" "$CHAT"
        ### Request: /plex_sync_key ♻️
        elif [[ $command == /plex_sync_* ]]; then
            section_key=$(echo $command | sed "s/\/plex_sync_//")
            plex_sections=$(plex-sections | jq ". | select(.key == \"$section_key\")")
            plex_name=$(echo $plex_sections | jq -r .name)
            echo "[OK]   $(date '+%H:%M:%S'): Response on /plex_sync for $plex_name (key: $section_key)" >> $path_log
            plex_scanned=$(echo $plex_sections | jq -r .scanned)
            echo "[OK]   $(date '+%H:%M:%S'): Before scanned: $plex_scanned" >> $path_log
            plex-sync-section "$section_key"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            plex_sections=$(plex-sections | jq ". | select(.key == \"$section_key\")")
            plex_scanned=$(echo $plex_sections | jq -r .scanned)
            echo "[OK]   $(date '+%H:%M:%S'): After scanned: $plex_scanned" >> $path_log
            menu-plex-status "/plex_status_$section_key"
        ### Request: /plex_folder_key 📋🎥🎧
        elif [[ $command == /plex_folder_* ]]; then
            section_key=$(echo $command | sed "s/\/plex_folder_//")
            echo "[OK]   $(date '+%H:%M:%S'): Response on /plex_folder for key: $section_key" >> $path_log
            plex_folder=$(plex-folder-from-section "$section_key")
            plex_foleer_name=$(echo $plex_folder | jq -r ".name")
            IFS=$'\n'
            data=$(echo "Содержимое:\n")
            for p in $plex_foleer_name; do
                test_folder=$(echo $plex_folder | jq -r ". | select(.name == \"$p\").type")
                if [[ $test_folder == "null" ]]; then
                    data+=$(echo "🗂 \`$p\`\n")
                elif [[ $test_folder == "track" ]]; then
                    data+=$(echo "🎧 \`$p\`\n")
                else
                    data+=$(echo "🎥 \`$p\`\n")
                fi
            done
            data+=$(echo "\nДля вывода содержимого используйте команду: */find* и передайте параметр название директории или файла")
            encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
            keyboard='{"inline_keyboard":['
            keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/plex_status_$global_section_key\"},"
            keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
            keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
            keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$encoded_data" "$CHAT" "$keyboard"
            fi
        ### Request: /find "folder name or file name or path (endpoint)"
        elif [[ $command == /find* ]]; then
            folder_name=$(echo $command | sed "s/\/find //")
            if [[ $folder_name == $command ]]; then
                echo "[WARN] $(date '+%H:%M:%S'): Response on $command invalid. Valid response: \"/find folder or file name\"" >> $path_log
            else
                echo "[OK]   $(date '+%H:%M:%S'): Response on /find for $folder_name to Plex" >> $path_log
                if [[ $folder_name == /* ]]; then
                    echo "[INFO] $(date '+%H:%M:%S'): Find on endpoint: $folder_name" >> $path_log
                    endpoint=$folder_name
                    json_data=$(plex-content-from-folder "$endpoint")
                    data=$(echo "Содержимое указанной директории:\n\n")
                else
                    echo "[INFO] $(date '+%H:%M:%S'): Find on folder: $folder_name" >> $path_log
                    endpoint=$(plex-folder-from-section $global_section_key | jq -r ". | select(.name == \"$folder_name\").endpoint")
                    echo "[INFO] $(date '+%H:%M:%S'): Get endpoint for find: $endpoint" >> $path_log
                    json_data=$(plex-content-from-folder "$endpoint")
                    data=$(echo "Содержимое *$folder_name*:\n\n")
                fi
                menu-plex-find "$json_data" "$data" "$CHAT"
            fi
        ### Request: /plex_last_views ⏯
        elif [[ $command == /plex_last_views ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Response on /plex_last_views" >> $path_log
            endpoint="/library/onDeck"
            json_data=$(plex-content-from-folder "$endpoint")
            data=$(echo "Список последних просмотров:\n\n")
            menu-plex-find "$json_data" "$data" "$CHAT" "last_view"
        ### Request: /plex_last_added *️⃣
        elif [[ $command == /plex_last_added ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Response on /plex_last_added" >> $path_log
            endpoint="/library/recentlyAdded"
            PLEX_ADDR=$PLEX_ADDR
            PLEX_TOKEN=$PLEX_TOKEN
            plex_dir=$(curl -s -X GET "$PLEX_ADDR$endpoint" \
                -H "X-Plex-Token: $PLEX_TOKEN" \
                -H "accept: application/json" | jq ".MediaContainer.Metadata[]")
            name_and_date=$(echo $plex_dir | jq ". | {
                name: .title,
                date: (.addedAt $DATA_TIMEZONE * 3600 | strftime(\"%d.%m.%Y\"))
            }")
            data=$(echo $name_and_date | jq -r "{data: \"\(.date) - *\(.name)*\"}.data")
            encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
            keyboard='{"inline_keyboard":['
            keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/plex_status_$global_section_key\"},"
            keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
            keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
            keyboard+="{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$encoded_data" "$CHAT" "$keyboard"
            fi      
        else
            echo "[WARN] $(date '+%H:%M:%S'): Command not found: $command" >> $path_log
        fi
    fi
done &

###### Thread 2️⃣
### Channel News (post news to channel from kinozal)
link_temp="null"
while :
    do
    if [[ $PROXY == "True" ]]; then
        URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
        rss=$(curl -s -x $URL_PROXY "https://kinozal.tv/rss.xml")
    else
        rss=$(curl -s https://kinozal.tv/rss.xml)
    fi
    if [ -n "$rss" ]; then
        links=($(printf "%s\n" "${rss[@]}" | grep "<link>https://kinozal.tv/details" | sed -r 's/<link>|<\/link>//g'))
        link=$(echo ${links[0]})
        if [ $link != $link_temp ]; then
            echo "[INFO] $(date '+%H:%M:%S'): RSS data updated"  >> $path_log
            unset array
            for l in ${links[@]}; do
                if [ $l != $link_temp ]; then
                    array+=($l)
                else
                    break
                fi
            done
            if [ $(echo ${#array[@]}) -ge 10 ]; then
                unset array
                array+=(${links[@]:0:1})
            fi
            count_all=$(echo ${#array[@]})
            count_post=0
            count_skip=0
            count_error=0
            for a in ${array[@]}; do
                if [[ $PROXY == "True" ]]; then
                    html=$(curl -s -x $URL_PROXY $a | iconv -f windows-1251 -t UTF-8)
                else
                    html=$(curl -s $a | iconv -f windows-1251 -t UTF-8)
                fi
                if [ -n "$html" ]; then
                    rating_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+floatright">//; s/<.+//')
                    rating_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r 's/.+floatright">//; s/<.+//')
                    year=$(printf "%s\n" "${html[@]}" | grep -E -B 1 "class=lnks_tobrs" | head -n 1 | sed -r 's/.+<\/b> //; s/<.+//')
                    ### Filtering content by rating
                    if [[ ($rating_kp == "—" || $rating_kp < $RATING_KP) && $rating_imdb < $RATING_IMDB ]]; then
                        ((count_skip++))
                        echo "[INFO] $(date '+%H:%M:%S'): Skip: $a (rating kp: $rating_kp and imdb: $rating_imdb)" >> $path_log
                        continue
                    ### Filtering content by year
                    elif [[ $year < $FILTER_YEAR ]]; then
                        ((count_skip++))
                        echo "[INFO] $(date '+%H:%M:%S'): Skip: $a (year: $year)" >> $path_log
                        continue
                    else
                        ((count_post++))
                        echo "[OK]   $(date '+%H:%M:%S'): Post: $a (year: $year, rating kp: $rating_kp and imdb: $rating_imdb)" >> $path_log
                        data=$(read-html "$html" "$a" "Channel")
                        encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                        send-telegram "$encoded_data" "$TG_CHANNEL"
                    fi
                else
                    ((count_error++))
                    echo "[ERRO] $(date '+%H:%M:%S'): HTML data not avaliable: $a" >> $path_log
                fi
            done
            echo "[INFO] $(date '+%H:%M:%S'): All records: $count_all, post: $count_post, skip: $count_skip, error: $count_error" >> $path_log
            link_temp=$link
            echo "[INFO] $(date '+%H:%M:%S'): Update last link: $link_temp" >> $path_log
        else
            echo "[INFO] $(date '+%H:%M:%S'): RSS no new data. Last link: $link_temp" >> $path_log
        fi
        sleep $TIMEOUT_SEC_POST
    else
        echo "[ERRO] $(date '+%H:%M:%S'): RSS data not avaliable" >> $path_log
        sleep $TIMEOUT_SEC_ERROR
    fi
done &