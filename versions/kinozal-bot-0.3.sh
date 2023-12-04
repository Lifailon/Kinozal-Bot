#!/bin/bash

# Stack:
# kinozal.tv: read RSS, receiving data from html (no api) and filtering by rating, download torrent files
# Optional: Proxy server with VPN (Split Tunneling mode) for access to kinozal (example: HandyCache and Hotspot Shield)
# Telegram api: send news to channel (thread 2), message reading (only commands) and answers in menu (keyboard) format (thread 1)
# qBittorrent api: download from torrent files and managment data
# Plex Media Server api: view and sync content

# Change log:
# 16.11.2023 (0.1) - Creat kinozal news channel and Telegram bot for download torrent files and qBittorrent managment
# 27.11.2023 (0.2) - Added Telegram keyboard menu, delete torrent files and get count downloaded to profile kinozal
# 30.11.2023 (0.3) - Added Plex functions and commands for view and sync content

# Bot commands (Menu):
# /torrent_files - Torrent files
# /status - qBittorrent manager
# /plex_info - Plex content
# /find - Find content to Plex
# /count_torrent - Количество загрузок в профиле Кинозал
# /download_torrent - Загрузить торрент файл (передать два параметра: id и имя файла через пробел)
# /delete_torrent_file_id - Удалить торрент файл по id
# /find_kinozal_id - Поиск в Кинозал по id
# /download_video_id - Загрузить из торрент файла
# /info - Статус загрузки указанного торрента (передать параметр: hash торрент файла)
# /pause - Установить на паузу
# /resume - Восстановить загрузку
# /delete_torrent - Удалить торрент из загрузки
# /delete_video - Удалить вместе с видео данными
# /plex_status_key - Информация о выбранной секции в Plex (передать параметр: ключ секции)
# /plex_sync_key - Синхронизировать указанную секцию в Plex
# /plex_folder_key - Получить список директорий и файлов в выбранной секции

### Read configuration
conf="./kinozal-bot.conf"
source "$conf"
TG_CHAT_ARRAY=($(echo $TG_CHAT | tr ',' ' '))

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
    exit
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

###### Telegram
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
    curl -s $url -X "GET" \
        -d chat_id=$chat \
        -d text="$text" \
        -d "parse_mode=$mode" 1> /dev/null
}

