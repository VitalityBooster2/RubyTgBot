require "tmpdir"
require "open3"

module ProgrammerHelperBot
  class YoutubeAudioDownloader
    MAX_DURATION_SECONDS = 10 * 60
    YOUTUBE_REGEX = %r{(?:https?://)?(?:www\.)?(youtube\.com/watch\?v=|youtu\.be/)}i.freeze

    def youtube_url?(text)
      text.to_s.match?(YOUTUBE_REGEX)
    end

    def download_mp3(url)
      raise ArgumentError, "Invalid YouTube URL" unless youtube_url?(url)

      ensure_duration_within_limit!(url)
      Dir.mktmpdir("youtube_audio") do |dir|
        output_pattern = File.join(dir, "audio.%(ext)s")
        command = [
          "yt-dlp",
          "--no-playlist",
          "-x",
          "--audio-format",
          "mp3",
          "-o",
          output_pattern,
          url
        ]
        append_auth_options!(command)

        _out, err, status = Open3.capture3(*command)
        unless status.success?
          details = safe_utf8(err).strip
          if details.match?(/Failed to decrypt with DPAPI/i)
            raise <<~MSG.strip
              Не удалось прочитать cookies из браузера (DPAPI, Windows).
              Используй cookies-файл вместо --cookies-from-browser:
              1) Экспортируй cookies YouTube в Netscape-формате (cookies.txt).
              2) В .env укажи:
                 YTDLP_COOKIES_FILE=C:/path/to/cookies.txt
              3) Удали/закомментируй YTDLP_COOKIES_FROM_BROWSER и перезапусти бота.

              Техническая ошибка:
              #{details}
            MSG
          end

          if details.match?(/Sign in to confirm you're not a bot|Sign in to confirm you\?re not a bot/i)
            raise <<~MSG.strip
              YouTube просит подтверждение аккаунта. Добавь cookies для yt-dlp через .env:
              - YTDLP_COOKIES_FROM_BROWSER=chrome
              или
              - YTDLP_COOKIES_FILE=C:/path/to/cookies.txt

              Техническая ошибка:
              #{details}
            MSG
          end

          raise "yt-dlp failed: #{details}"
        end

        mp3_files = Dir[File.join(dir, "*.mp3")]
        raise "MP3 file was not produced" if mp3_files.empty?

        File.binread(mp3_files.first)
      end
    end

    private

    def ensure_duration_within_limit!(url)
      command = [
        "yt-dlp",
        "--no-playlist",
        "--print",
        "%(duration)s",
        "--skip-download",
        url
      ]
      append_auth_options!(command)

      out, err, status = Open3.capture3(*command)
      raise "yt-dlp failed: #{safe_utf8(err).strip}" unless status.success?

      duration_seconds = out.to_s.strip.to_f
      return if duration_seconds <= MAX_DURATION_SECONDS

      raise "Видео слишком длинное: #{(duration_seconds / 60.0).round(1)} мин. Допустимо до 10 минут."
    end

    def safe_utf8(text)
      text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end

    def append_auth_options!(command)
      cookies_file = ENV["YTDLP_COOKIES_FILE"].to_s.strip
      cookies_from_browser = ENV["YTDLP_COOKIES_FROM_BROWSER"].to_s.strip

      if !cookies_file.empty?
        if cookies_file.match?(%r{\A(?:[A-Za-z]:)?/?path/to/cookies\.txt\z}i)
          raise <<~MSG.strip
            В .env указан шаблонный путь cookies: #{cookies_file}
            Укажи реальный путь к файлу cookies.txt, например:
            YTDLP_COOKIES_FILE=C:/Users/YourUser/Downloads/cookies.txt
          MSG
        end
        raise "Файл cookies не найден: #{cookies_file}" unless File.file?(cookies_file)

        command.insert(-2, "--cookies", cookies_file)
      elsif !cookies_from_browser.empty?
        command.insert(-2, "--cookies-from-browser", cookies_from_browser)
      end
    end
  end
end
