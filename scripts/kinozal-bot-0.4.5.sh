#!/bin/bash

# © 2023-2024 by Lifailon
# Source GitHub: https://github.com/Lifailon/Kinozal-Bot
# Publication on Habr: https://habr.com/ru/articles/782028
# Active Telegram Channel: @kinozal_news
# Telegram Bot (access by id): @lifailon_ps_bot (Kinozal-Bot)

###############################################################################

### Stack:
# Kinozal: чтение RSS ленты, получение данных из HTML, поиск с фильтрацией контента и загрузка торрент файлов
# Telegram api: чтение команд и отправка ответных сообщений в формате меню (keyboard), торрент файлов и постов в канал
# qBittorrent WebUI api: добавление торрентов из торрент файлов или инфо хеш и управление данными (пауза, удаление и изменение приоритета)
# Transmission RPC api: добавление торрентов из инфо хеш и управление загрузкой (пауза и удаление)
# Plex Media Server api: синхронизация данных и получение информации о содержимом секций и дочерних файлах
### Зависимости:
# jq 1.6 (https://github.com/jqlang/jq)
### Опционально:
# VPN через Proxy сервер (например, HandyCache и Hotspot Shield в режиме Split Tunneling) для доступа в Кинозал
# Kinopoisk unofficial API (https://github.com/mdwitr0/kinopoiskdev)

###############################################################################

### Backlog:
# Поддержка обратного прокси сервера
# Отладить получение информации по актеру
# Заменить Kinopoisk unofficial API на TMDB api

###############################################################################

### Change log:
### 16.11.2023 (0.1):   Создан новостной канал Kinozal_News и Telegram-бот для скачивания торрент-файлов и управления qBittorrent.
### 27.11.2023 (0.2):   Добавлено меню клавиатуры Telegram, удаление торрент-файлов и профиль в Кинозал с информацией о загрузках.
### 30.11.2023 (0.3):   Добавлен функционал Plex для просмотра содержимого секций и синхронизации контента.
### 04.12.2023 (0.4.0): Добавлен поиск в Кинозал, список альтернативных ссылок, получение содержимого торрент файла и изменение приоритета.
### 07.12.2023 (0.4.1): Добавлено получение дополнительной информации из Кинозал и поиск в Plex.
### 27.12.2023 (0.4.2): Добавлен список актеров для каждого фильма, просмотр их фильмографии и ссылка на Кинопоиск.
# Получение дополнительной информации и список трейлеров из kinopoisk api. Фильтрация для поиска фильмов по году выхода.
### 20.01.2023 (0.4.3): Добавлен функционал для управления Windows через WinAPI: состояния системы, запуск и остановка приложений qBittorrent и Plex. 
# Нереализовано: просмотр списка директорий и файлов с возможностью их удаления (проблема с отображением из за длинны пути при отправке через callback_data).
### 16.05.2024-12.06.2024 (0.4.4):
# + Изменены параметры управления запуска (2 режима) и возможность настройки управления чере службу systemd;
# + Добавлены параметры вывода логов бота, журнала работы клиента qBittorrent и сервера Plex;
# + Добавлено получение инфо хеш каждой раздачи и содержимое раздачи (/file_list из /find_kinozal);
# + Повторить последний поисковой запрос (доступно из меню и /find_kinozal);
# + Фильтрация по формату (разрешению) при поиске по названию фильма или сериала;
# + Получение последнего, выбранного и всех загруженных торрент файлов с сервера (отправка в телеграм);
# + Добавлена возможность загрузить торрент по инфо хеш (/add_torrent из меню);
# + Выгрузить торрент файла из клиента qBittorrent (после загрузки метаданных) на сервер с отправкой в телеграм;
# + Добавлена проверка (сканирование целостности) торрент раздачи в qBittorrent;
# + Добавлен статус приоритета и загрузки в списке файлов выбранного торрента;
# + Добавлен пропуск и восстановление загрузки всех файлов в qBittorrent;
# + Добавлен поиск в Plex из qBittorrent по имени файла (из /info <name> в /find <name>);
# + Добавлена информация о настройках и лимитах qBittorrent в список торрентов (/status) и переключение на альтернатывные лимиты скорости (/torrent_limit);
# ~ Исправлено: обновление статуса после синхронизации контента Plex, добавлено время обновления, что бы отвисала кнопка, где может не обновляться контент;
# ~ Канал: добавлены хэштеги по жанру и кнопки для перехода по url (Кинопоиск + IMDb + Кинозал + Magnet + Kinobox);
# ~ Обновлен парсинг и добавлены условия для проверки на наличие содержимого в описание постов;
# + Добавлен redirect с url https на magnet uri для перенаправления в торрент клиент по умолчанию, т.к. магнитные ссылки не принимает Telegram для передачи в url;
# + Добавлены функции qBittorrent для получения списка трекеров, содержимого RSS ленты и работы с поисковыми плагинами (Search Plugins).
### 14.06.2024 (0.4.5):
# + Добавлен функционал управления торрент клиентом Transmission (добавление по хэшу, остановка и возобновление загрузки, удаление торрента и данных)
# ~ Изменено добавление торрента по хешу (вначале принимается команда /add_torrent <hash> для выбора клиента, после нажатия вызывается команда /add_hash)
# + Добавлен список плееров в меню результатов поиска Кинозал

###############################################################################

### Bot commands (endpoint):
# /search - Поиск в Кинозал по названию (вначале запроса принимает год выхода для фильтрации)
# /profile - Профиль Кинозал (количество доступных для загрузки торрент файлов, статистика загрузки и отдачи, время сид и пир)
# /torrent_files - Список загруженных торрент файлов с возможностью удаления
# /status - список и статус всех текущих торрентов, добавленных в торрент-клиент qBittorrent
# /plex_info - Список секций на сервере Plex для доступа к их контенту
# /download_torrent <id> <file_name> - Загрузить торрент файл (передать два параметра: id и имя файла без пробелов)
# /delete_torrent_file_<id> - Удалить торрент файл по id
# /find_kinozal <id> - Поиск в Кинозал по id
# /download_video_<id> - Добавить торрент файла на загрузку в qBittorrent
# /info <hash> - Статус загрузки указанного торрента (передать параметр: hash торрента)
# /torrent_content <hash> - Содержимое торрента (список файлов)
# /file_torrent <index> - Статус выбранного торрент файла (передать параметр: порядковый индекс файла)
# /torrent_priority <num> - Изменить приоритет выбранного файла в /file_torrent (передать параметр: номер приоритета)
# /pause <hash> - Установить на паузу
# /resume <hash> - Восстановить загрузку
# /delete_torrent <hash> - Удалить торрент из клиента
# /delete_video <hash> - Удалить вместе с данными
# /plex_status_<key> - Информация о выбранной секции в Plex (передать параметр: ключ секции)
# /plex_sync_<key> - Синхронизировать выбранную секцию в Plex
# /plex_folder_<key> - Получить список директорий и файлов в выбранной секции
# /find <endpoint> - Поиск контента в Plex по пути (передать параметр: конечную точку)
### 0.4.1:
# /plex_last_views - Список последних просмотров (дата просмотра и время остановки) в Plex
# /plex_last_added - Список последних добавленных файлов в Plex
# /kinozal_description <id> - Описание фильма из Кинозал (передать параметр: id kinozal)
### 0.4.2:
# /kinozal_actors <id> - Список актеров из Кинозал (передать параметр: id kinozal)
# /actor <actor_name> - Описание, поиск актера и его фильмографии из Кинозала и ссылка на Кинопоиск (передать параметр: имя актера)
# /kinopoisk_movie <id> - Информация о фильме из Кинопоиск по id kinopoisk (передать параметр: id kinozal)
### 0.4.3 (удалено из меню):
# /win_state - Получение информации о состояние системы через WinAPI
# /win_process - Список запущенных процессов с фильтрацией по уникальному имени
# /app_status <app_name> - Статус процесса/приложения
# /app_start <app_name> - Запуск приложения
# /app_stop <app_name> - Остановка приложения
# /win_api_get_dir <path> - Получить список директорий и файлов по указанному пути (нереализовано)
# /win_api_del_dir <path> - Удалить директорию или файл по указанному пути (нереализовано)
### 0.4.4:
# /search <year*> <format*> <title> - Поиск с фильтрацией по году выхода и формату разрешения
# /research - Повторить последний поиск (id не требуется)
# /file_list - Извлечь список файлов и их размер из раздачи
# /send_torrent_file_id - Отправка загруженного торрент-файла в Telegram
# /send_last_torrent_file - Отправить последний загруженный торрент-файл
# /send_all_torrent_files - Отправить все загруженные торрент-файлы
# /skip_all_files <hash> - Пропустить загрузку всех файлов путем изменения приоритета в qBittorrent
# /normal_all_files <hash> - Восстановить загрузку всех файлов
# /add_torrent <hash> - Добавить раздачу на загрузку в qBittorrent по инфо хеш
# /get_torrent <hash> - Выгрузить торрент файл на сервер по инфо хеш и отправить в телеграмм
# /torrent_recheck <hash> - Проверить торрент файл
# /torrent_limit - Переключить альтернативные лимиты скорости загрузки и отдачи
### 0.4.5:
# /trans_status - Список и статус всез торрент в клиенте Transmission
# /trans_info <id> - Получить подробную информацию о торренте
# /trans_pause <id> <type> - установить на паузу или возобновить
# /trans_remove <id> <type> - удалить торрент и данные
# /add_hash <qbit/trans> <hash> - Добавить торрент по инфо хеш в указанный клиент

###############################################################################

### Telegram menu (Edit Bot - Edit commands):
# / find_kinozal - 🔎 Поиск в Кинозал по id
# / search - 🍿 Поиск по названию
# / actor - 👥 Поиск по актеру
# / research - 🔄 Повторить последний поиск
# / add_torrent - ⬇️ Добавить торрент по инфо хеш
# / torrent_files - 🗂 Торрент файлы
# / status - 🟢 qBittorrent
# / trans_status - 🔲 Transmission
# / plex_info - 🟠 Plex
# / find - 🔍 Поиск в Plex

###############################################################################

### Поиск в Кинозал по id:
# /find_kinozal 1940284

### Поиск по названию фильма или сериала:
# /search Рокки 2
# /search Рокки 4

### Поиск с фильтрацией по году выхода:
# /search 1979 Рокки
# /search 1985 Рокки

### Поиск с фильтрацией по формату разрешения:
# /search (720) Рокки
# /search (1080) Рокки
# /search (2160) Рокки

### Поиск с фильтрацией по формату разрешения и году выхода:
# /search 1985 (2160) Рокки
# /search (2160) 1985 Рокки

### Поиск фильмографии по имени актера (получить список фильмов из Кинозал):
# /actor Сильвестр Сталлоне

### Неверный поиск (находит только актера в Кинопоиск по api без фильмографии):
# /actor сильвестр сталлоне
# /actor Сильвестр Сталоне

### Повторить последний запрос поиска (для фильма/сериала или актера):
# /research

### Добавить торрент по инфо хеш на загрузку с выбором клиента через меню:
# /add_torrent A72BD27A0CE265A3C7965392BC06C25EDD759214

### Добавить торрент по инфо хеш в указанный торрент клиент:
# /add_hash qbit A72BD27A0CE265A3C7965392BC06C25EDD759214
# /add_hash trans A72BD27A0CE265A3C7965392BC06C25EDD759214

###############################################################################

### Параметры управления:
# bash kinozal-bot-0.4.4.sh start bot                       # запустить только бот (1 поток)
# bash kinozal-bot-0.4.4.sh start all                       # запустить бот и канал (2 потока)
# bash kinozal-bot-0.4.4.sh start <bot/all> log             # запустить дополнительный поток вывода логов для службы systemd
# bash kinozal-bot-0.4.4.sh status                          # статус работы сервера и количство активных процессов
# bash kinozal-bot-0.4.4.sh status proc                     # вывести список активных процессов
# bash kinozal-bot-0.4.4.sh stop                            # остановить сервер (остановить все процессы)
# bash kinozal-bot-0.4.4.sh log bot                         # вывести журнал работы бота в реальном времени
# bash kinozal-bot-0.4.4.sh log bot 50                      # вывести 50 записей журнала
# bash kinozal-bot-0.4.4.sh log qb                          # вывести журнал работы с клиента qBittorrent (critical и warning)
# bash kinozal-bot-0.4.4.sh log qb all                      # вывести все записи журнала qBittorrent
# bash kinozal-bot-0.4.4.sh log plex server                 # вывести журнал работы сервер plex (error и warning)
# bash kinozal-bot-0.4.4.sh log plex system                 # вывести системный журнал plex (error и warning)
# bash kinozal-bot-0.4.4.sh log plex <server/system> all    # вывести все записи журнала plex

###############################################################################

### Служба для управления ботом

### nano /etc/systemd/system/kinozal-bot.service

# [Unit]
# Description=Telegram bot for kinozal.tv torrent tracker, remote managment qBittorrent and Plex Media Server
# After=network.target
# 
# [Service]
# ExecStart=/bin/bash "/home/lifailon/kinozal-torrent/kinozal-bot-0.4.4.sh" start all log
# ExecReload=/bin/kill -HUP $MAINPID
# Restart=on-failure
# Type=forking
# 
# [Install]
# WantedBy=multi-user.target

### systemctl daemon-reload         # применить настройки
### systemctl enable kinozal-bot    # включать автозапуск при перезагрузки
### systemctl start kinozal-bot     # запустить бота
### systemctl status kinozal-bot    # статус работы
### systemctl restart kinozal-bot   # перезапустить бота
### journalctl -fu kinozal-bot      # вывести журнал работы бота в реальном времени
### journalctl -eu kinozal-bot      # вывесли журнал работы бота с конца

###############################################################################

### Получить путь к конфигурации (по умолчанию файл конфигурации находится рядом со скриптом сервера)
kinozal_bot_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
conf="$kinozal_bot_path/kinozal-bot.conf"

###############################################################################
############################## Debug to console ###############################
###############################################################################

### (Debug) Отключаем обработку параметров запуска
# START_DEBUG=true

### (Debug) Передаем путь к конфигурации вручную
# conf="/home/lifailon/kinozal-torrent/kinozal-bot.conf"

### Прочитать конфигурацию сервера
if [ -f "$conf" ]; then
    source "$conf"
    TG_CHAT_ARRAY=($(echo $TG_CHAT | tr ',' ' '))
else
    echo "Configuration file not fount: $conf"
    exit 1
fi

### Пути хранения лог файла и cookie относительно заданного в конфигурации
path_log="$path/kinozal-bot.log"
path_qb_cookies="$path/qbittorrent.cookies"
path_kz_cookies="$path/kinozal.cookies"

### (Debug) Забираем первый id из массива для отправки сообщений в Telegram через консоли
# CHAT=$(echo "${TG_CHAT_ARRAY[0]}")

### (Debug) Формируем URL Proxy-сервера
# URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")

### (Debug) Включить для проверки доступности Telegram и Internet при каждой интерации цикла основного потока
CHECK_TG_AND_INTERNET="False"

### Функция авторизации в qBittorrent
function qbittorrent-auth {
        echo "[INFO] $(date '+%H:%M:%S'): Authorization to qBittorrent" >> $path_log
        endpoint_auth="api/v2/auth/login"
        curl -s "$QB_ADDR/$endpoint_auth" \
            --max-time 1 \
            -c $path_qb_cookies \
            --header "Referer: $QB_ADDR" \
            --data "username=$QB_USER&password=$QB_PASS" 1> /dev/null
}

### Журнал работы клиента qBittorrent
function qbittorrent-log {
    count=$1
    all=false
    if [[ $count == "all" ]]; then
        all=true
    fi
    qbittorrent-auth
    endpoint="api/v2/log/main"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "normal=$all" \
        --data "info=$all" \
        --data "warning=true" \
        --data "critical=true" \
        --data "last_known_id=-1" | jq -r '.[] | {
            type: (
                if .type == 1 then "NORM"
                elif .type == 2 then "INFO"
                elif .type == 4 then "WARN"
                elif .type == 8 then "CRIT"
                else "UNKNOWN"
                end
            ),
            datetime: (.timestamp | todateiso8601),
            message: .message
        } | "[\(.type)] \(.datetime): \(.message)"' | while read -r line; do
            datetime=$(echo "$line" | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z')
            formatted_datetime=$(date -d "$datetime" "+%d.%m.%Y %H:%M:%S")
            echo "$line" | sed "s/$datetime/$formatted_datetime/"
        done
}