### Send keyboard to Telegram
function send-keyboard {
    text=$1
    chat=$2
    reply_markup=$3
    endpoint="sendMessage"
    mode="markdown"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    curl -s $url -X POST \
        -d "chat_id=$chat" \
        -d "text=$text" \
        -d "parse_mode=$mode" \
        -d "reply_markup=$reply_markup" 1> /dev/null
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
    curl -s $url -X POST \
        -d "chat_id=$chat" \
        -d "text=$text" \
        -d "parse_mode=$mode" \
        -d "reply_markup=$reply_markup" \
        -d "message_id=$message_id" 1> /dev/null
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
                date: (.message.date + 3 * 3600 | strftime("%d.%m-%H:%M:%S")),
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
                date: (.callback_query.message.date + 3 * 3600 | strftime("%d.%m-%H:%M:%S")),
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

###### qBittorrent
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
        --header "Referer: $QB_ADDR" | jq ".[] | {\
            name: .name,
            hash: .hash,
            path: .content_path,
            state: .state,
            progress: (.progress * 100 | floor / 100 * 100 | tostring + \" %\"),
            size: (.size / 1024 / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + \" GB\")
        }"
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

###### Plex Media Server
### No official documentation
### All sections (root derictory) and date last scanned
function plex-sections {
    PLEX_ADDR=$PLEX_ADDR
    PLEX_TOKEN=$PLEX_TOKEN
    endpoint="library/sections"
    plex_dir=$(curl -s -X GET "$PLEX_ADDR/$endpoint" \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        -H "accept: application/json" | jq ".MediaContainer.Directory[]")
    echo $plex_dir | jq '{
        name: .title,
        key: .key,
        type: .type,
        path: .Location[].path,
        scanned: (.scannedAt + 3 * 3600 | strftime("%H:%M:%S %d.%m.%Y")),
        updated: (.updatedAt + 3 * 3600 | strftime("%H:%M:%S %d.%m.%Y")),
        created: (.createdAt + 3 * 3600 | strftime("%H:%M:%S %d.%m.%Y")),
    }' 
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
    echo $plex_dir | jq '
        if .type != null then {
            name: .title,
            endpoint: .key,
            type: .type,
            path: .Media[].Part[].file,
            size: (.Media[].Part[].size / 1024 / 1024 / 1024 | tonumber * 100 | floor / 100 | tostring + " GB"),
            duration: (.Media[].duration / 1000 | strftime("%T")),
            format: .Media[].Part[].container,
            FrameRate: .Media[].videoFrameRate,
            quality: ((.Media[].width | tostring)+"x"+(.Media[].height | tostring)),
            video: .Media[].videoResolution,
            video_codec: .Media[].videoCodec,
            audio_codec: .Media[].audioCodec,
            audio_channels: .Media[].audioChannels,
            year: .year,
            originally: .originallyAvailableAt,
            last_view: (.lastViewedAt + 3 * 3600 | strftime("%H:%M:%S %d.%m.%Y")),
            added: (.addedAt + 3 * 3600 | strftime("%H:%M:%S %d.%m.%Y")),
            update: (.updatedAt + 3 * 3600 | strftime("%H:%M:%S %d.%m.%Y"))
        }
        else {
            name: .title,
            endpoint: .key,
            type: "folder"
        } end
    '
}

###### Kinozal
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

### Daily download statistics to Kinozal profile
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
        count_torrent=$(curl -s -L $url_profile -X GET \
            -x $URL_PROXY \
            -b $path_kz_cookies \
            -H "Referer: $url_refrer")
    else
        curl -s $url_login -X POST \
            -c $path_kz_cookies \
            -d "username=$KZ_USER&password=$KZ_PASS" 1> /dev/null
        count_torrent=$(curl -s -L $url_profile -X GET \
            -b $path_kz_cookies \
            -H "Referer: $url_refrer")
    fi
    count_torrent=$(echo "$count_torrent" | cat -v | grep -oE "\( [0-9]+ \)" | sed -r "s/\(|\)//g")
    count_all=$(echo $count_torrent | awk '{print $1}')
    count_current=$(echo $count_torrent | awk '{print $2}')
    echo "[INFO] $(date '+%H:%M:%S'): Downloaded $count_current of $count_all" >> $path_log
    data_count="Загружено $count_current из $count_all"
    keyboard="{
        \"inline_keyboard\":[
            [{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],
            [{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],
            [{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]
        ]
    }"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$data_count" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$data_count" "$CHAT" "$keyboard"
    fi
}

### Get data via html (no api)
function read-html {
    html=$1
    a=$2
    type_down=$3
    rating_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+floatright">//; s/<.+//')
    rating_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r 's/.+floatright">//; s/<.+//')
    id_kz=$(echo $a | sed -r 's/.+id=//')
    name=$(printf "%s\n" "${html[@]}" | grep "<title>" | sed -r 's/<title>//; s/ \/.+//')
    name_down=$(echo $name | sed -r "s/ /_/g")
    year=$(printf "%s\n" "${html[@]}" | grep -E -B 1 "class=lnks_tobrs" | head -n 1 | sed -r 's/.+<\/b> //; s/<.+//')
    if [[ $year == $(date '+%Y') ]]; then
        name="🆕 $name"
    fi
    genre=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_tobrs" | sed -r 's/.+tobrs>//; s/<.+//' | head -n 1)
    side=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_tobrs" | sed -r 's/.+tobrs>//; s/<.+//' | head -n 2 | tail -n 1)
    id_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+film\///; s/".+//') # for api
    link_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+href="//; s/" target=.+//')
    size=$(printf "%s\n" "${html[@]}" | grep "floatright green" -m 1 | sed -r 's/.+n">//;s/\s.+//')
    length=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -A 1 | tail -n 1 | sed -r 's/.+b> //; s/<.+//')
    lang=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -A 2 | tail -n 1 | sed -r 's/.+b> //; s/<.+//')
    #audio=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -B 1 | tail -n 2 | head -n 1 | sed -r 's/.+b> //; s/<.+//')
    video=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -B 2 | tail -n 3 | head -n 1 | sed -r 's/.+b> //; s/<.+//; s/.* ([0-9]+x[0-9]+).*/\1/p' | head -n 1)
    #cast=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_toprs" | tail -n 1 | sed -r 's/.+toprs>//; s/<.+//')
    #description=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_toprs" | tail -n 1 | sed -r 's/.+<\/span><\/h2><\/div><div class="bx1 justify"><p><b>//; s/<\/p>.+//; s/.+<\/b> //')
    data=$(echo "$name \n")
    data+=$(echo "*Год выхода:* $year \n")
    data+=$(echo "*Жанр:* $genre \n")
    data+=$(echo "*Страна:* $side \n")
    data+=$(echo "*Рейтинг Кинопоиск:* $rating_kp \n")
    data+=$(echo "*Рейтинг IMDb:* $rating_imdb \n")
    data+=$(echo "*Размер:* $size Гб \n")
    data+=$(echo "*Продолжительность:* $length \n") 
    data+=$(echo "*Перевод:* $lang \n")
    #data+=$(echo "*Аудио:* $audio \n")
    data+=$(echo "*Качество:* $video \n")
    #data+=$(echo "*Актеры:* $cast \n")
    #data+=$(echo "*Описание:* $description \n")
    data+=$(echo "*Кинопоиск:* $link_kp \n")
    data+=$(echo "*Кинозал:* $a \n")
    if [[ $type_down != "True" ]]; then
        data+=$(echo "*Для загрузки:* \`/download_torrent $id_kz $name_down\`")
    fi
    echo $data
}

