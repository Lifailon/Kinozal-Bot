#!/bin/bash

# Stack:
# kinozal.tv: read rss, receiving data from html (no api) + filtering by rating and download torrent files
# Telegram api: send news to channel and read message commands
# qBittorrent api: download data from torrent files
# Plex Media Server api: sync content
# Optional: Proxy server with VPN (Split Tunneling mode) for access to kinozal.tv (Example: HandyCache and Hotspot Shield)

# Bot commands:
# /torrent_files - Вывести список загруженных torrent-файлов
# /find_kinozal_id - Получить информацию о torrent-файле (параметр в теле команды: _id Кинозал)
# /download_torrent - Загрузить torrent-файл (передать параметр: id Кинозал)
# /status - Статус загрузок на сервере qBittorrent
# /download_video_id - Загрузить видео (параметр в теле команды: _id Кинозал)
# /pause - Поставить загрузку на паузу (передать параметр: имя видео)
# /resume - Восстановить загрузку (передать параметр: имя видео)
# /delete_torrent - Удалить загрузку (передать параметр: имя видео)
# /delete_video - Удалить загрузку и видео файлы (передать параметр: имя видео)
# /sync_plex - Синхронизировать директорию

### Read configuration
conf="./kinozal-bot.conf"
source "$conf"
TG_CHAT_ARRAY=($(echo $TG_CHAT | tr ',' ' '))

### Stop threads processes (2+):
### bash kinozal-news.sh stop
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
    echo "Server started. Read log: tail -f $path_log"
}

log-rotate

### Telegram
### API documentation: https://core.telegram.org/bots/api
### Send message to Telegram
function test-telegram {
    endpoint="getMe"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    curl -s $url -X "GET"
}

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

### Read messages from Telegram
function read-telegram {
    endpoint="getUpdates"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    last_update_id=$(curl -s $url -X "GET" | jq ".result[-1].update_id")
    messages=$(curl -s $url -X "GET" -d offset=$last_update_id -d limit=1)
    type="bot_command"
    ### Filtering messages by chat id and type message (only commands)
    for TG in ${TG_CHAT_ARRAY[@]}
        do
        selected=$(echo $messages | jq ".result[] | select(.message.chat.id == $TG and .message.entities[0].type == \"$type\")")
        if [[ -n "$selected" ]]; then
            echo $selected | jq '{date: (.message.date + 3 * 3600 | strftime("%d.%m-%H:%M:%S")), timestamp: .message.date, text: .message.text, user: .message.from.username, chat: .message.chat.id}' 
            break
        fi
    done
}

### qBittorrent
### API documentation: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)
### Authorization to qBittorrent
function qbittorrent-auth {
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
    endpoint_info="api/v2/torrents/info"
    curl -s "$QB_ADDR/$endpoint_info" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq ".[] | {\
        name: .name, \
        hash: .hash, \
        path: .content_path, \
        state: .state, \
        progress: (.progress * 100 | floor / 100 * 100 | tostring + \" %\"), \
        size: (.size / 1024 / 1024 / 1024 * 100 | floor / 100 | tostring + \" GB\")}"
}

### Download selected torrent file
function qbittorrent-download {
    qbittorrent-auth
    filename=$1
    file_path="$path/$filename.torrent"
    endpoint_download="api/v2/torrents/add"
    curl -s "$QB_ADDR/$endpoint_download" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --form "file=@$file_path"
}

### Pause selected torrent file
function qbittorrent-pause {
    torrent_name=$1
    torrent_hash=$(qbittorrent-info | jq ". | select(.name == \"$torrent_name\") | .hash" | sed -r 's/\"//g')
    qbittorrent-auth
    endpoint_pause="api/v2/torrents/pause"
    curl -s "$QB_ADDR/$endpoint_pause" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$torrent_hash"
}

### Resume selected torrent file
function qbittorrent-resume {
    torrent_name=$1
    torrent_hash=$(qbittorrent-info | jq ". | select(.name == \"$torrent_name\") | .hash" | sed -r 's/\"//g')
    qbittorrent-auth
    endpoint_resume="api/v2/torrents/resume"
    curl -s "$QB_ADDR/$endpoint_resume" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$torrent_hash"
}

### Delete torrent
function qbittorrent-delete {
    torrent_name=$1
    delete_type=$2
    torrent_hash=$(qbittorrent-info | jq ". | select(.name == \"$torrent_name\") | .hash" | sed -r 's/\"//g')
    qbittorrent-auth
    endpoint_delete="api/v2/torrents/delete"
    curl -s "$QB_ADDR/$endpoint_delete" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$torrent_hash" \
        --data "deleteFiles=$delete_type"
}

