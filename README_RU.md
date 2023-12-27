# <img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/ico/kinozal-bot-256px.png" width="25" /> Kinozal-Bot

![GitHub release (with filter)](https://img.shields.io/github/v/release/lifailon/kinozal-bot?color=<green>)
![GitHub top language](https://img.shields.io/github/languages/top/lifailon/kinozal-bot)
![GitHub last commit (by committer)](https://img.shields.io/github/last-commit/lifailon/kinozal-bot)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/lifailon/kinozal-bot)
![GitHub License](https://img.shields.io/github/license/lifailon/kinozal-bot?color=<green>) \
[![Kinozal-News](https://img.shields.io/github/v/release/lifailon/kinozal-bot?label=Telegram+Kinozal-News&logo=Telegram&style=social)](https://t.me/kinozal_news)

🔈 **[Description in English (using DeepL Translate)](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/README.md)**

📝 **[Публикация на Habr](https://habr.com/ru/articles/782028/)**

🍿 Цель проекта:

- Генерация новых постов с отправкой в Telegram канал на основе новых публикаций в трекере **[Кинозал](https://kinozal.tv)** с фильтрацией по рейтингу и году выхода.
- Автоматизация процесса донесения контента до телевизора используя только телефон. Выбор (предложенного из поста канала или при ручном поиске в боте) и загрузка подходящего по разрешению, озвучке или размеру торрент-файла (используя предложенные рекомендуемые ссылки к каждой публикации), постановка на загрузку в qBittorrent с возможностью управления и отслеживанием статуса, а так же изменением приоритета загрузки файлов, и синхронизации контента с Plex Media Server, а так же просмотр содержимого секций и директорий.

## 📚 Stack

- **Kinozal**: чтение RSS ленты, получение данных из html (api отсутствует), поиск и фильтрация контента, загрузка торрент файлов;
- **Telegram api**: отправка сообщений в канал, чтение (только команд) и отправка ответных сообщений в формате меню (keyboard);
- **qBittorrent api**: загрузка данных из торрент файлов и управление данными (пауза, удаление, изменение приоритета);
- **Plex Media Server api**: синхронизация данных и получение информации о содержимом секций и дочерних файлах.

**Опционально:**

- Любое **клиентское приложение VPN и/или прокси сервер** для доступа (клиента curl) в Кинозал;
- **[Kinopoisk API](https://github.com/mdwitr0/kinopoiskdev)**: получение дополнительной информации о фильме и трейлеры в youtube (кнопка **Описание Кинопоиск**), ссылки на актера в Кинопоиск и фильмография из Кинозал (добавлено в версии 0.4.2);
- **[WinAPI](https://github.com/Lifailon/WinAPI)**: остановка и запуска приложений Plex и qBittorrent, управление директориями и файлами, получение метрик работоспособности системы (будет добавлено в следующей версии).

## 🎉 Example

Действующий канал с публикациями: 📢 **[Kinozal-News](https://t.me/kinozal_news)**

<a href="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/status_torrent_and_search_kinozal.jpg"><img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.0/status_torrent_and_search_kinozal.jpg" width="400"/></a>
<a href="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/info_torrent.jpg"><img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.0/info_torrent.jpg" width="400"/></a>
<a href="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/find_kinozal.jpg"><img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.0/find_kinozal.jpg" width="400"/></a>
<a href="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/plex_folder.jpg"><img src="https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.0/plex_folder.jpg" width="400"/></a>

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/example/0.4.0/telegram-example.gif)

## 🚀 Install

Для работы бота, необходимо подготовить свою собственную среду. Все настройки подключения и фильтрации новых публикаций задаются в конфигурационном файле: **kinozal-bot.conf** 📑.

1. Зарегистрировать аккаунт в **Кинозал** и заполнить параметры в конфигурации:

`KZ_PROFILE="id_you_profile"` - используется для получения информации из профиля \
`KZ_USER="LOGIN"` - используется на этапе загрузки торрент-файла и получения информации в профиле \
`KZ_PASS="PASSWORD"`

2. Если у вас нет прямого доступа в Кинозал, можете воспользоваться VPN или прокси сервером (я использую **Handy Cache** в связке с **VPN Hotspot Shield в режиме раздельного туннелирования (Split Tunneling)** на базе операционной системы Windows) через который бот может проксировать свои запросы.

`PROXY="True"` - включить использование прокси сервера в curl-запросах при обращении к Кинозал \
`PROXY_ADDR="http://192.168.3.100:9090"` \
`PROXY_USER="LOGIN"` \
`PROXY_PASS="PASSWORD"`

3. Создать бота в **[@botfather](https://t.me/BotFather)**, используя интуитивно понятный интерфейс и получить его API-токен. Так же создайте свой канал для новых публикаций в Кинозал и отдельно начните свой чат с созданным ранее ботом для взаимодействия с сервисами. Получите id канала (начинается с символа "-") и чата, используя бота: **[Get My ID](https://t.me/getmyid_arel_bot)** и заполните параметры:

`TG_TOKEN="6873341222:AAFnVgfavenjwbKutRwROQQBya_XXXXXXXX"` - используется для чтения и отправки сообщений в чат-бот Telegram \
`TG_CHANNEL="-1002064864175"` - используется для отправки сообщений в канал \
`TG_CHAT="8888888888,999999999"` - id всех чатов для доступа к боту (заполняется через запятую), в дальнейшем id можно получить в выводе лога из запросов обращений новых клиентов \
`TG_BOT_NAME="lifailon_ps_bot"` - используется для ссылки на бота из канала

4. Установить торрент клиент **qBittorrent** и в настройках включить **Веб-интерфейс**.

`QB_ADDR="http://192.168.3.100:8888"` - указать итоговый URL-адрес, где указан IP-адрес машины, на которой запущен qBittorrent и порт (задается в настройках) \
`QB_USER="LOGIN"` - указывается в поле **Аутентификация** в настройках **Веб-интерфейс** \
`QB_PASS="PASSWORD"`

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/settings/qbittorrent-settings.jpg)

> Добавьте директорию с содержимым контанта Plex для загрузки по умолчанию в qBittorrent

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/settings/qbittorrent-folder-default.jpg)

5. Установить **Plex Media Server** (в моем случае установлен там же, где клиент qBittorrent на Windows машине) и **получить ключ/токен** для доступа к REST API. Я не нашел способа получить ключ в веб-интерфейсе, по этому при авторизации перехватил токен в url-запросе сетевого журнала (X-Plex-Token=), используя **Development Tools** (нет ограничения по времени).

`PLEX_ADDR="http://192.168.3.100:32400"` \
`PLEX_TOKEN="TOKEN"`

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/settings/plex-token.jpg)

> Добавьте директорию контента на сервер Plex, на которую настроен клиент qBittorrent по умолчанию

![Image alt](https://github.com/Lifailon/Kinozal-Bot/blob/rsa/image/settings/plex-add-folder.jpg)

6. Получите свой API токен для доступа к базе Кинопоиска (неофициальной, из IMDb), используя бота Telegram **[@kinopoiskdev_bot](https://t.me/kinopoiskdev_bot)** (в бесплатной версии 200 запросов в сутки).

## 🐧 Start

Проверьте, что у вас установлен **[jq](https://github.com/jqlang/jq)**:

```bash
apt install jq
jq --version
jq-1.6
```

Для запуска бота на удаленной машине (я использую Ubuntu Server 22.04) расположите конфигурационный файл **kinozal-bot.conf** рядом со скриптом (пути хранения лог-файла, куки и торрент файлов задаются в конфигурации) и используйте интерпретатор 🐧 для запуска (root права не требуются):

```bash
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh
```

При запуске, будет указан путь к журналу. Всего запускается 2 основных потока (процесса) и до 20 дочерних в процессе работы.

**Остановить сервис:**

```bash
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh stop
bash ~/bash kinozal-torrent/kinozal-bot-0.4.sh status
```

## 📌 Commands

Список всех доступных команд (за исключением `/search`) автоматизированы через меню бота.

`/search` - Поиск в Кинозал по названию \
`/profile` - Профиль Кинозал (количество доступных для загрузки торрент файлов, статистика загрузки и отдачи, время сид и пир) \
`/torrent_files` - Список загруженных торрент файлов (с возможностью удаления файлов) \
`/status` - qBittorrent manager (список и статус всех текущих торрентов, добавленных в торрент-клиент) \
`/plex_info` - Plex content (список доступных секций для выбора) \
`/download_torrent` - Загрузить торрент файл (передать два параметра: id и имя файла без пробелов) \
`/delete_torrent_file_id` - Удалить торрент файл по id \
`/find_kinozal_id` - Поиск в Кинозал по id \
`/download_video_id` - Добавить в qBittorrent на загрузку из торрент файла \
`/info` - Статус загрузки указанного торрента (передать параметр: hash торрента) \
`/torrent_content` - Содержимое (файлы) торрента (передать параметр: hash торрента) \
`/file_torrent` - Статус выбранного торрент файла (передать параметр: порядковый индекс файла) \
`/torrent_priority` - Изменить приоритет выбранного файла в /file_torrent (передать параметр: номер приоритета) \
`/pause` - Установить на паузу (передать параметр: hash торрента) \
`/resume` - Восстановить загрузку (передать параметр: hash торрента) \
`/delete_torrent` - Удалить торрент из загрузки (передать параметр: hash торрента) \
`/delete_video` - Удалить вместе с видео данными (передать параметр: hash торрента) \
`/plex_status_key` - Информация о выбранной секции в Plex (передать параметр: ключ секции) \
`/plex_sync_key` - Синхронизировать указанную секцию в Plex (передать параметр: ключ секции) \
`/plex_folder_key` - Получить список директорий и файлов в выбранной секции \
`/find` - Поиск контента в Plex по пути (передать параметр: endpoint) \

### Добавлены в версии 0.4.1:

`/plex_last_views` - Список последних просмотров (дата просмотра и время остановки) \
`/plex_last_added` - Список последних добавленных файлов \
`/kinozal_description` - Описание фильма из Кинозал (передать параметр: id kinozal)

### Добавлены в версии 0.4.2:

`/kinozal_actors` - Список актеров из Кинозал (передать параметр: id kinozal) \
`/actor` - Описание и поиск актера и его фильмографии из Кинозала и ссылка на Кинопоиск (передать параметр: имя актера) \
`/kinopoisk_movie` - Информация о фильме из Кинопоиск по id kinopoisk (передать параметр: id kinozal)
