# Базовый легковесный образ
FROM alpine:latest
# Устанавливаем рабочую директорию как в конфигурации для локального запуска 
WORKDIR /home/lifailon/kinozal-bot
# Установка зависимостей
RUN apk add --no-cache bash coreutils curl grep sed gawk jq
# Копируем скрипт и конфигурацию
COPY kinozal-bot-0.4.5.sh .
COPY kinozal-bot.conf .
# Права на запуск скрипта
RUN chmod +x kinozal-bot-0.4.5.sh
# Запускаем потоки сервера и логируем вывод работы бота в консоль
CMD ["bash", "-c", "./kinozal-bot-0.4.5.sh start bot docker"]