### Журнал работы сервера Plex
function plex-log {
    type=$1
    count=$2
    path_plex_log="$path/plex-log"
    plex_log_name=$(date "+%H:%M-%d.%m.%Y")
    if [ -d "$path_plex_log" ]; then
        rm -r $path_plex_log
    fi
    mkdir $path_plex_log
    endpoint="diagnostics/logs"
    curl -s "$PLEX_ADDR/$endpoint" \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        -o "$path_plex_log/plex-log-$plex_log_name.zip"
    unzip "$path_plex_log/plex-log-$plex_log_name.zip" -d $path_plex_log > null
    if [[ $type == "server" && $count == "all" ]]; then
        cat "$path_plex_log/Plex Media Server.log"
    elif [[ $type == "server" && $count != "all" ]]; then
        cat "$path_plex_log/Plex Media Server.log" | grep -E "ERROR|WARN"
    elif [[ $type == "system" && $count != "all" ]]; then
        cat "$path_plex_log/com.plexapp.system.log" | grep -E "ERROR|WARN"
    elif [[ $type == "system" && $count == "all" ]]; then
        cat "$path_plex_log/com.plexapp.system.log"
    fi
}

### Параметры управления
if [[ $START_DEBUG != true ]]; then
    if [[ $1 == "start" ]]; then
        if [[ $2 == "bot" ]]; then
            TG_CHANNEL_USE="false"
            echo "[OK]   $(date '+%H:%M:%S'): Server started (only bot)" >> $path_log
            cat $path_log | tail -n 1
        elif [[ $2 == "all" ]]; then
            TG_CHANNEL_USE="True"
            echo "[OK]   $(date '+%H:%M:%S'): Server started (bot and channel)" >> $path_log
            cat $path_log | tail -n 1
        else
            echo "Available parameters: bot and all"
            exit 0
        fi
        if [[ $3 == "log" ]]; then
            tail -f $path_log &
        fi
    else
        process_name="kinozal"
        if [[ $1 == "stop" ]]; then
            ### Найти все процессы kinozal, исключив текущий процесс отановки
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
                echo "[WARN] $(date '+%H:%M:%S'): Server is already stopped. Count running process: $(echo ${#proc[@]})" >> $path_log
            fi
            cat $path_log | tail -n 1
        elif [[ $1 == "status" ]]; then
            if [[ $2 == "proc" ]]; then
                ps -AF | grep "$process_name" | grep -vE "grep|status" | awk '{
                    printf "%s %s %s %s %s ", $1, $5, $6, $8, $10
                    for (i=11; i<=NF; i++)
                    printf "%s ", $i; printf "\n"
                }'
            else
                proc=($(ps -AF | grep "$process_name" | grep -vE "grep|status" | awk '{print $2}'))
                if [ -n "$proc" ]; then 
                    echo "[INFO] $(date '+%H:%M:%S'): Server running. Count running process: $(echo ${#proc[@]})"
                else
                    echo "[INFO] $(date '+%H:%M:%S'): Server not running. Count running process: $(echo ${#proc[@]})"
                fi
            fi
        elif [[ $1 == "log" ]]; then
            if [[ $2 == "bot" ]]; then
                if [[ $3 =~ ^[0-9]+$ ]]; then
                    tail -n $3 $path_log
                else
                    tail -f $path_log
                fi
            elif [[ $2 == "qb" ]]; then
                if [[ $3 == "all" ]]; then
                    qbittorrent-log all
                else
                    qbittorrent-log
                fi
            elif [[ $2 == "plex" ]]; then
                if [[ $3 == "server" ]]; then
                    if [[ $4 == "all" ]]; then
                        plex-log server all
                    else
                        plex-log server
                    fi
                elif [[ $3 == "system" ]]; then
                    if [[ $4 == "all" ]]; then
                        plex-log system all
                    else
                        plex-log system
                    fi
                else
                    echo "Available parameters: server and system"
                fi
            else
                echo "Available parameters: bot, qb and plex"
            fi
        else
            echo "Available parameters: start, status, log and stop"
        fi
        exit 0
    fi
fi

### Логирование
function log-rotate {
    byte=$((($log_size_mbyte*1024*1024)))
    if [ ! -e "$file_path" ]; then
        touch $path_log 
    elif [[ $size > $byte ]]; then
        size=$(ls -l $path_log | awk '{print $5}')
        cp $path_log $(echo "$path_log"_bak)
        rm $path_log
    fi
}

log-rotate

################################### 🔵 🔵 🔵 Telegram 🔵 🔵 🔵 ####################################
### API documentation: https://core.telegram.org/bots/api

function test-telegram {
    endpoint="getMe"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    curl -s $url -X "GET"
}

### Функция отправки сообщения в to Telegram
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

### Функция отправки keyboard-меню в Telegram
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

### Функция обновления последнего сообщения в Telegram
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

### ⬆️⬆️⬆️ Функция отправка файла в Telegram ⬆️⬆️⬆️
function send-file {
    document=$1
    endpoint="sendDocument"
    url="https://api.telegram.org/bot$TG_TOKEN/$endpoint"
    curl_response=$(curl -s -X POST $url \
        -F chat_id="$CHAT" \
        -F document=@"$document")
    if [[ "$curl_response" =~ "error_code" ]]; then
        echo "[WARN] $(date '+%H:%M:%S'): cURL: $curl_response" >> $path_log
    else
        echo "[OK]   $(date '+%H:%M:%S'): cURL: sent file to telegram" >> $path_log
    fi
}

### Функция чтения сообщений из Telegram
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

################################## 🟢 🟢 🟢 qBittorrent 🟢 🟢 🟢 ##################################
### WebUI API documentation: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)
### Tested on version 4.6.0 and 4.6.5

### Проверка доступности qBittorrent
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

# qbittorrent-test
# 0 - ОК
# 1 - Ошибка авторизации
# 2 - Служба не запущена (порт недоступен)
# 3 - Сервер недоступен (нет пинга)

### Общие настройки лимитов скорости загрузки и отдачи ⬇️⬆️📶
function qbittorrent-get-limit {
    endpoint=$1
    # qbittorrent-auth
    curl -s "$QB_ADDR/api/v2/transfer/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq .
}

# qbittorrent-get-limit info
# qbittorrent-get-limit speedLimitsMode
# qbittorrent-get-limit downloadLimit
# qbittorrent-get-limit uploadLimit

### Переключить на альтернативные ограничения скорости (POST) 📶📶📶
function qbittorrent-switch-limit {
    qbittorrent-auth
    endpoint="api/v2/transfer/toggleSpeedLimitsMode"
    curl -s -X POST "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR"
}

# qbittorrent-switch-limit

### Найстройки приложения
function qbittorrent-settings {
    # qbittorrent-auth
    endpoint="api/v2/app/preferences"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq .
}

# qbittorrent-settings
# qbittorrent-settings | jq -r .save_path

### Размер свободного места на диске (server_state), список всех торрентов (torrents) и трекеров (trackers)
function qbittorrent-free-space-disk {
    qbittorrent-auth
    endpoint="api/v2/sync/maindata"
    curl -s -X POST "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq .
}

# qbittorrent-free-space-disk

### Функция получения данных для статус
function qbittorrent-data {
    free_space_disk=$(
        qbittorrent-free-space-disk | jq -r ". | {
            free_space: (.server_state.free_space_on_disk / 1024 / 1024 / 1024 | round )
        } | .free_space"
    )
    save_path_default=$(qbittorrent-settings | jq -r .save_path)
    qb_limit_down=$(qbittorrent-get-limit downloadLimit)
    qb_limit_upload=$(qbittorrent-get-limit uploadLimit)
    qb_limit_down_mb=$(echo "scale=2; $qb_limit_down/1024/1024" | bc)
    qb_limit_upload_mb=$(echo "scale=2; $qb_limit_upload/1024/1024" | bc)
    qb_limit_mode=$(qbittorrent-get-limit speedLimitsMode)
    if [[ $qb_limit_mode == 0 ]]; then
        qb_limit_mode_text="Отключены"
    elif [[ $qb_limit_mode == 1 ]]; then
        qb_limit_mode_text="Включены"
    fi
    data="🐸 Список добавленных торрентов \n"
    data+="*Свободного места на диске*: $free_space_disk Гб \n"
    data+="*Путь сохранения (по умолчанию):* $save_path_default \n"
    data+="*Лимит скорости:* $qb_limit_down_mb ⬇️ $qb_limit_upload_mb ⬆️ МБайт/c \n"
    data+="*Альтернативные ограничения скорости:* $qb_limit_mode_text \n"
    data+="*Обновлено:* $(date '+%H:%M:%S')"
    echo -e "$data"
}

### Для конечной точки /status (функция menu-status) и /info (функция menu-info)
### Основная функция получения списка торрентов добавленных на клиенте и дополнительная информация для выбранной раздачи
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

# qbittorrent-info

### Для функции menu-info (/info)
### Функция получения свойств выбранной торрент раздачи (дополнительная информация для функции menu-info после информации из функции qbittorrent-info)
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

# qbittorrent-properties "a72bd27a0ce265a3c7965392bc06c25edd759214"

### /file_torrent
### Получить список файлов выбранной раздачи
function qbittorrent-files {
    torrent_hash=$1
    qbittorrent-auth
    endpoint_delete="api/v2/torrents/files"
    curl -s "$QB_ADDR/$endpoint_delete" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hash=$torrent_hash" | jq .
}

# qbittorrent-files "a72bd27a0ce265a3c7965392bc06c25edd759214"

# Priority:
# 0 - skip
# 1 - normal
# 6 - high
# 7 - maximum

### /torrent_priority
### Изменить приоритет выбранно файла ⏸▶️🔼⏫
function qbittorrent-priority {
    torrent_hash=$1
    # Порядковый номер файла
    file_index=$2
    # 0/1/6/7
    priority=$3
    qbittorrent-auth
    endpoint_delete="api/v2/torrents/filePrio"
    curl -s "$QB_ADDR/$endpoint_delete" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hash=$torrent_hash" \
        --data "id=$file_index" \
        --data "priority=$priority"
}

# qbittorrent-priority "a72bd27a0ce265a3c7965392bc06c25edd759214" 0 0
# qbittorrent-priority "a72bd27a0ce265a3c7965392bc06c25edd759214" 1 1
# qbittorrent-priority "a72bd27a0ce265a3c7965392bc06c25edd759214" 2 6
# qbittorrent-priority "a72bd27a0ce265a3c7965392bc06c25edd759214" 3 7

### /download_video_id
### ⏩ Добавить на загрузку выбранный торрент файл (POST)
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

### /pause
### ⏸ Пауза выбранного торрент файла
function qbittorrent-pause {
    torrent_hash=$1
    qbittorrent-auth
    endpoint_pause="api/v2/torrents/pause"
    curl -s "$QB_ADDR/$endpoint_pause" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$torrent_hash"
}

# qbittorrent-pause "a72bd27a0ce265a3c7965392bc06c25edd759214"

### /resume
### ▶️ Восстановить загрузку (из паузы) выбранного торрент файла
function qbittorrent-resume {
    torrent_hash=$1
    qbittorrent-auth
    endpoint_resume="api/v2/torrents/resume"
    curl -s "$QB_ADDR/$endpoint_resume" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$torrent_hash"
}

# qbittorrent-resume "a72bd27a0ce265a3c7965392bc06c25edd759214"

### 🗑 /delete_torrent
### ❌ /delete_video
### Удалить раздачу из клиента с или без содержимым контента (deleteFiles true/false)
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

# qbittorrent-delete "a72bd27a0ce265a3c7965392bc06c25edd759214" "false"
# qbittorrent-delete "a72bd27a0ce265a3c7965392bc06c25edd759214" "true"

### Проверить торрент файл (пересканировать на целостность)
function qbittorrent-recheck {
    hash=$1
     qbittorrent-auth
    endpoint_delete="api/v2/torrents/recheck"
    curl -s "$QB_ADDR/$endpoint_delete" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hashes=$hash"
}

# qbittorrent-recheck "A72BD27A0CE265A3C7965392BC06C25EDD759214"

##################################### 🧲🧲🧲 Info hash 🧲🧲🧲 #####################################

### Добавить торрент файл по хэш сумме
function qbittorrent-add-torrent-from-hash {
    hash=$1
    magnet_link="magnet:?xt=urn:btih:$hash"
    qbittorrent-auth
    curl -s "$QB_ADDR/api/v2/torrents/add" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data-urlencode "urls=$magnet_link"
}

# qbittorrent-add-torrent-from-hash "A72BD27A0CE265A3C7965392BC06C25EDD759214"

### Экспортировать из раздачи с полученными метаданными на клиенте в торрент файл
function qbittorrent-export-torrent-file {
    hash=$1
    qbittorrent-auth
    endpoint="api/v2/torrents/export"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "hash=$hash" \
        -o "$path/$hash.torrent"
}

# qbittorrent-export-torrent-file "A72BD27A0CE265A3C7965392BC06C25EDD759214"

#-----------------------------------------------------------------------------------------------------

### Функция проверки статуса загрузки метаданных
function qbittorrent-metadata-status {
    hash=$1
    qbittorrent-auth
    endpoint="api/v2/torrents/info"
    status=$(curl -s "$QB_ADDR/$endpoint?hashes=$hash" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq -r '.[0].state')
    if [[ $status == "null" ]]; then
        # Торрент не найден (не добавлен)
        echo null
    elif [[ $status != "metaDL" ]]; then
        # Метаданные получены
        echo true
    else
        # Загрузка метаданных
        echo false
    fi
}

# qbittorrent-metadata-status "A72BD27A0CE265A3C7965392BC06C25EDD759214"

### Переименовать торрент раздачу (которая отображается в клиенте)
function qbittorrent-rename-torrent {
    torrent_hash=$1
    new_name_torrent=$2
    qbittorrent-auth
    endpoint="api/v2/torrents/trackers"
    curl "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq .
}

# qbittorrent-rename-torrent "23a29deb70f2d38a462575f81bb6d79ca5415673" "Rick"

### Переименовать торрент файл или директорию
function qbittorrent-rename-file {
    torrent_hash=$1
    new_name_file=$2
    type_file=$3
    # Получаем текущий путь по хэшу и забираем из него старое имя
    old_torrent_path=$(qbittorrent-info | jq -r ". | select(.hash == \"$torrent_hash\").path")
    echo "[INFO] $(date '+%H:%M:%S'): Old torrent path: $old_torrent_path" # >> $path_log
    old_torrent_name=$(echo $old_torrent_path | sed -r 's/.+\\//')
    # Забираем текущий путь к файлу и формируем путь с новым именем файла
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

### Список всех уникальных трекеров используемых торрентами
function qbittorrent-tracker-list {
    qbittorrent-auth
    endpoint="api/v2/torrents/info"
    hash_list=$(curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq -r .[].hash)
    endpoint="api/v2/torrents/trackers"
    tracker_list=""
    for hash in $hashes; do
        trackers=$(curl -s "$QB_ADDR/$endpoint?hash=$hash" -b $path_qb_cookies --header "Referer: $QB_ADDR")
        tracker_list+="$(echo "$trackers" | jq -r .[].url)"
        tracker_list+=$'\n'
    done
    echo "$tracker_list" | grep . | sort | uniq
}

# qbittorrent-tracker-list

### RSS
### Получить список добавленных новостных лент и их содержимое (true), которые слушает клиент
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

############################## 🍿🍿🍿 qBittorrent Search Plugins 🍿🍿🍿 ##############################
### Список плагинов и процесс установки: https://github.com/qbittorrent/search-plugins/wiki
### Плагин для Kinozal, RuTracker, RuTor и NoNameClub: https://github.com/imDMG/qBt_SE
### Файл настроек: "%localappdata%\qBittorrent\nova3\engines\kinozal.json"
### Автоматизированный процесс установки и настройки плагина для Windows: https://github.com/Lifailon/PS-Commands/blob/rsa/Scripts/qbittorrent-plugin-search-kinozal-install.ps1

### Получить список установленных плагинов поиска
function qbittorrent-plugin-list {
    qbittorrent-auth
    endpoint="api/v2/search/plugins"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" | jq '.[] | {
            Name: .fullName,
            Url: .url,
            Enabled: .enabled
        }'
}

# qbittorrent-plugin-list

### Установить плагин
function qbittorrent-install-plugin {
    url=$1
    qbittorrent-auth
    endpoint="api/v2/search/installPlugin"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR"
        --data "sources=$url"
}