### kinozal.tv
### Authorization and download selected torrent file
function download-torrent {
    id_kz=$1
    url_down="https://dl.kinozal.tv/download.php?id=$id_kz"
    url_login="https://kinozal.tv/takelogin.php"
    url_refrer="https://kinozal.tv/"
    path_down="$path/$id_kz.torrent"
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

### Get data via html (no api)
function read-html {
    html=$1
    a=$2
    type_down=$3
    rating_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+floatright">//; s/<.+//')
    rating_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r 's/.+floatright">//; s/<.+//')
    #name=$(printf "%s\n" "${html[@]}" | grep "<title>" | sed -r 's/<title>//; s/::.+//')
    name=$(printf "%s\n" "${html[@]}" | grep "<title>" | sed -r 's/<title>//; s/ \/.+//')
    year=$(printf "%s\n" "${html[@]}" | grep -E -B 1 "class=lnks_tobrs" | head -n 1 | sed -r 's/.+<\/b> //; s/<.+//')
    if [[ $year == $(date '+%Y') ]]; then
        name="🆕 $name"
    fi
    genre=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_tobrs" | sed -r 's/.+tobrs>//; s/<.+//' | head -n 1)
    side=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_tobrs" | sed -r 's/.+tobrs>//; s/<.+//' | head -n 2 | tail -n 1)
    id_kz=$(echo $a | sed -r 's/.+id=//')
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
    if [[ $type_down == "True" ]]; then
        data+=$(echo "*ID для загрузки:* \`$id_kz\` \n")
        data+=$(echo "*Скачать видео:* /download\_video\_$id_kz")
    else
        data+=$(echo "*ID для загрузки:* \`$id_kz\`")
    fi
    echo $data
}

