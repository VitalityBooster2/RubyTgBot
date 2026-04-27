# Ruby Telegram Programmer Helper Bot

Telegram-бот на Ruby для рутинных задач программиста:

- Анализ `.txt` и `.py` файлов (строки, символы, импорты Python)
- Скачивание аудио с YouTube-ссылки в формате `.mp3` (через `yt-dlp`)
- Выполнение Python-кода (`python print(2+2)`)
- Сокращение ссылок (`shorten https://example.com`)

## Requirements

- Ruby 3.1+
- Python в PATH (для мини-компилятора)
- `yt-dlp` в PATH (для YouTube->mp3)
- FFmpeg в PATH (обычно нужен `yt-dlp` для конвертации в mp3)

## Setup

1. Установить зависимости:

```bash
bundle install
```

2. Создать `.env`:

```bash
TELEGRAM_BOT_TOKEN=your_token_here
```

3. Запустить:

```bash
ruby bot.rb
```

## Usage

- Отправь `.txt` или `.py` файлы боту
- Отправь YouTube ссылку
- Выполни Python:
  - `python print(2+2)`
- Сократи ссылку:
  - `shorten https://example.com`

## Tests

```bash
bundle exec rake test
```

Тесты покрывают:

- анализ файлов
- роутинг команд
- сокращение ссылок (со стабами HTTP)
- выполнение Python-кода и таймаут