# qbittorrent-install-plugin "https://raw.githubusercontent.com/imDMG/qBt_SE/master/engines/kinozal.py"

### Начать поиск и получить его идентификатор (POST)
function qbittorrent-search {
    title=$1
    plugin=$2
    category="all"
    qbittorrent-auth
    endpoint="api/v2/search/start"
    curl -s -X POST "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "pattern=$title" \
        --data "plugins=$plugin" \
        --data "category=$category" | jq -r .id
}

# search_id=$(qbittorrent-search "Rocky" "Kinozal")
# search_id=$(qbittorrent-search "Rocky" "all")
# search_id=$(qbittorrent-search "Rocky" "enabled")

### Получить статус поиска (Running или Stopped) и количество результатов (total)
function qbittorrent-status {
    id=$1
    qbittorrent-auth
    endpoint="api/v2/search/status"
    if [[ -z "$id" ]]; then
        curl -s "$QB_ADDR/$endpoint" \
            -b $path_qb_cookies \
            --header "Referer: $QB_ADDR"
    else
        curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "id=$id"
    fi
}

# qbittorrent-status
# qbittorrent-status $search_id | jq -r .[].status

### Остановить поиск
function qbittorrent-stop {
    id=$1
    qbittorrent-auth
    endpoint="api/v2/search/stop"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "id=$id"
}

# qbittorrent-stop $search_id

### Получить результаты поиска
function qbittorrent-result {
    id=$1
    qbittorrent-auth
    endpoint="api/v2/search/results"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "id=$id"
}

# qbittorrent-result $search_id

### Удалить поиск
function qbittorrent-clear {
    id=$1
    qbittorrent-auth
    endpoint="api/v2/search/delete"
    curl -s "$QB_ADDR/$endpoint" \
        -b $path_qb_cookies \
        --header "Referer: $QB_ADDR" \
        --data "id=$id" | jq -r .
}

# qbittorrent-clear $search_id

#################################### ❤️❤️❤️ WebTorrent ❤️❤️❤️ #####################################

### Формируем magnet ссылку из хэша с указанием списка серверов торрент трекеров 
function magnet-uri {
    info_hash=$1
    trackers=(
        "http://tr0.torrent4me.com/ann?uk=kCm7WcIM00"
        "http://tr1.torrent4me.com/ann?uk=kCm7WcIM00"
        "http://tr2.torrent4me.com/ann?uk=kCm7WcIM00"
        "http://tr3.torrent4me.com/ann?uk=kCm7WcIM00"
        "http://tr4.torrent4me.com/ann?uk=kCm7WcIM00"
        "http://tr5.torrent4me.com/ann?uk=kCm7WcIM00"
        "http://tr0.tor4me.info/ann?uk=kCm7WcIM00"
        "http://tr1.tor4me.info/ann?uk=kCm7WcIM00"
        "http://tr2.tor4me.info/ann?uk=kCm7WcIM00"
        "http://tr3.tor4me.info/ann?uk=kCm7WcIM00"
        "http://tr4.tor4me.info/ann?uk=kCm7WcIM00"
        "http://tr5.tor4me.info/ann?uk=kCm7WcIM00"
        "http://tr0.tor2me.info/ann?uk=kCm7WcIM00"
        "http://tr1.tor2me.info/ann?uk=kCm7WcIM00"
        "http://tr2.tor2me.info/ann?uk=kCm7WcIM00"
        "http://tr3.tor2me.info/ann?uk=kCm7WcIM00"
        "http://tr4.tor2me.info/ann?uk=kCm7WcIM00"
        "http://tr5.tor2me.info/ann?uk=kCm7WcIM00"
        "http://retracker.local/announce"
        "wss://tracker.openwebtorrent.com"
        "wss://tracker.openwebtorrent.com"
    )
    magnet="magnet:?xt=urn:btih:$info_hash"
    for tracker in "${trackers[@]}"; do
      magnet+="&tr=$(echo -n "$tracker")"
    done
    echo $magnet | sed -r "s/\s//g"
}

# magnet-uri "7395a859e8e590418f422e7d0dfe68860de90631"

#-----------------------------------------------------------------------------------------------------

################################# 🔲 🔲 🔲 Transmission 🔲 🔲 🔲 ##################################
# RPC API documentation: https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md

### Arguments:
# activityDate - Дата последней активности торрента
# addedDate - Дата добавления торрента
# availability - Доступность торрента (сколько процентов от общего размера доступно)
# bandwidthPriority - Приоритет пропускной способности для торрента
# comment - Комментарий к торренту
# corruptEver - Объем данных, полученных с ошибками
# creator - Создатель торрента
# dateCreated - Дата создания торрента
# desiredAvailable - Объем доступных данных, которые еще не загружены
# doneDate - Дата завершения загрузки торрента
# downloadDir - Директория для загрузки файлов торрента
# downloadedEver - Объем данных, загруженных за все время
# downloadLimit - Лимит скорости загрузки
# downloadLimited - Флаг ограничения скорости загрузки
# editDate - Дата последнего редактирования торрента
# error - Код ошибки
# errorString - Описание ошибки
# eta - Ожидаемое время завершения загрузки
# etaIdle - Ожидаемое время до перехода в режим ожидания
# file-count - Количество файлов в торренте
# files - Список файлов в торренте
# fileStats - Статистика по файлам торрента
# group - Группа, к которой принадлежит торрент
# hashString - Хеш-строка торрента
# haveUnchecked - Объем непроверенных данных
# haveValid - Объем проверенных данных
# honorsSessionLimits - Флаг соблюдения общих лимитов сессии
# id - Уникальный идентификатор торрента
# isFinished - Флаг завершения загрузки торрента
# isPrivate - Флаг приватности торрента
# isStalled - Флаг застоя торрента
# labels - Метки торрента
# leftUntilDone - Оставшийся объем данных до завершения загрузки
# magnetLink - Магнет-ссылка торрента
# manualAnnounceTime - Время до следующего ручного объявления
# maxConnectedPeers - Максимальное количество подключенных пиров
# metadataPercentComplete - Процент завершенности загрузки метаданных
# name - Имя торрента
# peer-limit - Лимит числа пиров
# peers - Список пиров
# peersConnected - Количество подключенных пиров
# peersFrom - Источники пиров
# peersGettingFromUs - Количество пиров, получающих данные от нас
# peersSendingToUs - Количество пиров, отправляющих данные нам
# percentComplete - Процент завершенности загрузки
# percentDone - Процент выполнения загрузки
# pieces - Список частей торрента
# pieceCount - Количество частей
# pieceSize - Размер части
# priorities - Приоритеты файлов в торренте
# primary-mime-type - Основной MIME-тип файлов в торренте
# queuePosition - Позиция в очереди загрузки
# rateDownload - Скорость загрузки в байтах в секунду
# rateUpload - Скорость отдачи в байтах в секунду
# recheckProgress - Прогресс повторной проверки
# secondsDownloading - Секунды, потраченные на загрузку
# secondsSeeding - Секунды, потраченные на раздачу
# seedIdleLimit - Лимит времени простоя при раздаче
# seedIdleMode - Режим ожидания при раздаче
# seedRatioLimit - Лимит соотношения раздачи к загрузке
# seedRatioMode - Режим соотношения раздачи к загрузке
# sequentialDownload - Флаг последовательной загрузки
# sizeWhenDone - Размер при завершении загрузки
# startDate - Дата начала загрузки
# status - Статус торрента
# trackers - Список трекеров
# trackerList - Список URL-адресов трекеров
# trackerStats - Статистика по каждому трекеру
# totalSize - Общий размер файлов, указанных в торренте
# torrentFile - Путь к файлу .torrent в локальной файловой системе (создается клиентом автоматически)
# uploadedEver -  Общий объем данных, отданных (загруженных другим пирам) за все время работы торрента
# uploadLimit - Максимальная скорость отдачи (загрузки другим пирам) в килобитах в секунду
# uploadLimited - Булево значение, установлено ли ограничение на скорость отдачи (если true, скорость отдачи ограничена значением uploadLimit)
# uploadRatio-  Соотношение объема отданных данных к объему загруженных данных
# wanted - Список файлов в торренте, отмеченных для загрузки (файлы, не включенные в этот список, будут пропущены при загрузке)
# webseeds - Список URL-адресов веб-сидов, которые могут использоваться для загрузки данных торрента
# webseedsSendingToUs - Количество веб-сидов, которые в данный момент активно отправляют данные клиенту

### Status:
# 0	- Торрент остановлен
# 1	- Торрент в очереди на проверку локальных данных
# 2	- Торрент проверяет локальные данные
# 3	- Торрент в очереди на загрузку
# 4	- Торрент загружается
# 5	- Торрент в очереди на раздачу
# 6	- Торрент раздается

function transmission-status {
    endpoint="transmission/rpc"
    request=$(curl -s -X POST -u "$TRANS_USER:$TRANS_PASS" "$TRANS_ADDR/$endpoint")
    session_id=$(echo $request | sed -r "s/.+Id: //g; s/<.+//")
    curl -s "$TRANS_ADDR/$endpoint" \
        -u "$TRANS_USER:$TRANS_PASS" \
        -H "X-Transmission-Session-Id: $session_id" \
        -H "Content-Type: application/json" \
        -d '{
            "method": "torrent-get",
            "arguments": {
                "fields": [
                    "name",
                    "id",
                    "hashString",
                    "comment",
                    "metadataPercentComplete",
                    "status",
                    "percentDone",
                    "percentComplete",
                    "isStalled",
                    "totalSize",
                    "downloadedEver",
                    "rateDownload",
                    "rateUpload",
                    "addedDate",
                    "startDate",
                    "doneDate",
                    "secondsDownloading",
                    "torrentFile"
                    "downloadDir",
                    "file-count",
                    "files",
                    "fileStats",
                    "priorities",
                    "trackers"
                ]
            }
        }' | jq '.arguments.torrents[] | {
            name: .name,
            id: .id,
            hashString: .hashString,
            comment: .comment,
            metadataPercentComplete: .metadataPercentComplete,
            status: .status,
            percentDone: .percentDone,
            percentDoneRaw: (.percentDone * 100 | round),
            percentComplete: .percentComplete,
            isStalled: .isStalled,
            totalSizeGb: ((.totalSize / 1024 / 1024 / 1024) * 100 | round / 100),
            downloadedGb: ((.downloadedEver / 1024 / 1024 / 1024) * 100 | round / 100),
            DownloadMBs: ((.rateDownload / 1024 / 1024) * 100 | round / 100),
            UploadMBs: ((.rateUpload / 1024 / 1024) * 100 | round / 100),
            addedDate: (.addedDate | strftime("%d.%m.%Y %H:%M")),
            startDate: (.startDate | strftime("%d.%m.%Y %H:%M")),
            minutesDownloading: (.secondsDownloading / 60) | round,
            torrentFile: .torrentFile,
            downloadDir: .downloadDir,
            fileCount: ."file-count",
            files: .files,
            fileStats: .fileStats,
            priorities: .priorities,
            trackers: .trackers
        }'
}

# transmission-status
# transmission-status | jq -r '. | "\(.name) - \(.id)"'

### Приоритеты (содержит fileStats.priority и priorities)
# 0  - Обычный
# 1  - Высокий
# -1 - Низкий
# Статус пропуска содержит параметр fileStats.priority.wanted

### Список файлов из статуса загрузки в процентах и номера приоритета
function transmission-files {
    id=$1
    transmission_files_list=$(transmission-status | jq ". | select(.id == $id)")
    transmission_files_array=$(echo $transmission_files_list | jq -r .files[].name)
    pri_num=-1
    for file in $transmission_files_array; do
        # file=$(echo $transmission_files_list | jq -r .files[0].name)
        pri_num=$(echo $pri_num + 1 | bc)
        select_file=$(echo $transmission_files_list | jq -r ".files[] | select(.name == \"$file\")")
        procCompleted=$(echo $select_file | jq -r "(.bytesCompleted / .length) * 100 | round")
        filePrioriti=$(echo $transmission_files_list | jq -r ".priorities[$pri_num]")
        fileSkip=$(echo $transmission_files_list | jq -r ".fileStats[$pri_num].wanted")
        echo $procCompleted $filePrioriti $fileSkip
    done
}

# transmission-files 1

### Функция изминения приоритета и пропуск выбранного файла
function transmission-priority {
    trans_torrent_id=$1
    trans_file_index=$2
    trans_file_pri=$3
    if [[ $trans_file_pri == "skip" ]]; then
        trans_param="files-unwanted"
    elif [[ $trans_file_pri == "resume" ]]; then
        trans_param="files-wanted"
    elif [[ $trans_file_pri == "low" || $trans_file_pri == "high" || $trans_file_pri == "normal" ]]; then
        trans_param="priority-$trans_file_pri"
    else
        break
    fi
    endpoint="transmission/rpc"
    request=$(curl -s -X POST -u "$TRANS_USER:$TRANS_PASS" "$TRANS_ADDR/$endpoint")
    session_id=$(echo $request | sed -r "s/.+Id: //g; s/<.+//")
    curl -s -X POST "$TRANS_ADDR/$endpoint" \
        -u "$TRANS_USER:$TRANS_PASS" \
        -H "X-Transmission-Session-Id: $session_id" \
        -H "Content-Type: application/json" \
        -d "{
            \"method\": \"torrent-set\",
            \"arguments\": {
                \"ids\": [$trans_torrent_id],
                \"$trans_param\": [$trans_file_index]
            }
        }"
    # Если функция принимает изминение приоритета, по умолчанию возобновляется загрузка из пропуска
    if [[ $trans_file_pri == "low" || $trans_file_pri == "high" || $trans_file_pri == "normal" ]]; then
        transmission-priority $trans_torrent_id $trans_file_index resume
    fi
}

# transmission-priority 1 0 skip
# transmission-priority 1 0 resume
# transmission-priority 1 0 low
# transmission-priority 1 0 high
# transmission-priority 1 0 normal

### Функция для возврата эмодзи эквивалентного переданному числу
function number-emoji {
    number=$1
    digits=($(echo $number | grep -o .))
    emoji=""
    for digit in "${digits[@]}"; do
        case $digit in
            1) emoji+="1️⃣";;
            2) emoji+="2️⃣";;
            3) emoji+="3️⃣";;
            4) emoji+="4️⃣";;
            5) emoji+="5️⃣";;
            6) emoji+="6️⃣";;
            7) emoji+="7️⃣";;
            8) emoji+="8️⃣";;
            9) emoji+="9️⃣";;
            0) emoji+="0️⃣";;
        esac
    done

    echo $emoji
}

# number-emoji 15
# number-emoji 100

