require "dotenv/load"
require "telegram/bot"
require "open-uri"
require "tempfile"
require "net/http"
require "uri"
require_relative "lib/programmer_helper_bot/chat_state"
require_relative "lib/programmer_helper_bot/file_state_repository"
require_relative "lib/programmer_helper_bot/chat_state_service"
require_relative "lib/programmer_helper_bot/file_analyzer"
require_relative "lib/programmer_helper_bot/link_shortener"
require_relative "lib/programmer_helper_bot/python_sandbox"
require_relative "lib/programmer_helper_bot/youtube_audio_downloader"
require_relative "lib/programmer_helper_bot/message_router"

token = ENV["TELEGRAM_BOT_TOKEN"]
abort("Set TELEGRAM_BOT_TOKEN in environment or .env") if token.to_s.strip.empty?

analyzer = ProgrammerHelperBot::FileAnalyzer.new
shortener = ProgrammerHelperBot::LinkShortener.new
sandbox = ProgrammerHelperBot::PythonSandbox.new
youtube = ProgrammerHelperBot::YoutubeAudioDownloader.new
state_repository = ProgrammerHelperBot::FileStateRepository.new(path: File.join(__dir__, "tmp", "chat_states.json"))
state_service = ProgrammerHelperBot::ChatStateService.new(repository: state_repository)
router = ProgrammerHelperBot::MessageRouter.new(
  file_analyzer: analyzer,
  link_shortener: shortener,
  python_sandbox: sandbox,
  youtube_downloader: youtube
)

help_text = <<~HELP
  Я умею:
  1) Анализировать .txt / .py файлы (строки, символы, импорты)
  2) Скачать аудио из YouTube ссылки в mp3
  3) Выполнить Python код: "python print(2+2)"
  4) Сократить ссылку: "shorten https://example.com"
HELP

MAX_TEXT_MESSAGE_LENGTH = 3500
TELEGRAM_HTTP_OPEN_TIMEOUT = 20
TELEGRAM_HTTP_READ_TIMEOUT = 120
TELEGRAM_HTTP_WRITE_TIMEOUT = 120
TELEGRAM_HTTP_RETRIES = 3

main_menu_markup = {
  keyboard: [
    ["1) Анализ файла", "2) YouTube -> mp3"],
    ["3) Выполнить Python", "4) Сократить ссылку"]
  ],
  resize_keyboard: true,
  one_time_keyboard: false
}

