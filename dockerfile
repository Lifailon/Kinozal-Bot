# Базовый легковесный образ
FROM alpine:latest
# Устанавливаем рабочую директорию как в конфигурации для локального запуска 
WORKDIR /home/lifailon/kinozal-bot
# Установка зависимостей
RUN apk add --no-cache bash coreutils curl grep sed gawk jq
# Копируем скрипт и конфигурацию
COPY kinozal-bot.sh .
COPY kinozal-bot.conf .
# Права на запуск скрипта
RUN chmod +x kinozal-bot.sh
# Запускаем потоки сервера и логируем вывод работы бота в консоль
CMD ["bash", "-c", "./kinozal-bot.sh start bot docker"]