### Список торрентов в клиенте и их статус
function transmission-tg-status {
    transmission_status=$(transmission-status)
    id_array=$(echo "$transmission_status" | jq -r .id)
    keyboard='{"inline_keyboard":['
    for id in $id_array; do
        select=$(echo "$transmission_status" | jq -r ". | select(.id == $id)")
        tr_name=$(echo $select | jq -r .name)
        tr_percentDone=$(echo $select | jq -r .percentDone)
        tr_percentComplete=$(echo $select | jq -r .percentComplete)
        tr_metadata=$(echo $select | jq -r .metadataPercentComplete)
        tr_stalled=$(echo $select | jq -r .isStalled)
        tr_down=$(echo $select | jq -r .status)
        if [[ $tr_percentDone == 1 || $tr_percentComplete == 1 ]]; then
            tr_status=$(echo $tr_name | sed -r "s/^/🆗 /")
        elif [[ $tr_metadata != 1 ]]; then
            tr_status=$(echo $tr_name | sed -r "s/^/🧲 /")
        elif [[ $tr_stalled == true ]]; then
            tr_status=$(echo $tr_name | sed -r "s/^/⏸ /")
        elif [[ $tr_down == 4 ]]; then
            tr_status=$(echo $tr_name | sed -r "s/^/⬇️ /")
        else
            tr_status=$(echo $tr_name | sed -r "s/^/📶 /")
        fi
        keyboard+="[{\"text\":\"$tr_status\",\"callback_data\":\"/trans_info $id\"}],"
    done
    keyboard+="[{\"text\":\"🔄 Обновить статус\",\"callback_data\":\"\/trans_status\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
    data="🔲 Список добавленных торрентов \n"
    data+="*Обновлено:* $(date '+%H:%M:%S')"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### Получить подробную информацию выбранной раздачи в клиенте
function transmission-tg-info {
    tr_id=$1
    select=$(transmission-status | jq -r ". | select(.id == $tr_id)")
    tr_name=$(echo $select | jq -r .name)
    tr_percentDone=$(echo $select | jq -r .percentDone)
    tr_percentComplete=$(echo $select | jq -r .percentComplete)
    tr_metadata=$(echo $select | jq -r .metadataPercentComplete)
    tr_stalled=$(echo $select | jq -r .isStalled)
    tr_down=$(echo $select | jq -r .status)
    if [[ $tr_percentDone == 1 || $tr_percentComplete == 1 ]]; then
        tr_status="🆗 Загружено"
    elif [[ $tr_metadata != 1 ]]; then
        tr_status="🧲 Загрузка метаданных"
    elif [[ $tr_stalled == true ]]; then
        tr_status="⏸ Пауза"
    elif [[ $tr_down == 4 ]]; then
        tr_status="⬇️ Загрузка"
    else
        tr_status="📶 Неизвестно"
    fi
    data=$(echo "*Название:* $tr_name \n")
    data+=$(echo "*Статус загрузки:* $tr_status \n")
    data+=$(echo "*Прогресс:* $(echo $select | jq -r .percentDoneRaw) % \n")
    data+=$(echo "*Размер:* $(echo $select | jq -r .totalSizeGb) Гб \n")
    data+=$(echo "*Загружено:* $(echo $select | jq -r .downloadedGb) Гб \n")
    data+=$(echo "*Количество файлов:* $(echo $select | jq -r .fileCount) \n")
    data+=$(echo "*Скорость загрузки:* $(echo $select | jq -r .DownloadMBs) Мб/c \n")
    data+=$(echo "*Скорость отдачи:* $(echo $select | jq -r .UploadMBs) Мб/c \n")
    data+=$(echo "*Дата добавления:* $(echo $select | jq -r .addedDate) \n")
    data+=$(echo "*Дата начала или продолжения загрузки:* $(echo $select | jq -r .startDate) \n")
    data+=$(echo "*Время загрузки:* $(echo $select | jq -r .minutesDownloading) минут \n")
    data+=$(echo "*Обновлено:* $(date '+%H:%M:%S')\n")
    data+=$(echo "*Описание:* $(echo $select | jq -r .comment) \n")
    data+=$(echo "*Инфо хеш:* \`$(echo $select | jq -r .hashString)\` \n")
    keyboard='{"inline_keyboard":['
    transmission_files_array=$(transmission-files $tr_id)
    IFS=$'\n'
    pri_num=-1
    for tfile in ${transmission_files_array[@]}; do
        # tfile=$(echo "$transmission_files_array" | head -n 1)
        pri_num=$(echo $pri_num + 1 | bc)
        tfile_proc=$(echo $tfile | awk '{print $1}')
        tfile_pri=$(echo $tfile | awk '{print $2}')
        tfile_stat=$(echo $tfile | awk '{print $3}')
        if [[ $tfile_stat == false ]]; then
            tfile_pri_stat="⏸"
        elif [[ $tfile_pri == -1 ]]; then
            tfile_pri_stat="🔽"
        elif [[ $tfile_pri == 0 ]]; then
            tfile_pri_stat="▶️"
        elif [[ $tfile_pri == 1 ]]; then
            tfile_pri_stat="🔼"
        fi
        ### Статус загрузки
        if [[ $tfile_proc -eq 100 ]]; then
            squares="🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩"
        elif [[ $tfile_proc -ge 10 && $tfile_proc -lt 100 ]]; then
            green_squares_count=$((tfile_proc / 10))
            white_squares_count=$((10 - green_squares_count))
            squares=""
            for ((i=1; i<=green_squares_count; i++)); do
                squares+="🟩"
            done
            for ((i=1; i<=white_squares_count; i++)); do
                squares+="⬜️"
            done
        else
            squares="⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️"
        fi
        # keyboard+="[{\"text\":\"$(number-emoji $(echo $pri_num + 1 | bc)) 🔹 $tfile_pri_stat $squares ($tfile_proc%)\",\"callback_data\":\"/trans_info $tr_id\"}],"
        keyboard+="[{\"text\":\"$tfile_pri_stat $squares\",\"callback_data\":\"/trans_info $tr_id\"}],"
    done
    # ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    # 🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/trans_status\"},"
    keyboard+="{\"text\":\"🔄 Обновить\",\"callback_data\":\"/trans_info $tr_id\"}],"
    keyboard+="[{\"text\":\"⏸ Пауза\",\"callback_data\":\"\/trans_pause $tr_id stop\"},"
    keyboard+="{\"text\":\"▶️ Возобновить\",\"callback_data\":\"/trans_pause $tr_id start\"}],"
    keyboard+="[{\"text\":\"🗑 Удалить торрент\",\"callback_data\":\"\/trans_remove $tr_id false\"},"
    keyboard+="{\"text\":\"❌ Удалить данные\",\"callback_data\":\"/trans_remove $tr_id true\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]"
    keyboard+="]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### Добавление торрента в клиент по инфо хеш
function transmission-add {
    hash=$1
    endpoint="transmission/rpc"
    request=$(curl -s -X POST -u "$TRANS_USER:$TRANS_PASS" "$TRANS_ADDR/$endpoint")
    session_id=$(echo $request | sed -r "s/.+Id: //g; s/<.+//")
    curl -s "$TRANS_ADDR/$endpoint" \
        -u "$TRANS_USER:$TRANS_PASS" \
        -H "X-Transmission-Session-Id: $session_id" \
        -H "Content-Type: application/json" \
        -d "{
            \"method\": \"torrent-add\",
            \"arguments\": {
                \"filename\": \"magnet:?xt=urn:btih:$hash\"
            }
        }"
}

# transmission-add 828835b8b8b50a0d57fc8c5a4d99c997e9959ea4

### Управление остановкой и возобновлением загрузки
function transmission-pause {
    id=$1
    type=$2
    endpoint="transmission/rpc"
    request=$(curl -s -X POST -u "$TRANS_USER:$TRANS_PASS" "$TRANS_ADDR/$endpoint")
    session_id=$(echo $request | sed -r "s/.+Id: //g; s/<.+//")
    curl -s "$TRANS_ADDR/$endpoint" \
        -u "$TRANS_USER:$TRANS_PASS" \
        -H "X-Transmission-Session-Id: $session_id" \
        -H "Content-Type: application/json" \
        -d "{
            \"method\": \"torrent-$type\",
            \"arguments\": {
                \"ids\": [$id]
            }
        }"
}

# transmission-pause 5 stop
# transmission-pause 5 start

### Удалить торрент по id из статуса
function transmission-remove {
    id=$1
    type=$2
    endpoint="transmission/rpc"
    request=$(curl -s -X POST -u "$TRANS_USER:$TRANS_PASS" "$TRANS_ADDR/$endpoint")
    session_id=$(echo $request | sed -r "s/.+Id: //g; s/<.+//")
    curl -s "$TRANS_ADDR/$endpoint" \
        -u "$TRANS_USER:$TRANS_PASS" \
        -H "X-Transmission-Session-Id: $session_id" \
        -H "Content-Type: application/json" \
        -d "{
            \"method\": \"torrent-remove\",
            \"arguments\": {
                \"ids\": [$id],
                \"delete-local-data\": $type
            }
        }"
}

# transmission-remove 5 false
# transmission-remove 6 true

############################### 🟠 🟠 🟠 Plex Media Server 🟠 🟠 🟠 ###############################
### No official API documentation
### Token: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token
### Endpoint list:
# curl -s "$PLEX_ADDR" -H "X-Plex-Token: $PLEX_TOKEN" -H "accept: application/json" | jq -r .MediaContainer.Directory[].key
### Version
# curl -s "$PLEX_ADDR/servers" -H "X-Plex-Token: $PLEX_TOKEN" -H "accept: application/json" | jq -r .MediaContainer.Server[].version
### Builder Tasks:
# curl -s "$PLEX_ADDR/butler" -H "X-Plex-Token: $PLEX_TOKEN" -H "accept: application/json" | jq .ButlerTasks.ButlerTask[]
### Plugins:
# curl -s "$PLEX_ADDR/channels/all" -H "X-Plex-Token: $PLEX_TOKEN" -H "accept: application/json" | jq .
### Devices (web clients):
# curl -s "$PLEX_ADDR/devices" -H "X-Plex-Token: $PLEX_TOKEN" -H "accept: application/json" | jq .

### /plex_status_<key>
### Даты создания, обновления контента и последней синхронизации в выбранной секции Plex
function plex-sections {
    endpoint="library/sections"
    plex_dir=$(curl -m 2 -s -X GET "$PLEX_ADDR/$endpoint" \
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

# plex-sections

### /plex_info
### Функция получения списка всех секций на сервере Plex через функция plex-sections для отправки в Telegram
function plex-info {
    plex_sections=$(plex-sections | jq -r ".name,.key")
    keyboard='{"inline_keyboard":['
    if [[ -z "$plex_sections" ]]; then
        data="☹️ *Приложение Plex не запущено*"
    else
        data="🍿 Выберите секцию в Plex для доступа к его контенту:"
        IFS=$'\n'
        name_section=""
        key_section=""
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
    fi
    app_name="plex_media_server"
    #keyboard+="[{\"text\":\"🟠 Управление\",\"callback_data\":\"\/app_status $app_name\"},"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🔲 Transmission\",\"callback_data\":\"\/trans_status\"}],"
    keyboard+="[{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"},"
    keyboard+="{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"}]]}"
    #keyboard+="{\"text\":\"⚙️ Windows API\",\"callback_data\":\"\/win_state\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$data" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$data" "$CHAT" "$keyboard"
    fi
}

### /plex_sync_<key>
### Синхронизация указанной секции в Plex по ключу
function plex-sync-section {
    key=$1
    endpoint="library/sections/$key/refresh"
    curl -s -X GET "$PLEX_ADDR/$endpoint" \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        -H "accept: application/json"
}

# plex-sections | jq -r '. | select(.key == "2") | .scanned'
# plex-sync-section 2
# plex-sections | jq -r '. | select(.key == "2") | .scanned'

### /plex_folder_<key>
### Получить список директорий и файлов в корне выбранной секции
function plex-folder-from-section {
    key=$1
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

# plex-folder-from-section 2

### /find <key/endpoint>
### Получить список всех файлов в указанной директории через ключ конечной точки
function plex-content-from-folder {
    endpoint="$1"
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

# plex-content-from-folder "/library/sections/2/folder?parent=46"
# plex-content-from-folder $(plex-folder-from-section $(plex-sections | jq -r .key) | jq -r .endpoint)

################################### 🟣 🟣 🟣 Kinozal 🟣 🟣 🟣 #####################################
### Получить хэш и список файлов раздачи используя авторизацию
function files-and-hash {
    kz_id=$1
    url_hash="https://kinozal.tv/get_srv_details.php?id=$kz_id&action=2"
    url_login="https://kinozal.tv/takelogin.php"
    url_refrer="https://kinozal.tv/"
    if [[ $PROXY == "True" ]]; then
        URL_PROXY=$(echo $PROXY_ADDR | sed -r "s/:\/\//:\/\/$PROXY_USER:$PROXY_PASS@/")
        curl -s $url_login -X POST \
            -x $URL_PROXY \
            -c $path_kz_cookies \
            -d "username=$KZ_USER&password=$KZ_PASS" 1> /dev/null
        curl -s -L $url_hash -X GET \
            -x $URL_PROXY \
            -b $path_kz_cookies \
            -H "Referer: $url_refrer"
    else
        curl -s $url_login -X POST \
            -c $path_kz_cookies \
            -d "username=$KZ_USER&password=$KZ_PASS" 1> /dev/null
        curl -s -L $url_hash -X GET \
            -b $path_kz_cookies \
            -H "Referer: $url_refrer"
    fi
}

### Функция загрузки торрент-файла с применением авторизации через cookies
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

### Текущая статистика в профиле Кинозал (загрузок на день, залито и скачено в ГБ, сид и пир в часах)
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
            {\"text\":\"🔲 Transmission\",\"callback_data\":\"\/trans_status\"}],
            [{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},
            {\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]
        ]
    }"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### Основная функция обработки данных из Кинозал (принимает полученный html из curl-запроса) + вызов функции files-and-hash
function read-html {
    html=$1
    a=$2
    type_chat=$3
    id_kz=$(echo $a | sed -r 's/.+id=//')
    ### Удаление символа кавычек (&quot;) и замена буквы ё на е
    name=$(printf "%s\n" "${html[@]}" | grep "<title>" | sed -r 's/<title>//; s/ \/.+//' | sed -r 's/`|_|\"|&|; |quot//g; s/ё/е/g')
    # name_down=$(echo $name | sed -r "s/ /_/g")
    rating_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+floatright">//; s/<.+//' | awk '{print $1}')
    rating_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r 's/.+floatright">//; s/<.+//')
    year=$(printf "%s\n" "${html[@]}" | grep -E -B 1 "class=lnks_tobrs" | head -n 1 | sed -r 's/.+<\/b> //; s/<.+//')
    if [[ $year == $(date '+%Y') ]]; then
        name="🆕 $name"
    fi
    # Хештеги по жарну
    genre=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_tobrs" | sed -r 's/.+tobrs>//; s/<.+//; s/ё/е/g' | head -n 1)
    genre_hashtag=$(echo $genre | sed -r "s/^/#/; s/,\s/ #/g")
    # Добавляем нижнее подчеркивание и его экранирование, если хэштег из двух и более слов
    genre_hashtag_join=$(echo "$genre_hashtag" | awk '{
        for (i = 1; i <= NF; i++) {
            if ($i !~ /^#/) {
                if (i > 1 && $i-1 !~ /^#/) {
                    printf "\\_%s", $i
                } else {
                    printf "%s", $i
                }
            } else {
                if (i > 1) printf " "
                printf "%s", $i
            }
        }
        printf "\n"
    }')
    # Опускаем регистр в строке
    genre_hashtag_join_down=$(echo "${genre_hashtag_join,,}")
    region=$(printf "%s\n" "${html[@]}" | grep -E "class=lnks_tobrs" | sed -r 's/.+tobrs>//; s/<.+//' | head -n 2 | tail -n 1 | sed -r 's/`|_|\"|&|;|quot//g; s/ё/е/g')
    link_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+href="//; s/" target=.+//')
    link_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r "s/.+href=\"//g; s/\".+//g")
    size=$(printf "%s\n" "${html[@]}" | grep "floatright green" -m 1 | sed -r 's/.+n">//;s/\s.+//')
    # Обновленный парсинг (в 0.4.4)
    length=$(printf "%s\n" "${html[@]}" | grep "Продолжительность:" | sed -r "s/.+<\/b> //g; s/<br.+>//g")
    lang=$(printf "%s\n" "${html[@]}" | grep "Перевод:" | sed -r "s/.+<\/b> //g; s/<br.+>//g" | sed -r "s/<.+//g")
    video=$(printf "%s\n" "${html[@]}" | grep "Качество:" | sed -r "s/.+<\/b> //g; s/<br.+>//g" | sed -r "s/<.+//g")
    audio=$(printf "%s\n" "${html[@]}" | grep "Аудио:" | sed -r "s/.+<\/b> //g; s/<br.+>//g")
    # length=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -A 1 | tail -n 1 | sed -r 's/.+b> //; s/<.+//')
    # lang=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -A 2 | tail -n 1 | sed -r 's/.+b> //; s/<.+//')
    # video=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -B 2 | tail -n 3 | head -n 1 | sed -r 's/.+b> //; s/<.+//; s/.* ([0-9]+x[0-9]+).*/\1/p' | head -n 1)
    # audio=$(printf "%s\n" "${html[@]}" | grep $size -m 2 -B 1 | tail -n 2 | head -n 1 | sed -r 's/.+b> //; s/<.+//')
    rating_kz=$(printf "%s\n" "${html[@]}" | grep "ratingValue" | sed -r "s/.+ratingValue\">//; s/<.+//")
    rating_count_users=$(printf "%s\n" "${html[@]}" | grep "ratingValue" | sed -r "s/.+content=\"//; s/\">.+//")
    users_download=$(printf "%s\n" "${html[@]}" | grep "Скачивают " | sed -r "s/.+Скачивают //; s/',.+//")
    users_downloaded=$(printf "%s\n" "${html[@]}" | grep "Скачали полностью" | sed -r "s/.+Скачали полностью\s+//g; s/,.+//")
    users_send=$(printf "%s\n" "${html[@]}" | grep "Раздают " | sed -r "s/.+Раздают //; s/',.+//")
    # Получаем hash торрент файла
    files_and_hash=$(files-and-hash "$id_kz")
    info_hash=$(echo "$files_and_hash" | sed -r "s/.+Инфо хеш: //; s/<.+//g")
    data=$(echo "$name \n\n")
    # Проверяем, что переменная не пустая (не отдавать строки с пустыми данными)
    if [ -n "$year" ]; then
        data+=$(echo "*Год выхода:* $year \n")
    fi
    if [[ $type_chat != "Channel" ]]; then
        data+=$(echo "*Жанр:* $genre \n")
    fi
    if [ -n "$region" ]; then
        data+=$(echo "*Страна:* $region \n")
    fi
    if [ -n "$rating_kp" ]; then
        data+=$(echo "*Рейтинг Кинопоиск:* $rating_kp \n")
    fi
    if [ -n "$rating_imdb" ]; then
        data+=$(echo "*Рейтинг IMDb:* $rating_imdb \n")
    fi
    if [ -n "$rating_kz" ]; then
        data+=$(echo "*Рейтинг Кинозал:* $rating_kz (*голосов:* $rating_count_users)\n")
    fi
    if [ -n "$video" ]; then
        data+=$(echo "*Качество:* $video \n")
    fi
    if [ -n "$lang" ]; then
        data+=$(echo "*Перевод:* $lang \n")
    fi
    # Отдаем аудио в боте и если переменная не пустая
    if [[ $type_chat != "Channel" && -n $audio ]]; then
        data+=$(echo "*Аудио:* $audio \n")
    fi
    if [ -n "$size" ]; then
        data+=$(echo "*Размер:* $size Гб \n")
    fi
    if [ -n "$length" ]; then
        data+=$(echo "*Продолжительность:* $length \n")
    fi
    # Если переменная "скачали полностью" пустая, обновляем на 0
    if [ -z "$users_downloaded" ]; then
        users_downloaded=0
    fi
    # Проверяем оставшиеся два параметра
    if [[ -n "$users_download" && -n "$users_send" ]]; then
        data+=$(echo "*Скачивают/Скачали/Раздают:* $users_download/$users_downloaded/$users_send \n")
    fi
    # Ссылки описания
    if [[ $type_chat == "Channel" ]]; then
        if [ -n "$link_kp" ]; then
            data+=$(echo "*Описание:* $link_kp \n")
        else
            data+=$(echo "*Описание:* $a \n")
        fi
    else
        if [ -n "$link_kp" ]; then
            data+=$(echo "*Кинопоиск*: $link_kp \n")
            kp_id=$(echo $link_kp | sed -r "s/.+\///g")
            data+=$(echo "*Kinobox*: https://kinomix.web.app/#$kp_id \n")
        fi
        if [ -n "$link_imdb" ]; then
            data+=$(echo "*IMDb*: $link_imdb \n")
        fi
        data+=$(echo "*Кинозал*: $a \n")
    fi
    data+=$(echo "*Кинозал id:* \`$id_kz\` \n")
    data+=$(echo "*Инфо хеш:* \`$info_hash\` \n")
    # data+=$(echo "*Магнит:* \`magnet:?xt=urn:btih:$info_hash\` \n")
    ### Хештеги по жарну
    if [[ $type_chat == "Channel" ]]; then
        data+=$(echo "\n$genre_hashtag_join_down")
    fi
    echo $data
}

