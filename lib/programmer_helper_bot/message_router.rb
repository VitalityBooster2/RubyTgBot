# frozen_string_literal: true

module ProgrammerHelperBot
  class MessageRouter
    def initialize(file_analyzer:, link_shortener:, python_sandbox:, youtube_downloader:)
      @file_analyzer = file_analyzer
      @link_shortener = link_shortener
      @python_sandbox = python_sandbox
      @youtube_downloader = youtube_downloader
    end

    def detect_action(text:, document:, state: nil)
      current_state = state || ChatState.new
      return :file_stats if document

      text = text.to_s.strip
      mode_action = detect_by_mode(text, current_state)
      return mode_action if mode_action

      return :menu_file_stats if text.match?(/\A1(?:\b|[).:\-\s])/)
      return :menu_youtube if text.match?(/\A2(?:\b|[).:\-\s])/)
      return :menu_python if text.match?(/\A3(?:\b|[).:\-\s])/)
      return :menu_short_link if text.match?(/\A4(?:\b|[).:\-\s])/)
      return :help if text.match?(%r{\A/start\z}i)
      return :python if text.downcase.start_with?('python ')
      return :short_link if text.match?(%r{\A(?:shorten|short)\s+https?://\S+}i)
      return :youtube if @youtube_downloader.youtube_url?(text)

      :help
    end

    def extract_python_code(text)
      text.to_s.sub(/\Apython\s+/i, '')
    end

    def extract_link(text)
      text.to_s.split(/\s+/, 2).last.to_s.strip
    end

    private

    def detect_by_mode(text, state)
      case state.mode
      when 'awaiting_youtube'
        return :youtube if @youtube_downloader.youtube_url?(text)
      when 'awaiting_python'
        return :python unless text.empty?
      when 'awaiting_short_link'
        return :short_link if text.match?(%r{\Ahttps?://\S+}i)
      when 'awaiting_file'
        return :help
      end

      nil
    end
  end
end
