# Базовый легковесный образ
FROM alpine:latest

# Устанавливаем рабочую директорию как в конфигурации для локального запуска 
WORKDIR /kinozal-bot

# Установка зависимостей
RUN apk add --no-cache bash coreutils curl grep sed gawk jq tzdata

# Установка часового пояса
ENV TZ=Etc/GMT-3
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Копируем скрипт
COPY kinozal-bot.sh .

# Не копируем конфигурацию
# COPY kinozal-bot.conf .
# Монтируем при запуске контейнера с помощью: --volume ./kinozal-bot.conf:/kinozal-bot/kinozal-bot.conf

# Права на запуск скрипта
RUN chmod +x kinozal-bot.sh

# Запускаем сервер и логируем вывод работы бота в консоль
ENTRYPOINT ["bash", "-c", "./kinozal-bot.sh start bot docker"]

# Запуск двух потоков (бот и канал)
# ENTRYPOINT ["bash", "-c", "./kinozal-bot.sh start all docker"]