# Получить id Кинопоиск по id Кинозал для Kinopoisk API
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

### Список ссылок из кнопок на похожие (рекомендуемые) торрент-раздачи
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
            keyboard+="[{\"text\":\"$encoded_kz_name\",\"callback_data\":\"/find_kinozal $kz_id\"}],"
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
            keyboard+="[{\"text\":\"$encoded_kz_name\",\"callback_data\":\"/find_kinozal $kz_id\"}],"
        done
    fi
    if [[ $KINOBOX_PLAYERS == "True" ]]; then
        ### ▶️▶️▶️ Kinobox api
        link_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+href="//; s/" target=.+//')
        link_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r "s/.+href=\"//g; s/\".+//g")
        if [ -n "$link_kp" ]; then
            players_id=$(echo $link_kp | sed -r "s/\/$//; s/.+\///g")
            players=$(kinobox-players "kinopoisk" "$players_id")
        elif [ -n "$link_imdb" ]; then
            players_id=$(echo $link_imdb | sed -r "s/\/$//; s/.+\///g")
            players=$(kinobox-players "imdb" "$players_id")
        fi
        keyboard+=$(echo $players | jq -c '[
            {
                "text": ("▶️ " + .provider),
                "url": .url
            }
        ]' | sed -r "s/]/],/g; s/&.+/\"}],/g")
    fi
    ### Main menu
    keyboard+="[{\"text\":\"🔎 Повторить последний поиск\",\"callback_data\":\"\/research\"}],"
    keyboard+="[{\"text\":\"👥 Список актеров\",\"callback_data\":\"\/kinozal_actors $id_find\"},"
    keyboard+="{\"text\":\"📄 Содержимое раздачи\",\"callback_data\":\"\/file_list\"}],"
    if [[ $type == "find" ]]; then
        keyboard+="[{\"text\":\"🟣 Описание Кинозал\",\"callback_data\":\"\/kinozal_description $id_find\"},"
    elif [[ $type == "description" ]]; then
        keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/find_kinozal $id_find\"},"
    fi
    keyboard+="{\"text\":\"🟡 Описание Кинопоиск\",\"callback_data\":\"/kinopoisk_movie $id_find\"}],"  
    keyboard+="[{\"text\":\"⬇️ Скачать торрент файл\",\"callback_data\":\"\/download_torrent $id_find "GLOBAL_NAME" \"},"
    keyboard+="{\"text\":\"🗑 Удалить торрент файл\",\"callback_data\":\"\/delete_torrent_file_$id_find\"}],"
    keyboard+="[{\"text\":\"⏩ Загрузить в qBittorrent\",\"callback_data\":\"\/download_video_$id_find\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"/status\"}],"
    keyboard+="[{\"text\":\"⬆️ Получить торрент файл\",\"callback_data\":\"\/send_torrent_file_$id_find\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
    echo $keyboard
}

### Функция фиксации глобального имени переменной (вызывается в /find_kinozal id)
function get-global-name {
    html=$1
    name=$(printf "%s\n" "${html[@]}" | grep "<title>" | sed -r 's/<title>//; s/ \/.+//' | sed -r 's/`|_|\"|&|;|quot//g')
    echo $name | sed -r "s/ /_/g"
}

### Switch функция для кодирования кириллицы в url формат
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

### Поиск в кинозал по названию фильма или сериала + обработка доп параметров
function get-search {
    search_name=$1
    search_year_test=false
    search_format_test=false
    id_url="https://kinozal.tv/browse.php?" # формируем url
    if [[ $search_name =~ ^[0-9]{4} ]]; then
        search_year_test=true # указываем, что используется фильтрация по году (для вывода в $data)
        search_year=$(echo $search_name | grep -Po "^[0-9]{4}") # забираем год
        search_name=$(echo $search_name | sed -r "s/$search_year //") # удаляем год из имени
        id_url+="&d=$search_year" # добавляем в url параметр год выхода
    fi
    if [[ $search_name =~ ^\(.+\) ]]; then
        search_format_test=true
        search_format_temp=$(echo $search_name | grep -Po "^\(.+\)" | sed -r "s/\(|\)//g") # забираем формат
        search_name=$(echo $search_name | sed -r "s/\($search_format_temp\)\s//") # обновляем имя
        # Проверяем пользовательский параметр (устанавливаем соответствующий параметр в url и обновляем пользовательский параметр для ответа)
        case $search_format_temp in
            "720")
                search_format="&v=3002"
                search_format_temp="HD (720)"
            ;;
            "1080")
                search_format="&v=3001"
                search_format_temp="Full HD (1080)"
            ;;
            "2160")
                search_format="&v=7"
                search_format_temp="4K (2160)"
            ;;
            *)
                search_format=false
                search_format_temp="Неправильно задан формат (доступны: 720, 1080 и 2160)."
            ;;
        esac
        # Обновляем url, если параметр передан верно
        if [[ $search_format != false ]]; then
            id_url+=$search_format
        fi
    fi
    # Повторяем проверку года выхода, если он был передан после формата
    if [[ $search_name =~ ^[0-9]{4} ]]; then
        search_year_test=true
        search_year=$(echo $search_name | grep -Po "^[0-9]{4}")
        search_name=$(echo $search_name | sed -r "s/$search_year //")
        id_url+="&d=$search_year"
    fi
    # Кодируем запрос в url строку (для кириллицы)
    search_name_encode=$(url-encode-ru "$search_name")
    search_name_replace_space=$(echo $search_name_encode | sed "s/ /+/g")
    echo "[INFO] $(date '+%H:%M:%S'): Url name: $search_name_replace_space" >> $path_log
    id_url+="&s=$search_name_replace_space"
    # Проверяем параметры для формирования тела ответа
    data="Поиск: *$search_name*\n"
    if [[ $search_year_test == true ]]; then
        data+="Год выхода: *$search_year*\n"
    else
        data+="Год выхода: *все года*\n"
    fi
    if [[ $search_format_test == true ]]; then
        data+="Выбор формата: *$search_format_temp*\n"
    else
        data+="Выбор формата: *все форматы*\n"
    fi
    # Делаем запрос и создаем кнопки
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
        keyboard+="[{\"text\":\"$encoded_name_year_quality\",\"callback_data\":\"/find_kinozal $id\"}],"
    done
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}],"
    keyboard+="[{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
    search_count=$(echo $(( $(echo $keyboard | jq . | grep "text" | wc -l) -4 )))
    echo "[INFO] $(date '+%H:%M:%S'): Search count link: $search_count" >> $path_log
    data+="Совпадений: *$search_count*"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### Получить информацию об актере и список его фильмографии из Кинозал
### Список актеров обрабатывается в конечной точке /kinozal_actors
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
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard"
    fi
}

################################### ▶️ ▶️ ▶️ Kinobox ▶️ ▶️ ▶️ #####################################
### Kinobox api: https://kinobox.tv/api

function kinobox-players {
    source_player=$1
    id_player=$2
    if [[ $source_player == "kinopoisk" ]]; then
        players=$(curl -s -X GET "https://kinobox.tv/api/players?kinopoisk=$id_player" -H "accept: application/json")
    elif [[ $source_player == "imdb" ]]; then
        players=$(curl -s -X GET "https://kinobox.tv/api/players?imdb=$id_player" -H "accept: application/json")
    fi
    echo $players | jq ".[] | select(.source != null and .iframeUrl != null) | {
        provider: .source,
        url: .iframeUrl
    }"
}
# kinobox-players kinopoisk 1142153
# kinobox-players imdb tt7587890

################################ 🟡 🟡 🟡 Kinopoisk API 🟡 🟡 🟡 ##################################
### API documentation: https://api.kinopoisk.dev/documentation

### Функции кодирования и декодирования кириллицы для передачи в параметр функции get-actor-kinopoisk

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

### Получить информацию о выбранном актере из Кинопоиск API
function get-actor-kinopoisk {
    actor_name=$1
    actor_encode=$(percent-encode $actor_name)
    curl -s -X 'GET' \
        "https://api.kinopoisk.dev/v1.4/person/search?page=1&limit=1&query=$actor_encode" \
        -H "accept: application/json" \
        -H "X-API-KEY: $KINOPOISK_TOKEN" | jq .
}

### Описание Кинопоиск по id + трейлеры + список названий Сиквелов и Приквелов (свойство movie_similar) для передачи в поиск Кинозал (/search) 🟡
### Описание Кинозал обрабатывается в конечной точке /kinozal_description
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
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/find_kinozal $GLOBAL_ID_FIND\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard"
    fi
}

##################################### 🔵 Telegram menu 📚📝📄 #######################################

### /torrent_files
### 🗂 Список скаченных торрент файлов на сервере
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
        keyboard+="[{\"text\":\"$torrent_name\",\"callback_data\":\"/find_kinozal $torrent_id\"}],"
    done
    keyboard+="[{\"text\":\"⬆️ Получить последний торрент файл\",\"callback_data\":\"\/send_last_torrent_file\"}],"
    keyboard+="[{\"text\":\"⬆️ Получить все торрент файлы\",\"callback_data\":\"\/send_all_torrent_files\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🔲 Transmission\",\"callback_data\":\"\/trans_status\"}],"
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
    #keyboard+="[{\"text\":\"⚙️ Windows API\",\"callback_data\":\"\/win_state\"}],"
    keyboard+="{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$TEXT" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$TEXT" "$CHAT" "$keyboard"
    fi
}

### State:
# 📶 stalledDL           Торрент скачивается, но соединение не установлено
# 📶 stalledUP           Торрент загружается, но соединение не установлено
# ⏸ pausedDL            Торрент приостановлен и загрузка НЕ ​​завершена
# ⏸🆗 pausedUP         Торрент приостановлен и загрузка завершена
# ⬇️ downloading         Торрент скачивается и данные передаются
# ⬆️ uploading           Торрент загружается и данные передаются
# ⏯ queuedUP            Очередь включена, и торрент поставлен в очередь на загрузку
# ⏯ queuedDL            Очередь включена, и торрент поставлен в очередь на загрузку
# ⬇️🆙forcedUP          Торрент принудительно загружается и игнорирует ограничение очереди
# ⬇️🆙forcedDL          Торрент принудительно загружается, чтобы игнорировать ограничение очереди
# 🧲 metaDL              Торрент только начал загрузку и получает метаданные
# ♻️ checkingUP          Торрент завершил загрузку и проходит проверку
# ♻️ checkingDL          То же, что и проверка UP, но загрузка торрента НЕ завершена
# ♻️ checkingResumeData  Проверка данных возобновления при запуске qBt
# ⚠️ allocating          Торрент выделяет место на диске для скачивания
# ⚠️ moving              Торрент переезжает в другое место
# ⚠️ missingFiles        Файлы данных торрента отсутствуют
# ⚠️ error               Произошла ошибка, относится к приостановленным торрентам
# ⚠️ unknown             Неизвестный статус