### Thread (1): Chat-Bot (reading Telegram requests and sending response messages)
test_code=0
date_temp=$(date +%s)
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
        user=$(echo $last_message | jq ".user" | sed -r 's/\"//g')
        CHAT=$(echo $last_message | jq ".chat" | sed -r 's/\"//g')
        command=$(echo $last_message | jq ".text" | sed -r 's/\"//g')
        if [[ $date > $date_temp ]]; then
            date_temp=$date
            echo "[OK]   $(date '+%H:%M:%S'): Request command from user: $user ($CHAT)" >> $path_log
            ### Request: /download_torrent
            if [[ $command == /download_torrent* ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Response on /download_torrent_id" >> $path_log
                id_down=$(echo $command | sed "s/\/download_torrent //")
                if [[ $id_down =~ ^[0-9]{7}$ ]]; then
                    echo "[INFO] $(date '+%H:%M:%S'): Torrent file name valid: $id_down" >> $path_log
                    download-torrent $id_down
                    if [ -e "$path/$id_down.torrent" ]; then
                        echo "[INFO] $(date '+%H:%M:%S'): Torrent file successfully downloaded" >> $path_log
                        send-telegram "Torrent uploaded. Download video: /download\_video\_$id_down" "$CHAT"
                    else
                        echo "[WARN] $(date '+%H:%M:%S'): Torrent file not uploaded" >> $path_log
                        send-telegram "Torrent not uploaded" "$CHAT"
                    fi
                else
                    echo "[WARN] $(date '+%H:%M:%S'): Torrent file name not valid: $id_down" >> $path_log
                fi
            ### Request: /torrent_files
            elif [[ $command == /torrent_files ]]; then
                echo "[OK]   $(date '+%H:%M:%S'): Response on /torrent_files" >> $path_log
                ls=$(ls -l $path | grep -E "*\.torrent" | awk '{print $9,$7,$6,$8}' | sed -r "s/.torrent//; s/^/\/find\\\_kinozal\\\_/" | sort -k2,2 -k4,4)
                send-telegram "$ls" "$CHAT"
                wc=$(ls -l $path | grep -E "*\.torrent" | wc -l)
                echo "[INFO] $(date '+%H:%M:%S'): Torrent files count: $wc" >> $path_log
            ### Request: /find_kinozal_id
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
                    send-telegram "$encoded_data_for_chat" "$CHAT"
                    echo "[INFO] $(date '+%H:%M:%S'): HTML data sending to chat: $id_url" >> $path_log
                else
                    echo "[ERRO] $(date '+%H:%M:%S'): HTML data not avaliable: $id_url" >> $path_log
                fi
            ### Request: /status
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
                    info=$(qbittorrent-info | jq '"➡️ `\(.name)` (\(.size)) *\n\(.state) (\(.progress))*"' | sed -r 's/\"//g')
                    encoded_info=$(echo -ne "$info" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                    send-telegram "$encoded_info" "$CHAT"
                    wc_all=$(printf "%s\n" "${info[@]}" | wc -l)
                    wc_up=$(printf "%s\n" "${info[@]}" | grep "100 %" | wc -l)
                    echo "[INFO] $(date '+%H:%M:%S'): Download files count to qBittorrent: $wc_up of $wc_all" >> $path_log
                fi
            ### Request: /download_video_id
            elif [[ $command == /download_video_* ]]; then
                id_down=$(echo $command | sed "s/\/download_video_//")
                echo "[OK]   $(date '+%H:%M:%S'): Response on /download_video for $id_down" >> $path_log
                wc_be=$(qbittorrent-info | jq .name | wc -l)
                start=$(qbittorrent-download $id_down)
                wc_af=$(qbittorrent-info | jq .name | wc -l)
                echo "[INFO] $(date '+%H:%M:%S'): Before: $wc_be, after: $wc_af" >> $path_log
                if [[ $wc_af > $wc_be ]]; then
                    echo "[INFO] $(date '+%H:%M:%S'): Download started" >> $path_log
                    send-telegram "Download started: /status" "$CHAT"
                else
                    if [[ $start == "Fails." ]]; then
                        echo "[WARN] $(date '+%H:%M:%S'): Already downloading (response: Fails)" >> $path_log
                        send-telegram "Already downloading: /status" "$CHAT"
                    else
                        echo "[WARN] $(date '+%H:%M:%S'): Download not started (response: Null)" >> $path_log
                        send-telegram "Download not started: /status" "$CHAT"
                    fi
                fi
            ### Request: /pause ⏸
            elif [[ $command == /pause* ]]; then
                video_name=$(echo $command | sed -r "s/\/pause //")
                echo "[OK]   $(date '+%H:%M:%S'): Response on /pause for $video_name" >> $path_log
                be_state=$(qbittorrent-info | jq ". | select(.name == \"$video_name\") | \"\`\(.name)\` - *\(.state)*\"" | sed -r 's/\"//g')
                echo "[INFO] $(date '+%H:%M:%S'): Before state: $be_state" >> $path_log
                qbittorrent-pause "$video_name"
                sleep $TIMEOUT_SEC_READ
                af_state=$(qbittorrent-info | jq ". | select(.name == \"$video_name\") | \"\`\(.name)\` - *\(.state)*\"" | sed -r 's/\"//g')
                echo "[INFO] $(date '+%H:%M:%S'): After state: $af_state" >> $path_log
                encoded_state=$(echo -ne "$af_state" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                send-telegram "$encoded_state" "$CHAT"
            ### Request: /resume ▶️
            elif [[ $command == /resume* ]]; then
                video_name=$(echo $command | sed -r "s/\/resume //")
                echo "[OK]   $(date '+%H:%M:%S'): Response on /resume for $video_name" >> $path_log
                be_state=$(qbittorrent-info | jq ". | select(.name == \"$video_name\") | \"\`\(.name)\` - *\(.state)*\"" | sed -r 's/\"//g')
                echo "[INFO] $(date '+%H:%M:%S'): Before state: $be_state" >> $path_log
                qbittorrent-resume "$video_name"
                sleep $TIMEOUT_SEC_READ
                af_state=$(qbittorrent-info | jq ". | select(.name == \"$video_name\") | \"\`\(.name)\` - *\(.state)*\"" | sed -r 's/\"//g')
                echo "[INFO] $(date '+%H:%M:%S'): After state: $af_state" >> $path_log
                encoded_state=$(echo -ne "$af_state" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                send-telegram "$encoded_state" "$CHAT"
            ### Request: /delete_torrent
            elif [[ $command == /delete_torrent* ]]; then
                video_name=$(echo $command | sed -r "s/\/delete_torrent //")
                echo "[OK]   $(date '+%H:%M:%S'): Response on /delete_torrent for $video_name" >> $path_log
                wc_be=$(qbittorrent-info | jq .name | wc -l)
                qbittorrent-delete "$video_name" false
                wc_af=$(qbittorrent-info | jq .name | wc -l)
                echo "[INFO] $(date '+%H:%M:%S'): Before: $wc_be, after: $wc_af" >> $path_log
                if [[ $wc_af < $wc_be ]]; then
                    echo "[INFO] $(date '+%H:%M:%S'): Torrent file deleted" >> $path_log
                    send-telegram "Torrent file deleted: /status" "$CHAT"
                else
                    echo "[WARN] $(date '+%H:%M:%S'): Torrent file not deleted" >> $path_log
                    send-telegram "Torrent file not deleted: /status" "$CHAT"
                fi
            elif [[ $command == /delete_video* ]]; then
                video_name=$(echo $command | sed -r "s/\/delete_video //")
                echo "[OK]   $(date '+%H:%M:%S'): Response on /delete_video for $video_name" >> $path_log
                wc_be=$(qbittorrent-info | jq .name | wc -l)
                qbittorrent-delete "$video_name" true
                wc_af=$(qbittorrent-info | jq .name | wc -l)
                echo "[INFO] $(date '+%H:%M:%S'): Before: $wc_be, after: $wc_af" >> $path_log
                if [[ $wc_af < $wc_be ]]; then
                    echo "[INFO] $(date '+%H:%M:%S'): Torrent file deleted" >> $path_log
                    send-telegram "Torrent file deleted: /status" "$CHAT"
                else
                    echo "[WARN] $(date '+%H:%M:%S'): Torrent file not deleted" >> $path_log
                    send-telegram "Torrent file not deleted: /status" "$CHAT"
                fi
            ### Request: /sync_plex
            else
                echo "[WARN] $(date '+%H:%M:%S'): Command not found: $command" >> $path_log
            fi
        fi
        sleep $TIMEOUT_SEC_READ
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
            for l in ${links[@]}
                do
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
            for a in ${array[@]}
                do
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
                        echo "[INFO] $(date '+%H:%M:%S'): Skip: $a" >> $path_log
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