Telegram::Bot::Client.run(token) do |bot|
  send_multipart_file = lambda do |chat_id:, endpoint:, field_name:, file_path:, filename:, content_type:, caption: nil, reply_markup: nil|
    boundary = "RubyBotBoundary#{rand(1_000_000_000)}"
    file_content = File.binread(file_path)
    payload = +"".b
    payload << "--#{boundary}\r\n".b
    payload << "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".b
    payload << "#{chat_id}\r\n".b
    if caption
      payload << "--#{boundary}\r\n".b
      payload << "Content-Disposition: form-data; name=\"caption\"\r\n\r\n".b
      payload << "#{caption}\r\n".dup.force_encoding(Encoding::BINARY)
    end
    if reply_markup
      payload << "--#{boundary}\r\n".b
      payload << "Content-Disposition: form-data; name=\"reply_markup\"\r\n\r\n".b
      payload << "#{reply_markup}\r\n".dup.force_encoding(Encoding::BINARY)
    end
    payload << "--#{boundary}\r\n".b
    payload << "Content-Disposition: form-data; name=\"#{field_name}\"; filename=\"#{filename}\"\r\n".b
    payload << "Content-Type: #{content_type}\r\n\r\n".b
    payload << file_content
    payload << "\r\n--#{boundary}--\r\n".b

    uri = URI("https://api.telegram.org/bot#{token}/#{endpoint}")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
    req.body = payload
    attempts = 0

    begin
      attempts += 1
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: TELEGRAM_HTTP_OPEN_TIMEOUT,
        read_timeout: TELEGRAM_HTTP_READ_TIMEOUT,
        write_timeout: TELEGRAM_HTTP_WRITE_TIMEOUT
      ) { |http| http.request(req) }
      raise "Не удалось отправить файл: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT => e
      raise "Сеть недоступна при отправке файла: #{e.message}" if attempts >= TELEGRAM_HTTP_RETRIES

      sleep(1.5 * attempts)
      retry
    end
  end

  send_with_menu = lambda do |chat_id, text|
    bot.api.send_message(
      chat_id: chat_id,
      text: text,
      reply_markup: main_menu_markup.to_json
    )
  end

  send_output_with_fallback = lambda do |chat_id, text, filename_prefix: "output"|
    if text.to_s.length <= MAX_TEXT_MESSAGE_LENGTH
      send_with_menu.call(chat_id, text)
      next
    end

    Tempfile.create([filename_prefix, ".txt"]) do |f|
      f.write(text)
      f.rewind
      send_multipart_file.call(
        chat_id: chat_id,
        endpoint: "sendDocument",
        field_name: "document",
        file_path: f.path,
        filename: "#{filename_prefix}.txt",
        content_type: "text/plain",
        caption: "Вывод слишком большой, отправляю файлом.",
        reply_markup: main_menu_markup.to_json
      )
    end
  end

  bot.listen do |message|
    next unless message.respond_to?(:chat)

    begin
      chat_id = message.chat.id
      state = state_service.load(chat_id)
      action = router.detect_action(text: message.text, document: message.document, state: state)
      state_service.persist_for_action(chat_id: chat_id, action: action)

      case action
      when :menu_file_stats
        send_with_menu.call(chat_id, "Пришли .txt или .py файл документом, и я посчитаю строки, символы и импорты.")

      when :menu_youtube
        send_with_menu.call(chat_id, "Отправь ссылку на YouTube (youtube.com или youtu.be), и я скачаю аудио в mp3.")

      when :menu_python
        send_with_menu.call(chat_id, "Отправь Python-код. Пример: print(2+2)")

      when :menu_short_link
        send_with_menu.call(chat_id, "Отправь ссылку для сокращения. Пример: https://example.com")

      when :file_stats
        doc = message.document
        unless [".txt", ".py"].include?(File.extname(doc.file_name.to_s).downcase)
          bot.api.send_message(chat_id: chat_id, text: "Поддерживаются только .txt и .py файлы.")
          next
        end

        file_data = bot.api.get_file(file_id: doc.file_id)
        file_path = if file_data.respond_to?(:file_path)
                      file_data.file_path
                    elsif file_data.respond_to?(:dig)
                      file_data.dig("result", "file_path")
                    end
        unless file_path
          bot.api.send_message(chat_id: chat_id, text: "Не удалось получить файл.")
          next
        end

        file_url = "https://api.telegram.org/file/bot#{token}/#{file_path}"
        content = URI.open(file_url, &:read)
        stats = analyzer.analyze(content, doc.file_name)
        response = <<~TEXT
          Файл: #{doc.file_name}
          Строк: #{stats[:lines]}
          Символов: #{stats[:characters]}
          Импортов (Python): #{stats[:imports]}
        TEXT
        bot.api.send_message(chat_id: chat_id, text: response)

      when :youtube
        bot.api.send_message(chat_id: chat_id, text: "Скачиваю аудио, подожди...")
        binary = youtube.download_mp3(message.text.strip)
        Tempfile.create(["youtube_audio", ".mp3"]) do |f|
          f.binmode
          f.write(binary)
          f.rewind
          send_multipart_file.call(
            chat_id: chat_id,
            endpoint: "sendAudio",
            field_name: "audio",
            file_path: f.path,
            filename: "youtube_audio.mp3",
            content_type: "audio/mpeg",
            reply_markup: main_menu_markup.to_json
          )
        end

      when :python
        code = router.extract_python_code(message.text)
        result = sandbox.execute(code)
        text = if result[:ok]
                 result[:stdout].empty? ? "(пустой вывод)" : result[:stdout]
               else
                 "Ошибка:\n#{result[:stderr]}"
               end
        send_output_with_fallback.call(chat_id, text, filename_prefix: "python_output")

      when :short_link
        raw_text = message.text.to_s
        url = raw_text.match?(/\A(?:shorten|short)\s+/i) ? router.extract_link(raw_text) : raw_text.strip
        short = shortener.shorten(url)
        send_with_menu.call(chat_id, "Сокращенная ссылка: #{short}")

      else
        send_with_menu.call(chat_id, help_text)
      end
    rescue StandardError => e
      send_with_menu.call(message.chat.id, "Ошибка: #{e.message}")
    end
  end
end