###### Telegram menu
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
        keyboard+="[{\"text\":\"$torrent_name\",\"callback_data\":\"/find_kinozal_$torrent_id\"}],"
    done
    keyboard+="[{\"text\":\"🌐 Kinozal profile\",\"callback_data\":\"\/count_torrent\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$TEXT" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$TEXT" "$CHAT" "$keyboard"
    fi
}

### Torrent list
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
    keyboard+="[{\"text\":\"🔄 Обновить список загрузок\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$TEXT" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$TEXT" "$CHAT" "$keyboard"
    fi
}

### Actions for selected torrent
function menu-info {
    qb_hash=$1
    qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
    qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
    qb_status=$(echo $qb_state | jq -r ".state")
    qb_progress=$(echo $qb_state | jq -r ".progress" | sed -r "s/\..+ %/ %/")
    qb_size=$(echo $qb_state | jq -r ".size")
    echo "[OK]   $(date '+%H:%M:%S'): Response on /info for $qb_name ($qb_hash)" >> $path_log
    keyboard="{
        \"inline_keyboard\":[
            [{\"text\":\"⏸ Пауза\",\"callback_data\":\"\/pause $qb_hash\"},
            {\"text\":\"▶️ Возобновить\",\"callback_data\":\"\/resume $qb_hash\"}],
            [{\"text\":\"🗑 Удалить торрент\",\"callback_data\":\"\/delete_torrent $qb_hash\"},
            {\"text\":\"❌ Удалить видео\",\"callback_data\":\"\/delete_video $qb_hash\"}],
            [{\"text\":\"🔄 Обновить\",\"callback_data\":\"\/info $qb_hash\"}],
            [{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],
            [{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],
            [{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]
        ]
    }"
    qb_name=$(echo $qb_name | sed -r "s/_/ /g")
    data=$(echo "*Название:* $qb_name \n")
    data+=$(echo "*Статус загрузки:* $qb_status \n")
    data+=$(echo "*Прогресс:* $qb_progress \n")
    data+=$(echo "*Размер:* $qb_size")
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

function menu-plex-status {
    command=$1
    CHAT=$2
    section_key=$(echo $command | sed "s/\/plex_status_//")
    # Set vardiable for /find
    declare -g global_key=$section_key
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
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

function menu-plex-find {
    json_data=$1
    data=$2
    CHAT=$3
    ### Для создания массива, забрать по одному элементу из каждого объекта json
    array_data=$(echo $json_data | jq -r .name)
    IFS=$'\n'
    for a in $array_data; do
        ### Отффильтровать объекты по названию элемента для обращения к его дочерним значениям
        data_temp=$(echo $json_data | jq ". | select(.name == \"$a\")")
        type_temp=$(echo $data_temp | jq -r .type)
        if [[ $type_temp != "folder" ]]; then
            size_temp=$(echo $data_temp | jq -r .size)
            duration=$(echo $data_temp | jq -r .duration)
            video_temp=$(echo $data_temp | jq -r .video)
            quality_temp=$(echo $data_temp | jq -r .quality)
            format_temp=$(echo $data_temp | jq -r .format)
            video_codec_temp=$(echo $data_temp | jq -r .video_codec)
            audio_codec_temp=$(echo $data_temp | jq -r .audio_codec)
            added_temp=$(echo $data_temp | jq -r .added)
            data+=$(echo "*Название:* 📋 $a\n")
            data+=$(echo "*Размер:* $size_temp\n")
            data+=$(echo "*Продолжительность:* $duration\n")
            data+=$(echo "*Разрешение:* $video_temp ($quality_temp)\n")
            data+=$(echo "*Расширение:* $format_temp\n")
            data+=$(echo "*Видео/Аудио кодек:* $video_codec_temp/$audio_codec_temp\n")
            data+=$(echo "*Дата добавления:* $added_temp\n\n")
        else
            endpoint_temp=$(echo $data_temp | jq -r .endpoint)
            data+=$(echo "*Название:* 🗂 $a\n")
            data+=$(echo "*Параметр*: \`$endpoint_temp\`\n\n")
        fi
    done
    encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
    keyboard='{"inline_keyboard":['
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$encoded_data" "$CHAT" "$keyboard"
    fi
}

### Thread (1): Chat-Bot (reading Telegram requests and sending response messages)
test_code=0
message_id_temp="null"
update_id_temp=""
while :
    do
    ### Check Telegram and Internet
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
    else
        if [[ $test_code == 1 ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Telegram api avaliable" >> $path_log
        elif [[ $test_code == 2 ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): Internet avaliable" >> $path_log
        fi
        test_code=0
        ### Read Telegram
        last_message=$(read-telegram)
        date_from_timestamp=$(echo $last_message | jq -r ".date")
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
                echo "[INFO] $(date '+%H:%M:%S'): Torrent file name: $down_id ($down_name)" >> $path_log
                download-torrent "$down_id" "$down_name"
                file_path="$path/$down_id-$down_name.torrent"
                if [ -e $file_path ]; then
                    echo "[INFO] $(date '+%H:%M:%S'): Torrent file downloaded: $file_path" >> $path_log
                    file_size=$(ls -lh $file_path | awk '{print $5}')
                    echo "[INFO] $(date '+%H:%M:%S'): File size: $file_size" >> $path_log
                    file_test=$(cat "$file_path" | grep "javascript")
                    if [ -z "$file_test" ]; then
                        echo "[OK]   $(date '+%H:%M:%S'): Torrent file uploaded" >> $path_log
                        data=$(echo "Торрент файл загружен успешно ($file_size)")
                    else
                        echo "[WARN] $(date '+%H:%M:%S'): Torrent file downloaded with error (found javascript to file)" >> $path_log
                        data=$(echo "Торрент файл загружен с ошибкой ($file_size)")
                    fi
                    encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                    keyboard="{
                        \"inline_keyboard\":[
                            [{\"text\":\"⬇️ Загрузить видео\",\"callback_data\":\"\/download_video_$down_id\"}],
                            [{\"text\":\"🌐 Kinozal profile\",\"callback_data\":\"\/count_torrent\"}],
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
            ### Request: /count_torrent
            elif [[ $command == /count_torrent ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Response on /count_torrent" >> $path_log
                count-torrent
            ### Request: /torrent_files 📚🗂
            elif [[ $command == /torrent_files ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Response on /torrent_files" >> $path_log
                menu-files "🗂 Torrent files:" $CHAT
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
                if [[ $PROXY == "True" ]]; then
                    URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
                    html_from_chat=$(curl -s -x $URL_PROXY $id_url | iconv -f windows-1251 -t UTF-8)
                else
                    html_from_chat=$(curl -s $id_url | iconv -f windows-1251 -t UTF-8)
                fi
                if [ -n "$html_from_chat" ]; then
                    data_for_chat=$(read-html "$html_from_chat" "$id_url" "True")
                    encoded_data_for_chat=$(echo -ne "$data_for_chat" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                    keyboard="{
                        \"inline_keyboard\":[
                            [{\"text\":\"⬇️ Загрузить видео\",\"callback_data\":\"\/download_video_$id_find\"}],
                            [{\"text\":\"🗑 Удалить торрент файл\",\"callback_data\":\"\/delete_torrent_file_$id_find\"}],
                            [{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],
                            [{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]
                        ]
                    }"
                    if [[ $message_id_temp != "null" ]]; then
                        edit-keyboard "$encoded_data_for_chat" "$CHAT" "$keyboard" "$message_id_temp"
                    else
                        send-keyboard "$encoded_data_for_chat" "$CHAT" "$keyboard"
                    fi
                    echo "[INFO] $(date '+%H:%M:%S'): HTML data avaliable, sending data to chat: $id_url" >> $path_log
                else
                    echo "[ERRO] $(date '+%H:%M:%S'): HTML data not avaliable (connection problem or torrent file invalid id): $id_url" >> $path_log
                    keyboard="{
                        \"inline_keyboard\":[
                            [{\"text\":\"⬇️ Загрузить видео\",\"callback_data\":\"\/download_video_$id_find\"}],
                            [{\"text\":\"🗑 Удалить торрент файл\",\"callback_data\":\"\/delete_torrent_file_$id_find\"}],
                            [{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],
                            [{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]
                        ]
                    }"
                    if [[ $message_id_temp != "null" ]]; then
                        edit-keyboard "Торрент файл (id: $id_find) не найден в базе Кинозала (возможна проблема соединения)." "$CHAT" "$keyboard" "$message_id_temp"
                    else
                        send-keyboard "Торрент файл (id: $id_find) не найден в базе Кинозала (возможна проблема соединения)." "$CHAT" "$keyboard"
                    fi
                fi
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
                sleep $TIMEOUT_SEC_STATUS
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
                sleep $TIMEOUT_SEC_STATUS
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
                keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
                keyboard+="[{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
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
                sleep 1
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
                keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
                keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
                keyboard+="[{\"text\":\"🗂 Torrent files\",\"callback_data\":\"\/torrent_files\"}]]}"
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
                        echo "[OK]   $(date '+%H:%M:%S'): Find on endpoint" >> $path_log
                        endpoint=$folder_name
                        json_data=$(plex-content-from-folder "$endpoint")
                        data=$(echo "Содержимое указанной директории:\n\n")
                    else
                        echo "[OK]   $(date '+%H:%M:%S'): Find on folder" >> $path_log
                        endpoint=$(plex-folder-from-section $global_key | jq -r ". | select(.name == \"$folder_name\").endpoint")
                        json_data=$(plex-content-from-folder "$endpoint")
                        data=$(echo "Содержимое *$folder_name*:\n\n")
                    fi
                    menu-plex-find "$json_data" "$data" "$CHAT"
                fi
            ### Request: /plex_last_added
            elif [[ $command == /plex_last_added ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Response on /plex_last_added" >> $path_log
                endpoint="/library/recentlyAdded"
                json_data=$(plex-content-from-folder "$endpoint")
                data=$(echo "Список последних добавленных файлов:\n\n")
                menu-plex-find "$json_data" "$data" "$CHAT"
            ### Request: /plex_last_views
            elif [[ $command == /plex_last_views ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Response on /plex_last_views" >> $path_log
                endpoint="/library/onDeck"
                json_data=$(plex-content-from-folder "$endpoint")
                data=$(echo "Список последних просмотров:\n\n")
                menu-plex-find "$json_data" "$data" "$CHAT"
            else
                echo "[WARN] $(date '+%H:%M:%S'): Command not found: $command" >> $path_log
            fi
        fi
    fi
done &

### Thread (2): Channel News (post news to channel from kinozal)
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
                    ### Filtering content by rating
                    if [[ ($rating_kp == "—" || $rating_kp < $RATING_KP) && $rating_imdb < $RATING_IMDB ]]; then
                        ((count_skip++))
                        echo "[INFO] $(date '+%H:%M:%S'): Skip: $a (rating kp: $rating_kp and imdb: $rating_imdb)" >> $path_log
                        continue
                    else
                        ((count_post++))
                        echo "[OK]   $(date '+%H:%M:%S'): Post: $a" >> $path_log
                        data=$(read-html "$html" "$a" "False")
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
            sleep $TIMEOUT_SEC_POST
        else
            echo "[INFO] $(date '+%H:%M:%S'): RSS no new data. Last link: $link_temp" >> $path_log
            sleep $TIMEOUT_SEC_POST
        fi
    else
        echo "[ERRO] $(date '+%H:%M:%S'): RSS data not avaliable" >> $path_log
        sleep $TIMEOUT_SEC_ERROR
    fi
done &