### /status
### 🟢 Список торрент раздач добавленных в qBittorrent
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
        elif [[ $qb_status == "pausedDL" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⏸ /")
        elif [[ $qb_status =~ "pausedUP" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⏸🆗 /")
        elif [[ $qb_status =~ "download" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⬇️ /")
        elif [[ $qb_status =~ "upload" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⬆️ /")
        elif [[ $qb_status =~ "queued" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⏯ /")
        elif [[ $qb_status =~ "forced" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/⬇️🆙 /")
        elif [[ $qb_status =~ "metaDL" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/🧲 /")
        elif [[ $qb_status =~ "checking" ]]; then
            qb_name=$(echo $qb_name | sed -r "s/^/♻️ /")
        else
            qb_name=$(echo $qb_name | sed -r "s/^/⚠️ /")
        fi
        keyboard+="[{\"text\":\"$qb_name\",\"callback_data\":\"/info $qb_hash\"}],"
    done
    app_name="qbittorrent"
    keyboard+="[{\"text\":\"🔄 Обновить статус\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"📶 Переключить лимит\",\"callback_data\":\"\/torrent_limit\"},"
    keyboard+="{\"text\":\"🔲 Transmission\",\"callback_data\":\"\/trans_status\"}],"
    #keyboard+="{\"text\":\"🟢 Управление\",\"callback_data\":\"\/app_status $app_name\"}],"
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
    #keyboard+="[{\"text\":\"⚙️ Windows API\",\"callback_data\":\"\/win_state\"},"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$TEXT" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$TEXT" "$CHAT" "$keyboard"
    fi
}

### 🟢 Действие для выбранного торрента (ответ на /info в qBittorrent) и обновление информации для конечных точек /pause и /resume
function menu-info {
    qb_hash=$1
    qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
    qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
    echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /info for $qb_name ($qb_hash)" >> $path_log
    qb_status=$(echo $qb_state | jq -r ".state")
    qb_progress=$(echo $qb_state | jq -r ".progress" | sed -r "s/\..+ %/ %/")
    if [[ $qb_status == "completed" || $qb_progress == "100 %" ]]; then
        qb_status_emoji="🆗"
    elif [[ $qb_status =~ "stalled" ]]; then
        qb_status_emoji="📶"
    elif [[ $qb_status == "pausedDL" ]]; then
        qb_status_emoji="⏸"
    elif [[ $qb_status =~ "pausedUP" ]]; then
        qb_status_emoji="⏸🆗"
    elif [[ $qb_status =~ "download" ]]; then
        qb_status_emoji="⬇️"
    elif [[ $qb_status =~ "upload" ]]; then
        qb_status_emoji="⬆️"
    elif [[ $qb_status =~ "queued" ]]; then
        qb_status_emoji="⏯"
    elif [[ $qb_status =~ "forced" ]]; then
        qb_status_emoji="⬇️🆙"
    elif [[ $qb_status =~ "metaDL" ]]; then
        qb_status_emoji="🧲"
    elif [[ $qb_status =~ "checking" ]]; then
        qb_status_emoji="♻️"
    else
        qb_status_emoji="⚠️"
    fi
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
    ### Получаем дополнительную информацию из второй функции
    qb_prop=$(qbittorrent-properties $qb_hash)
    qb_prop_comment=$(echo $qb_prop | jq -r ".comment")
    kinozal_id=$(echo $qb_prop_comment | sed -r "s/.+id=//")
    qb_prop_seeds=$(echo $qb_prop | jq -r ".seeds")
    qb_prop_seeds_total=$(echo $qb_prop | jq -r ".seeds_total")
    qb_prop_peers=$(echo $qb_prop | jq -r ".peers")
    qb_prop_peers_total=$(echo $qb_prop | jq -r ".peers_total")
    qb_prop_download_speed_avg=$(echo $qb_prop | jq -r ".download_speed_avg")
    qb_name=$(echo $qb_name | sed -r "s/_/ /g")
    data=$(echo "*Название:* $qb_name \n")
    data+=$(echo "*Статус загрузки:* $qb_status_emoji ($qb_status) \n")
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
    data+=$(echo "*Обновлено:* $(date '+%H:%M:%S')\n")
    data+=$(echo "*Описание:* $qb_prop_comment \n")
    data+=$(echo "*Инфо хеш:* \`$qb_hash\`")
    #data+=$(echo "*Путь:* $qb_path")
    # Удалить расширение для поиска в plex (/find)
    qb_name_replace=$(echo $qb_name | sed -r "s/\.mkv$|\.avi$|\.mp4$//g")
    keyboard="{
        \"inline_keyboard\":[
            [{\"text\":\"🔄 Обновить\",\"callback_data\":\"\/info $qb_hash\"},
            {\"text\":\"📖 Список файлов\",\"callback_data\":\"/torrent_content $qb_hash\"}],
            [{\"text\":\"⏸ Пауза\",\"callback_data\":\"\/pause $qb_hash\"},
            {\"text\":\"▶️ Возобновить\",\"callback_data\":\"\/resume $qb_hash\"}],
            [{\"text\":\"⬆️ Получить торрент\",\"callback_data\":\"\/get_torrent $qb_hash\"},
            {\"text\":\"♻️ Проверить\",\"callback_data\":\"\/torrent_recheck $qb_hash\"}],
            [{\"text\":\"🗑 Удалить торрент\",\"callback_data\":\"\/delete_torrent $qb_hash\"},
            {\"text\":\"❌ Удалить данные\",\"callback_data\":\"\/delete_video $qb_hash\"}],
            [{\"text\":\"🔎 Кинозал\",\"callback_data\":\"/find_kinozal $kinozal_id\"},
            {\"text\":\"🟠 Plex 🔎 \",\"callback_data\":\"\/find $qb_name_replace\"}],
            [{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/status\"},
            {\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]
        ]
    }"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### 🟢 Меню для /torrent_content и возврат из /file_torrent
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
        # Получаем статус прогресса
        qb_file_progress=$(echo $qb_files | jq ".[] | select(.name == \"$qb_file_name\").progress")
        if [[ $qb_file_progress == 1 ]]; then
            qb_file_progress_stats="✅"
        else
            qb_file_progress_stats="❎"
        fi
        # Получаем статус приоритета
        qb_file_priority=$(echo $qb_files | jq ".[] | select(.name == \"$qb_file_name\").priority")
        if [[ $qb_file_priority == 0 ]]; then
            qb_file_priority_stats="⏸"
        elif [[ $qb_file_priority == 1 ]]; then
            qb_file_priority_stats="▶️"
        elif [[ $qb_file_priority == 6 ]]; then
            qb_file_priority_stats="🔼"
        elif [[ $qb_file_priority == 7 ]]; then
            qb_file_priority_stats="⏫"
        fi
        qb_file_name_replace=$(echo $qb_file_name | sed -r "s/.+\///")
        keyboard+="[{\"text\":\"$qb_file_progress_stats $qb_file_priority_stats $qb_file_name_replace\",\"callback_data\":\"/file_torrent $qb_file_index\"}],"
    done
    keyboard+="[{\"text\":\"⏸ Пропустить все\",\"callback_data\":\"\/skip_all_files\"},"
    keyboard+="{\"text\":\"▶️ Возобновить все\",\"callback_data\":\"\/normal_all_files\"}],"
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/info $global_hash\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$TEXT" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$TEXT" "$CHAT" "$keyboard"
    fi
}

### 🟢 Меню для /file_torrent и обновление списка файлов используя /torrent_content
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
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$encoded_data" "$CHAT" "$keyboard"
    fi
}

### 🟠 Меню Plex выбранной секции для /plex_status_key и обновления /plex_sync_key
function menu-plex-status {
    command=$1
    CHAT=$2
    section_key=$(echo $command | sed "s/\/plex_status_//")
    # Set global vardiable for /find
    declare -g global_section_key=$section_key
    plex_sections=$(plex-sections | jq ".| select(.key == \"$section_key\")")
    plex_name=$(echo $plex_sections | jq -r .name)
    echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /plex_status for $plex_name (key: $section_key)" >> $path_log
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
    keyboard+="[{\"text\":\"🆕 Последние добавления\",\"callback_data\":\"\/plex_last_added\"}],"
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/plex_info\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
    keyboard+="[{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"},"
    keyboard+="{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### 🟠 Меню поиска контента в Plex (/find)
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
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$encoded_data" "$CHAT" "$keyboard"
    fi
}

###############################################################################
################################## Debug end ##################################
###############################################################################

################################## 🔎 🔎 🔎 Everything 🔎 🔎 🔎 ###################################
### HTTP API documentation: https://www.voidtools.com/support/everything/http

EVERYTHING_ADDR="http://192.168.3.100:9999"
EVERYTHING_USER="every"
EVERYTHING_PASS="thing"

function everything-search {
    every_search=$1
    param="path_column=1"
    param+="&size_column=1"
    param+="&date_modified_column=1"
    param+="&json=1"
    curl -s "$EVERYTHING_ADDR/?search=$every_search&$param" \
        -u "$EVERYTHING_USER:$EVERYTHING_PASS" \
        -H "Content-Type: application/json" | jq .
}

# everything-search Jurassic.World.Chaos.Theory.S01E01.WEBDL.1080p.RGzsRutracker.mkv
# everything-search 2fdb28133eee0e3842ed855a08c07f35e482eedc.torrent

### Скачивает первый [0] найденный файл в фоновом потоке (или отфильтровать вывод по директории)
function everything-download {
    every_search=$1
    path=$path
    every_result=$(everything-search $every_search | jq .results[0])
    every_path=$(echo $every_result | jq -r .path)
    every_name=$(echo $every_result | jq -r .name)
    every_path_down="$every_path\\$every_name"
    curl "$EVERYTHING_ADDR/$every_path_down" \
        -u "$EVERYTHING_USER:$EVERYTHING_PASS" \
        -o "$path/$every_name" &> "$EVERYTHING_LOCAL_PATH/everything_progress.txt" &
}

# everything-download Jurassic.World.Chaos.Theory.S01E01.WEBDL.1080p.RGzsRutracker.mkv

### Проверяем статус загрузки, по завершению отправляем файл в Telegram и удаляем файл
### ⚠️ Боты могут отправлять файлы любого типа размером до 50 МБ через метод sendDocument ⚠️
function everything-send {
    every_search=$1
    every_result=$(everything-search $every_search | jq .results[0])
    every_name=$(echo $every_result | jq -r .name)
    while :
        do
        everything_progress=$(cat -v kinozal-torrent/everything_progress.txt | tail -n 1| sed -r "s/.+\^M//g" | awk '{print $1}') # awk '{print $1"% ("$4"/"$2") "$12"/s"}'
        if [[ $everything_progress == 100 ]]; then
            break
        fi
    done &
    sleep $TIMEOUT_SEC_UPDATE_STATUS
    send-file "$path/$every_name"
    sleep $TIMEOUT_SEC_UPDATE_STATUS
    # rm "$path/$every_name"
}

# everything-send Jurassic.World.Chaos.Theory.S01E01.WEBDL.1080p.RGzsRutracker.mkv

#################################### ⚙️ ⚙️ ⚙️ WinAPI ⚙️ ⚙️ ⚙️ #####################################
### REST API server based on .NET HttpListener and PowerShell Core
### Source: https://github.com/Lifailon/WinAPI (© Lifailon)

WIN_API_ADDR="http://192.168.3.100:8443"
WIN_API_USER="rest"
WIN_API_PASS="api"

function win-state {
    hardware=$(curl -s -X GET -u $WIN_API_USER:$WIN_API_PASS $WIN_API_ADDR/api/hardware)
    keyboard='{"inline_keyboard":['
    if [[ -z "$hardware" ]]; then
        data="Данные не получены (сервер неактивен)"
    else
        performance=$(curl -s -X GET -u $WIN_API_USER:$WIN_API_PASS $WIN_API_ADDR/api/performance)
        CPU=$(echo $hardware | jq -r .CPU)
        proc_count=$(echo $hardware | jq -r .ProcessCount)
        threads_count=$(echo $hardware | jq -r .ThreadsCount)
        handles_count=$(echo $hardware | jq -r .HandlesCount)
        mem_all=$(echo $hardware | jq -r .MemoryAll)
        mem_use=$(echo $hardware | jq -r .MemoryUse)
        mem_use_proc=$(echo $hardware | jq -r .MemoryUseProc)
        net_speed=$(echo $performance | jq -r .AdapterSpeed)
        disk_time=$(echo $performance | jq -r .DiskTotalTime)
        data=$(echo "*Процессор:* $CPU \n")
        data+=$(echo "*Диск:* $disk_time \n")
        data+=$(echo "*Сеть:* $net_speed \n")
        data+=$(echo "*Память:* $mem_use/$mem_all ($mem_use_proc) \n")
        data+=$(echo "*Количество процессов:* $proc_count \n")
        data+=$(echo "*Количество потоков:* $threads_count \n")
        data+=$(echo "*Количество дескрипторов:* $handles_count \n\n")
        #data+=$(echo "*Логические диски:* \n")
        disk=$(curl -s -X GET -u $WIN_API_USER:$WIN_API_PASS $WIN_API_ADDR/api/disk/logical)
        disk_array=$(echo $disk | jq -r .[].Logical_Disk)
        IFS=$'\n'
        for a in $disk_array; do
            select_disk=$(echo $disk | jq --arg a "$a" '.[] | select(.Logical_Disk == $a)')
            Disk_Num=$(echo $select_disk | jq -r .Logical_Disk)
            Disk_Name=$(echo $select_disk | jq -r .VolumeName)
            Disk_Size=$(echo $select_disk | jq -r .AllSize)
            Disk_FreeSize=$(echo $select_disk | jq -r .FreeSize)
            Disk_FreeSizeProc=$(echo $select_disk | jq -r .Free)
            #data+=$(echo "*$Disk_Num ($Disk_Name):* $Disk_FreeSize/$Disk_Size ($Disk_FreeSizeProc) \n")
            keyboard+="[{\"text\":\"$Disk_Num ($Disk_Name): $Disk_FreeSize/$Disk_Size ($Disk_FreeSizeProc)\",\"callback_data\":\"\/win_files $Disk_Num\"}],"
        done
    fi
    keyboard+="[{\"text\":\"🔄 Обновить\",\"callback_data\":\"\/win_state\"},"
    keyboard+="{\"text\":\"🔧 Процессы\",\"callback_data\":\"\/win_process\"}],"
    #keyboard+="[{\"text\":\"🔨 Службы\",\"callback_data\":\"\/win_service\"}]," # win-service
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

# + Обрезать имя и изменить select
# + Получить описание текущий директории

### 📄 /api/files
function win-files {
    win_path="$1"
    if [[ "$win_path" == [A-Za-z]: ]]; then
        data=$(echo "Cписок файлов на диске *$win_path* \n")
        declare -g global_win_path=$win_path
    elif [[ "$win_path" == "global_back_path" ]]; then
        # Передаем в текущую директорию старый путь
        win_path=$global_win_path_back
        declare -g global_win_path=$win_path
        # Обновляем новый путь назад
        declare -g global_win_path_back=$(dirname $global_win_path_back)
    else
        data=$(echo "Содержимое директории *$win_path*: \n")
        # Обновляем глобальную переменную обратного пути
        # Передаем старый путь для пути назад
        declare -g global_win_path_back="$global_win_path"
        # Обновляем глобальную переменную нового пути
        # К старому пути добавляем название выбранной директории
        declare -g global_win_path="$global_win_path/$win_path"
        win_path=$global_win_path
    fi
    echo "[INFO] $(date '+%H:%M:%S'): Current new path: $global_win_path" >> $path_log
    echo "[INFO] $(date '+%H:%M:%S'): Back path: $global_win_path_back" >> $path_log
    win_files=$(curl -s -X GET -u $WIN_API_USER:$WIN_API_PASS $WIN_API_ADDR/api/files -H "Path: $win_path")
    win_files_array=$(echo $win_files | jq -r .[].Name)
    keyboard='{"inline_keyboard":['
    IFS=$'\n'
    for a in $win_files_array; do
        select_file=$(echo $win_files | jq --arg a "$a" '.[] | select(.Name == $a)')
        #Full_Path=$(echo $select_file | jq -r .FullName)
        #Full_Path=$(echo $Full_Path | sed -r 's/\\|\\\\/\//g')
        Path_Size=$(echo $select_file | jq -r .Size)
        Path_Type=$(echo $select_file | jq -r .Type)
        if [[ $Path_Type == "Directory" ]]; then
            #keyboard+="[{\"text\":\"🗂 $a ($Path_Size)\",\"callback_data\":\"\/win_files $a\"}],"
            keyboard+="[{\"text\":\"🗂 $a\",\"callback_data\":\"\/win_files $a\"}],"
        else
            #keyboard+="[{\"text\":\"📄 $a ($Path_Size)\",\"callback_data\":\"\/win_files $a\"}],"
            keyboard+="[{\"text\":\"📄 $a\",\"callback_data\":\"\/win_files $a\"}],"
        fi
    done
    if [[ "$win_path" == [A-Za-z]: ]]; then
        keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/win_state\"},"
    else
        keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/win_files global_back_path\"},"
    fi
    keyboard+="{\"text\":\"⚙️ Windows API\",\"callback_data\":\"\/win_state\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### 🔧 /api/process
function win-process {
    process=$(curl -s -X GET -u $WIN_API_USER:$WIN_API_PASS $WIN_API_ADDR/api/process)
    process_array=$(echo $process | jq -r .[].ProcessName)
    # Удалить дубликаты
    process_array_unique=$(echo "$process_array" | awk '!seen[$0]++')
    IFS=$'\n'
    keyboard='{"inline_keyboard":['
    for a in $process_array_unique; do
        # Заменить в имени пробелы на нижние подчеркивания
        a_no_space=$(echo $a | sed "s/ /_/g")
        keyboard+="[{\"text\":\"$a\",\"callback_data\":\"\/app_status $a_no_space\"}],"
    done
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/win_state\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}]]}"
    data="🔧 Список процессов:"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### 🔧 /api/process/process_name
function app-status-response {
    app_name=$1
    data_json=$(curl -s -X GET -u $WIN_API_USER:$WIN_API_PASS $WIN_API_ADDR/api/process/$app_name)
    BadRequest="Bad Request"
    if [[ $data_json != *$BadRequest* ]]; then
        # Если процессов несколько, забрать только первый процесс
        app_count=$(echo $data_json | jq '. | length')
        if [ "$app_count" -gt 13 ] || [ "$app_count" -lt 13 ]; then
            data_json=$(echo $data_json | jq .[0])
        fi
        ProcessName=$(echo $data_json | jq -r .ProcessName)
        TotalProcTime=$(echo $data_json | jq -r .TotalProcTime)
        UserProcTime=$(echo $data_json | jq -r .UserProcTime)
        PrivilegedProcTime=$(echo $data_json | jq -r .PrivilegedProcTime)
        WorkingSet=$(echo $data_json | jq -r .WorkingSet)
        PeakWorkingSet=$(echo $data_json | jq -r .PeakWorkingSet)
        PageMemory=$(echo $data_json | jq -r .PageMemory)
        VirtualMemory=$(echo $data_json | jq -r .VirtualMemory)
        PrivateMemory=$(echo $data_json | jq -r .PrivateMemory)
        RunTime=$(echo $data_json | jq -r .RunTime | sed "s/\./ дня /")
        Threads=$(echo $data_json | jq -r .Threads)
        Handles=$(echo $data_json | jq -r .Handles)
        ProcPath=$(echo $data_json | jq -r .Path)
        data=$(echo "*Приложение:* $ProcessName \n")
        data+=$(echo "*Время работы:* $RunTime \n")
        data+=$(echo "*Процессорное время (all):* $TotalProcTime \n")
        data+=$(echo "*Процессорное время (user):* $UserProcTime \n")
        data+=$(echo "*Процессорное время (privileged):* $PrivilegedProcTime \n")
        data+=$(echo "*Потребление памяти (Working Set/Peak):* $WorkingSet / $PeakWorkingSet \n")
        data+=$(echo "*Потоки/Дескрипторы:* $Threads/$Handles \n\n")
    else
        data=$(echo "☹️ *Приложение $app_name не запущено* \n")
    fi
    keyboard='{"inline_keyboard":['
    keyboard+="[{\"text\":\"▶️ Запустить\",\"callback_data\":\"\/app_start $app_name\"},"
    keyboard+="{\"text\":\"⏹ Остановить\",\"callback_data\":\"\/app_stop $app_name\"}],"
    keyboard+="[{\"text\":\"⚙️ Windows API\",\"callback_data\":\"\/win_state\"},"
    keyboard+="{\"text\":\"🔧 Процессы\",\"callback_data\":\"\/win_process\"}],"
    keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
    keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

### ▶️ Start Process
function app-start {
    proc_name=$1
    curl -s -X POST -u $WIN_API_USER:$WIN_API_PASS \
        --data '' $WIN_API_ADDR/api/process/$proc_name \
        -H "Status: Start"
}

### ▶️🟠 Start Plex
function app-start-plex {
    proc_name=$1
    curl -s -X POST -u $WIN_API_USER:$WIN_API_PASS \
        --data '' $WIN_API_ADDR/api/process/$proc_name \
        -H "Status: Start" \
        -H "Path: C:\Program Files\Plex\Plex Media Server\Plex Media Server.exe"
}

### ⏹ Stop Process
function app-stop {
    proc_name=$1
    curl -s -X POST -u $WIN_API_USER:$WIN_API_PASS \
        --data '' $WIN_API_ADDR/api/process/$proc_name \
        -H "Status: Stop"
}

### 🔨 /api/service ⚠️ Слишком большой объем данных для отправки ⚠️
function win-service {
    service=$(curl -s -X GET -u $WIN_API_USER:$WIN_API_PASS $WIN_API_ADDR/api/service)
    service_array=$(echo $service | jq -r .[].Name)
    IFS=$'\n'
    keyboard='{"inline_keyboard":['
    data=$(echo "🔨 Список служб: \n\n")
    for a in $service_array; do
        # Заменить нижние подчеркивания на пробелы
        a_space=$(echo $a | sed "s/_/ /g")
        select_service=$(echo $service | jq ".[] | select(.Name == \"$a\")")
        #service_status=$(echo $select_service | jq -r ".Status")
        #keyboard+="[{\"text\":\"$a_space\",\"callback_data\":\"\/service_status $a\"}],"
        data+=$(echo "$a_space \n")
        #data+=$(echo "$a_space - $service_status \n")
    done
    keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/win_state\"},"
    keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}],"
    keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"},"
    keyboard+="{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"}]]}"
    if [[ $message_id_temp != "null" ]]; then
        edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
    else
        send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
    fi
}

###############################################################################
################################# Thread 1️⃣ ##################################
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
        echo "[OK]   $(date '+%H:%M:%S'): >>> Request command from user: $user ($CHAT)" >> $path_log
        ### Request: /download_torrent id name ⬇️
        if [[ $command == /download_torrent* ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /download_torrent" >> $path_log
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
                        [{\"text\":\"⏩ Загрузить в qBittorrent\",\"callback_data\":\"\/download_video_$down_id\"}],
                        [{\"text\":\"⬆️ Получить торрент файл\",\"callback_data\":\"\/send_torrent_file_$down_id\"}],
                        [{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"},
                        {\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]
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
        ### Request: /profile 🌐🌐🌐
        elif [[ $command == /profile ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /profile" >> $path_log
            count-torrent
        ### Request: /torrent_files 🗂📚🗂
        elif [[ $command == /torrent_files ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /torrent_files" >> $path_log
            menu-files "🗂 Список загруженных торрент файлов:" $CHAT
        ### Request: /delete_torrent_file_id 🗑 🗂 📚 🗂 🗑
        elif [[ $command == /delete_torrent_file_* ]]; then
            filename_id=$(echo $command | sed "s/\/delete_torrent_file_//")
            filename=$(ls -l $path | grep -E "*\.torrent" | grep "$filename_id" | awk '{print $9}')
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /delete_torrent_file on $filename ($filename_id)" >> $path_log
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
        ### Request: /find_kinozal <id> 🔎🔎🔎
        elif [[ $command == /find_kinozal* ]]; then
            id_find=$(echo $command | sed "s/\/find_kinozal //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /find_kinozal for $id_find" >> $path_log
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
                # Изменить глобальную переменную для конечной точки /download_torrent через меню (функция get-links)
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
                        {\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]
                    ]
                }"
                if [[ $message_id_temp != "null" ]]; then
                    edit-keyboard "Торрент файл (id: $id_find) не найден в базе Кинозала (возможна проблема соединения)." "$CHAT" "$keyboard" "$message_id_temp"
                else
                    send-keyboard "Торрент файл (id: $id_find) не найден в базе Кинозала (возможна проблема соединения)." "$CHAT" "$keyboard"
                fi
            fi
        ### Request: /kinozal_description 🟣🟣🟣
        elif [[ $command == /kinozal_description* ]]; then
            id_find=$(echo $command | sed "s/\/kinozal_description //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /kinozal_description for $id_find" >> $path_log
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
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /kinozal_actors for $id_find" >> $path_log
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
            keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/find_kinozal $id_find\"},"
            keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
            keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
            keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
            data=$(echo "👥 *Список актеров:*")
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$data" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$data" "$CHAT" "$keyboard"
            fi
        ### Request: /search 🔎🟣
        elif [[ $command == /search* ]]; then
            search_name=$(echo $command | sed "s/\/search //")
            # Update global variables for research
            declare -g GLOBAL_SEARCH_NAME=$search_name
            declare -g GLOBAL_SEARCH_TYPE="Film or Serial"
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /search for $search_name" >> $path_log
            get-search "$search_name"
        ### Request: /actor 👥
        elif [[ $command == /actor* ]]; then
            actor_name=$(echo $command | sed "s/\/actor //")
            # Update global variables for research
            declare -g GLOBAL_SEARCH_NAME=$actor_name
            declare -g GLOBAL_SEARCH_TYPE="Actor"
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /actor for $actor_name" >> $path_log
            get-actor "$actor_name"
        ### Request: /research 🔎⬅️🔄🔎
        elif [[ $command == /research ]]; then
            search_name=$(echo $command | sed "s/\/search //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /research for $GLOBAL_SEARCH_NAME (type: $GLOBAL_SEARCH_TYPE)" >> $path_log
            if  [[ $GLOBAL_SEARCH_TYPE == "Actor" ]]; then
                get-actor "$GLOBAL_SEARCH_NAME"
            else
                get-search "$GLOBAL_SEARCH_NAME"
            fi
        ### Request: /send_torrent_file ⬆️
        elif [[ $command == /send_torrent_file_* ]]; then
            id_send_file=$(echo $command | sed "s/\/send_torrent_file_//")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /send_torrent_file for $id_send_file" >> $path_log
            send_file=$(ls $path | grep $id_send_file)
            send_file_path=$(echo "$path/$send_file")
            echo "[INFO] $(date '+%H:%M:%S'): File path: $send_file_path" >> $path_log
            send-file "$send_file_path"
        ### Request: /send_last_torrent_file ⬆️⬆️⬆️
        elif [[ $command == /send_last_torrent_file ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /send_last_torrent_file" >> $path_log
            send_file=$(ls -t "$path" | grep "\.torrent" | head -n 1)
            send_file_path=$(echo "$path/$send_file")
            echo "[INFO] $(date '+%H:%M:%S'): Send file: $send_file_path" >> $path_log
            send-file "$send_file_path"
        ### Request: /send_all_torrent_files ⬆️⬆️⬆️⬆️⬆️⬆️
        elif [[ $command == /send_all_torrent_files ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /send_all_torrent_files" >> $path_log
            send_file_array=($(ls $path | grep "\.torrent"))
            for send_file in ${send_file_array[@]}; do
                send_file_path=$(echo "$path/$send_file")
                echo "[INFO] $(date '+%H:%M:%S'): Send file: $send_file_path" >> $path_log
                send-file "$send_file_path"
            done
        ###### 🟡 🟡 🟡 Kinopoisk 🟡 🟡 🟡
        ### Request: /kinopoisk_movie 🟡
        elif [[ $command == /kinopoisk_movie* ]]; then
            id_kz_search=$(echo $command | sed "s/\/kinopoisk_movie //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /kinopoisk_movie" >> $path_log
            echo "[OK]   $(date '+%H:%M:%S'): Search on id Kinozal: $id_kz_search" >> $path_log
            id_kp=$(get-kp-id "$id_kz_search")
            echo "[OK]   $(date '+%H:%M:%S'): Search on id Kinopoisk: $id_kp" >> $path_log
            get-movie-kinopoisk-id "$id_kp"
        ### Request: /file_list 📖📄🟣
        elif [[ $command == /file_list ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /file_list" >> $path_log
            files_and_hash=$(files-and-hash "$GLOBAL_ID_FIND")
            file_list=$(echo "$files_and_hash" | grep -oP '(?<=<li>)[^<]+(?=<i>)')
            file_sizes=$(echo "$files_and_hash" | grep -oP '(?<=<i>)[^<]+(?=</i>)' | sed -r "s/\s\(.+//g; s/^/(/; s/$/)/")
            ### paste вместо цикла for
            data=$(paste -d '' <(echo "$file_list") <(echo "$file_sizes"))
            ### echo "$data"
            encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
            keyboard='{"inline_keyboard":['
            keyboard+="[{\"text\":\"⬅️ Назад\",\"callback_data\":\"\/find_kinozal $GLOBAL_ID_FIND\"},"
            keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}],"
            keyboard+="[{\"text\":\"🌐 Профиль Кинозал\",\"callback_data\":\"\/profile\"},"
            keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$(echo -e $encoded_data)" "$CHAT" "$keyboard"
            fi
        ###### 🟢 🟢 🟢 qBittorrent 🟢 🟢 🟢
        ### Request: /status 🟢🐸
        elif [[ $command == /status ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /status" >> $path_log
            qb_check=$(qbittorrent-test)
            if [[ $qb_check == 1 ]]; then
                send-telegram "Ошибка авторизации на сервере qBittorrent" "$CHAT"
            elif [[ $qb_check == 2 ]]; then
                data=$(echo "☹️ *Приложение qBittorrent не запущено* \n")
                keyboard='{"inline_keyboard":['
                keyboard+="[{\"text\":\"▶️ Запустить\",\"callback_data\":\"\/app_start qBittorrent\"},"
                keyboard+="{\"text\":\"⏹ Остановить\",\"callback_data\":\"\/app_stop qBittorrent\"}],"
                keyboard+="[{\"text\":\"🟠 Plex\",\"callback_data\":\"\/plex_info\"},"
                keyboard+="{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/status\"}]]}"
                if [[ $message_id_temp != "null" ]]; then
                    edit-keyboard "$(echo -e $data)" "$CHAT" "$keyboard" "$message_id_temp"
                else
                    send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
                fi
            elif [[ $qb_check == 3 ]]; then
                send-telegram "Сервер qBittorrent недоступен" "$CHAT"
            else
                menu-status "$(qbittorrent-data)" "$CHAT"
            fi
        ### Request: /info hash 🔄🔄🔄
        elif [[ $command == /info* ]]; then
            qb_hash=$(echo $command | sed "s/\/info //")
            menu-info $qb_hash
        ### Request: /torrent_content hash 📖📖📖
        elif [[ $command == /torrent_content* ]]; then
            qb_hash=$(echo $command | sed "s/\/torrent_content //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /torrent_content for torrent hash: $qb_hash" >> $path_log
            menu-torrent-content "$qb_hash"
        ### Request: /file_torrent index
        elif [[ $command == /file_torrent* ]]; then
            file_index=$(echo $command | sed "s/\/file_torrent //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /file_torrent for torrent file index: $file_index" >> $path_log
            menu-torrent-file "$file_index"
        ### Request: /torrent_priority num_priority ⏸▶️🔼⏫
        elif [[ $command == /torrent_priority* ]]; then
            num_priority=$(echo $command | sed "s/\/torrent_priority //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /torrent_priority: $num_priority" >> $path_log
            qbittorrent-priority $global_hash $global_file_index $num_priority
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            menu-torrent-file "$global_file_index"
        ### Request: /skip_all_files ⏸⏸⏸ (добавляем в /torrent_content после обновления global_hash)
        elif [[ $command == /skip_all_files ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /skip_all_files for $global_hash" >> $path_log
            # Забираем индексы всех файлов из последнего выбранного глобального хеш торрента
            files_array=$(qbittorrent-files $global_hash)
            files_index_array=$(echo $files_array | jq -r .[].index)
            # Логируем количество файлов в раздаче
            files_index_array_count=$(echo $files_index_array | wc -w)
            echo "[OK]   $(date '+%H:%M:%S'): Count files for skip: $files_index_array_count" >> $path_log
            for files_index in $files_index_array; do
                # Поочередно изменяем приоритет всех файлов на 0 (не загружать)
                qbittorrent-priority "$global_hash" "$files_index" "0"
            done
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            menu-torrent-content $global_hash
        ### Request: /normal_all_files ▶️▶️▶️
        elif [[ $command == /normal_all_files ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /normal_all_files for $global_hash" >> $path_log
            files_array=$(qbittorrent-files $global_hash)
            files_index_array=$(echo $files_array | jq -r .[].index)
            files_index_array_count=$(echo $files_index_array | wc -w)
            echo "[OK]   $(date '+%H:%M:%S'): Count files for skip: $files_index_array_count" >> $path_log
            for files_index in $files_index_array; do
                qbittorrent-priority "$global_hash" "$files_index" "1"
            done
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            menu-torrent-content $global_hash
        ### Request: /download_video_id ⏩⏩⏩
        elif [[ $command == /download_video_* ]]; then
            id_down=$(echo $command | sed "s/\/download_video_//")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /download_video for $id_down" >> $path_log
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
        ### Request: /pause hash ⏸⏸⏸
        elif [[ $command == /pause* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/pause //")
            qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
            qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /pause for $qb_name ($qb_hash)" >> $path_log
            echo "[INFO] $(date '+%H:%M:%S'): Before status: $qb_status" >> $path_log
            qbittorrent-pause "$qb_hash"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[INFO] $(date '+%H:%M:%S'): After status: $qb_status" >> $path_log
            menu-info "$qb_hash"
        ### Request: /resume hash ▶️▶️▶️
        elif [[ $command == /resume* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/resume //")
            qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
            qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /resume for $qb_name ($qb_hash)" >> $path_log
            echo "[INFO] $(date '+%H:%M:%S'): Before status: $qb_status" >> $path_log
            qbittorrent-resume "$qb_hash"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            qb_state=$(qbittorrent-info | jq ". | select(.hash == \"$qb_hash\")")
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[INFO] $(date '+%H:%M:%S'): After status: $qb_status" >> $path_log
            menu-info "$qb_hash"
        ### Request: /delete_torrent hash 🗑🗑🗑
        elif [[ $command == /delete_torrent* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/delete_torrent //")
            qb_state_all=$(qbittorrent-info)
            wc_be=$(echo $qb_state_all | jq .name | wc -l)
            qb_state=$(echo $qb_state_all | jq ". | select(.hash == \"$qb_hash\")")
            qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /delete_torrent for $qb_name ($qb_hash)" >> $path_log
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
        ### Request: /delete_video hash ❌❌❌
        elif [[ $command == /delete_video* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/delete_video //")
            qb_state_all=$(qbittorrent-info)
            wc_be=$(echo $qb_state_all | jq .name | wc -l)
            qb_state=$(echo $qb_state_all | jq ". | select(.hash == \"$qb_hash\")")
            qb_name=$(echo $qb_state | jq ".name" | sed -r 's/\"//g')
            qb_status=$(echo $qb_state | jq ".state" | sed -r 's/\"//g')
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /delete_video for $qb_name ($qb_hash)" >> $path_log
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
        ### Request: /add_torrent hash 🧲🧲🧲
        elif [[ $command == /add_torrent* ]]; then
            torrent_hash=$(echo $command | sed -r "s/\/add_torrent //")
            echo "[INFO] $(date '+%H:%M:%S'): Add torrent from hash: $torrent_hash for select torrent client (qBittorrent or Transmission)" >> $path_log
            data="Выберите торрент клиент для загрузки:"
            keyboard='{"inline_keyboard":['
            keyboard+="[{\"text\":\"🟢 qBittorrent\",\"callback_data\":\"\/add_hash qbit $torrent_hash\"}],"
            keyboard+="[{\"text\":\"🔲 Transmission\",\"callback_data\":\"\/add_hash trans $torrent_hash\"}]]}"
            send-keyboard "$(echo -e $data)" "$CHAT" "$keyboard"
        elif [[ $command == /add_hash* ]]; then
            add_param=$(echo $command | sed "s/\/add_hash //")
            selected_torrent=$(echo $add_param | awk '{print $1}')
            torrent_hash=$(echo $add_param | awk '{print $2}')
            echo "[INFO] $(date '+%H:%M:%S'): Add torrent from hash: $torrent_hash to Torrent Client: $selected_torrent" >> $path_log
            if [[ $selected_torrent == "qbit" ]]; then
                qbittorrent-add-torrent-from-hash "$torrent_hash"
                sleep $TIMEOUT_SEC_UPDATE_STATUS
                menu-status "$(qbittorrent-data)" "$CHAT"
            elif [[ $selected_torrent == "trans" ]]; then
                transmission-add "$torrent_hash"
                sleep $TIMEOUT_SEC_UPDATE_STATUS
                transmission-tg-status
            fi
        ### Request: /get_torrent hash 🧲⬆️
        elif [[ $command == /get_torrent* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/get_torrent //")
            echo "[INFO] $(date '+%H:%M:%S'): Get torrent files from hash: $qb_hash" >> $path_log
            # Экспортируем торрент файл на сервер
            echo "[INFO] $(date '+%H:%M:%S'): Export and send torrent file: $path/$qb_hash.torrent" >> $path_log
            qbittorrent-export-torrent-file "$qb_hash"
            # Отправляем файл в телеграм
            send-file "$path/$qb_hash.torrent"
            # Удаляем торрент файл на сервере
            # rm "$path/$qb_hash.torrent"
            menu-info $qb_hash
        ### Request: /torrent_recheck hash ♻️♻️♻️
        elif [[ $command == /torrent_recheck* ]]; then
            qb_hash=$(echo $command | sed -r "s/\/torrent_recheck //")
            echo "[INFO] $(date '+%H:%M:%S'): Recheck torrent: $qb_hash" >> $path_log
            qbittorrent-recheck "$qb_hash"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /torrent_recheck" >> $path_log
            menu-info $qb_hash
        ### Request: /torrent_limit 📶📶📶
        elif [[ $command == /torrent_limit ]]; then
            echo "[INFO] $(date '+%H:%M:%S'): Switch torrent limit" >> $path_log
            qbittorrent-switch-limit
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /torrent_limit" >> $path_log
            menu-status "$(qbittorrent-data)" "$CHAT"
        ######  🔲 🔲 🔲 Transmission 🔲 🔲 🔲
        ### Request: /trans_status
        elif [[ $command == /trans_status ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /trans_status" >> $path_log
            transmission-tg-status
        ### Request: /trans_info
        elif [[ $command == /trans_info* ]]; then
            tr_id=$(echo $command | sed "s/\/trans_info //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /trans_info for id: $tr_id" >> $path_log
            transmission-tg-info "$tr_id"
        ### Request: /trans_pause
        elif [[ $command == /trans_pause* ]]; then
            tr_param=$(echo $command | sed "s/\/trans_pause //")
            tr_id=$(echo $tr_param | awk '{print $1}')
            tr_type=$(echo $tr_param | awk '{print $2}')
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /trans_pause type $tr_type for id: $tr_id" >> $path_log
            transmission-pause "$tr_id" "$tr_type"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            transmission-tg-info "$tr_id"
        ### Request: /trans_remove
        elif [[ $command == /trans_remove* ]]; then
            tr_param=$(echo $command | sed "s/\/trans_remove //")
            tr_id=$(echo $tr_param | awk '{print $1}')
            tr_type=$(echo $tr_param | awk '{print $2}')
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /trans_remove (data: $tr_type) for id: $tr_id" >> $path_log
            transmission-remove "$tr_id" "$tr_type"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            transmission-tg-status
        ###### 🟠 🟠 🟠 PLEX 🟠 🟠 🟠
        ### Request: /plex_info 🟠
        elif [[ $command == /plex_info ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /plex_info" >> $path_log
            plex-info
        ### Request: /plex_status_key
        elif [[ $command == /plex_status_* ]]; then
            menu-plex-status "$command" "$CHAT"
        ### Request: /plex_sync_key ♻️
        elif [[ $command == /plex_sync_* ]]; then
            section_key=$(echo $command | sed "s/\/plex_sync_//")
            plex_sections=$(plex-sections | jq ". | select(.key == \"$section_key\")")
            plex_name=$(echo $plex_sections | jq -r .name)
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /plex_sync for $plex_name (key: $section_key)" >> $path_log
            plex_scanned=$(echo $plex_sections | jq -r .scanned)
            echo "[OK]   $(date '+%H:%M:%S'): Before scanned: $plex_scanned" >> $path_log
            plex-sync-section "$section_key"
            sleep $TIMEOUT_SEC_UPDATE_STATUS
            # Повторно забираем дату последнего сканирования
            plex_sections=$(plex-sections | jq ". | select(.key == \"$section_key\")")
            plex_scanned=$(echo $plex_sections | jq -r .scanned)
            echo "[OK]   $(date '+%H:%M:%S'): After scanned: $plex_scanned" >> $path_log
            # Отправляем запрос в функцию /plex_status_key для ответа
            menu-plex-status "/plex_status_$section_key" "$CHAT"
        ### Request: /plex_folder_key 📋🎥🎧
        elif [[ $command == /plex_folder_* ]]; then
            section_key=$(echo $command | sed "s/\/plex_folder_//")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /plex_folder for key: $section_key" >> $path_log
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
            keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$encoded_data" "$CHAT" "$keyboard"
            fi
        ### Request: /find "folder name or file name or path (endpoint)"
        elif [[ $command == /find* ]]; then
            folder_name=$(echo $command | sed "s/\/find //")
            if [[ $folder_name == $command ]]; then
                echo "[WARN] $(date '+%H:%M:%S'): <<< Response on $command invalid. Valid response: \"/find folder or file name\"" >> $path_log
            else
                echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /find for $folder_name to Plex" >> $path_log
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
                # Если использовался поиск а секция не была выбрана, переадресуем на выбор секции
                if [ -z "$endpoint" ]; then
                    plex-info
                else
                    menu-plex-find "$json_data" "$data" "$CHAT"
                fi
            fi
        ### Request: /plex_last_views ⏯
        elif [[ $command == /plex_last_views ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /plex_last_views" >> $path_log
            endpoint="/library/onDeck"
            json_data=$(plex-content-from-folder "$endpoint")
            data=$(echo "Список последних просмотров:\n\n")
            menu-plex-find "$json_data" "$data" "$CHAT" "last_view"
        ### Request: /plex_last_added 🆕
        elif [[ $command == /plex_last_added ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /plex_last_added" >> $path_log
            endpoint="/library/recentlyAdded"
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
            keyboard+="{\"text\":\"🗂 Торрент файлы\",\"callback_data\":\"\/torrent_files\"}]]}"
            if [[ $message_id_temp != "null" ]]; then
                edit-keyboard "$encoded_data" "$CHAT" "$keyboard" "$message_id_temp"
            else
                send-keyboard "$encoded_data" "$CHAT" "$keyboard"
            fi
        ###### ⚙️ ⚙️ ⚙️ WinAPI ⚙️ ⚙️ ⚙️
        ### Request: /win_state
        elif [[ $command == /win_state* ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /win_state" >> $path_log
            win-state
        ### Request: /win_files
        elif [[ $command == /win_files* ]]; then
            win_path=$(echo $command | sed "s/\/win_files //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /win_files for disk or directory: $win_path" >> $path_log
            win-files "$win_path"
        ### Request: /win_process
        elif [[ $command == /win_process* ]]; then
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /win_process" >> $path_log
            win-process
        ### Request: /app_status
        elif [[ $command == /app_status* ]]; then
            app_name=$(echo $command | sed "s/\/app_status //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /app_status for application: $app_name" >> $path_log
            app-status-response "$app_name"
        ### Request: ▶️▶️▶️ /app_start
        elif [[ $command == /app_start* ]]; then
            app_name=$(echo $command | sed "s/\/app_start //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /app_start for application: $app_name" >> $path_log
            if [[ $app_name == *"plex"* ]]; then
                app_status_start=$(app-start-plex "$app_name")
            else
                app_status_start=$(app-start "$app_name")
            fi
            echo "[INFO] $(date '+%H:%M:%S'): Response from $app_name: $app_status_start" >> $path_log
            app-status-response "$app_name"
        ### Request: ⏹⏹⏹ /app_stop
        elif [[ $command == /app_stop* ]]; then
            app_name=$(echo $command | sed "s/\/app_stop //")
            echo "[OK]   $(date '+%H:%M:%S'): <<< Response on /app_start for application: $app_name" >> $path_log
            app_status_stop=$(app-stop "$app_name")
            echo "[INFO] $(date '+%H:%M:%S'): Response from $app_name: $app_status_stop" >> $path_log
            app-status-response "$app_name"
        else
            echo "[WARN] $(date '+%H:%M:%S'): Command not found: $command" >> $path_log
        fi
    fi
done &
###############################################################################

###############################################################################
################################# Thread 2️⃣ ##################################
### Channel News (post news to channel from kinozal)
if [[ $TG_CHANNEL_USE = "True" ]]; then
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
                        name=$(printf "%s\n" "${html[@]}" | grep "<title>" | sed -r 's/<title>//; s/ \/.+//' | sed -r 's/`|_|\"|&|;|quot//g')
                        rating_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+floatright">//; s/<.+//' | awk '{print $1}')
                        rating_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r 's/.+floatright">//; s/<.+//')
                        year=$(printf "%s\n" "${html[@]}" | grep -E -B 1 "class=lnks_tobrs" | head -n 1 | sed -r 's/.+<\/b> //; s/<.+//')
                        url_kp=$(printf "%s\n" "${html[@]}" | grep kinopoisk | sed -r 's/.+href="//; s/" target=.+//')
                        url_imdb=$(printf "%s\n" "${html[@]}" | grep imdb | sed -r "s/.+href=\"//g; s/\".+//g")
                        ### Фильтрация постов по рейтингу
                        if [[ ($rating_kp == "—" || $rating_kp < $RATING_KP) && $rating_imdb < $RATING_IMDB ]]; then
                            ((count_skip++))
                            echo "[INFO] $(date '+%H:%M:%S'): - Skip: $a (rating kp: $rating_kp and imdb: $rating_imdb)" >> $path_log
                            continue
                        ### Фильтрация постов по году выхода
                        elif [[ $year < $FILTER_YEAR ]]; then
                            ((count_skip++))
                            echo "[INFO] $(date '+%H:%M:%S'): - Skip: $a (year: $year)" >> $path_log
                            continue
                        else
                            ((count_post++))
                            echo "[OK]   $(date '+%H:%M:%S'): + Post: $a (year: $year, rating kp: $rating_kp and imdb: $rating_imdb)" >> $path_log
                            data=$(read-html "$html" "$a" "Channel")
                            keyboard='{"inline_keyboard":['
                            ### Отдаем ссылки на 🟠 Кинопоиск, 🟡 IMDb и 🟣 Кинозал, если они были получены
                            if [[ -n "$url_kp" && -n "$url_imdb" ]]; then
                                keyboard+="[{\"text\":\"Кинопоиск\",\"url\":\"$url_kp\"},"
                                keyboard+="{\"text\":\"IMDb\",\"url\":\"$url_imdb\"},"
                                keyboard+="{\"text\":\"Кинозал\",\"url\":\"$a\"}],"
                            elif [[ -n "$url_kp" && -z "$url_imdb" ]]; then
                                keyboard+="[{\"text\":\"Кинопоиск\",\"url\":\"$url_kp\"},"
                                keyboard+="{\"text\":\"Кинозал\",\"url\":\"$a\"}],"
                            elif [[ -z "$url_kp" && -n "$url_imdb" ]]; then
                                keyboard+="[{\"text\":\"Кинозал\",\"url\":\"$a\"},"
                                keyboard+="{\"text\":\"IMDb\",\"url\":\"$url_imdb\"}],"
                            else
                                keyboard+="[{\"text\":\"Кинозал\",\"url\":\"$a\"}],"
                            fi
                            ### Забираем info hash
                            info_hash=$(echo -e ${data[@]} | grep "Инфо хеш:" | sed -r "s/\`//g; s/.+\:\*\s//g")
                            ####################### ❤️❤️❤️ Instant © WebTorrent ❤️❤️❤️ ########################
                            ### Source: https://github.com/webtorrent/webtorrent
                            ### К созданным на базе протокола WebTorrent пиринговым сетям нельзя подключиться с помощью BitTorrent-клиента, взаимодействие возможно только между клиентами, использующими WebRTC.
                            # url_magnet="https://instant.io/#$info_hash"
                            ################## 💙💙💙 BTorrent (Web Client WebTorrent) 💙💙💙 #################
                            ### Source: https://github.com/DiegoRBaquero/BTorrent
                            # url_magnet="https://btorrent.xyz/#$info_hash"
                            ##################################### magnet2url #####################################
                            ### Source: https://github.com/Lifailon/magnet2url
                            # magnet=$(magnet-uri "$info_hash")
                            # url_magnet="https://lifailon.github.io/magnet2url#$magnet"
                            ### (error) keyboard не принимает символы & в параметрах url
                            ### Параметр #tr добавляет список серверов торрент трекеров при переадресации через magnet2url
                            url_magnet=$(echo "https://lifailon.github.io/magnet2url#$info_hash#tr" | sed -r "s/\s//g")
                            keyboard+="[{\"text\":\"🧲 Скачать\",\"url\":\"$url_magnet\"},"
                            ######################### ▶️▶️▶️ Kinomix © Kinobox ▶️▶️▶️ #########################
                            ### Source: https://kinobox.tv
                            kp_id=$(echo $url_kp | sed -r "s/.+\///g")
                            url_km="https://kinomix.web.app/#$kp_id"
                            keyboard+="{\"text\":\"▶️ Смотреть онлайн\",\"url\":\"$url_km\"}]]}"
                            encoded_data=$(echo -ne "$data" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
                            send-keyboard "$encoded_data" "$TG_CHANNEL" "$keyboard"
                            # (Debug) Отправить в чат бота
                            # send-keyboard "$encoded_data" "$CHAT" "$keyboard"
                            # send-keyboard "Test keyboard" "$CHAT" "$keyboard"
                            # send-keyboard "$encoded_data" "$CHAT"
                        fi
                    else
                        ((count_error++))
                        echo "[ERRO] $(date '+%H:%M:%S'): ! HTML data not avaliable: $a" >> $path_log
                    fi
                done
                echo "[INFO] $(date '+%H:%M:%S'): All records: $count_all, post: $count_post, skip: $count_skip, error: $count_error" >> $path_log
                link_temp=$link
                echo "[INFO] $(date '+%H:%M:%S'): Update last link: $link_temp" >> $path_log
            else
                echo "[INFO] $(date '+%H:%M:%S'): RSS no new data (last link: $link_temp)" >> $path_log
            fi
            sleep $TIMEOUT_SEC_POST
        else
            echo "[ERRO] $(date '+%H:%M:%S'): ! RSS data not avaliable" >> $path_log
            sleep $TIMEOUT_SEC_ERROR
        fi
    done &
fi
###############################################################################
