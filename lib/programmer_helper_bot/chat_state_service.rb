module ProgrammerHelperBot
  class ChatStateService
    MENU_TO_MODE = {
      menu_file_stats: "awaiting_file",
      menu_youtube: "awaiting_youtube",
      menu_python: "awaiting_python",
      menu_short_link: "awaiting_short_link"
    }.freeze

    def initialize(repository:)
      @repository = repository
    end

    def load(chat_id)
      @repository.load(chat_id)
    end

    def persist_for_action(chat_id:, action:)
      current = load(chat_id)
      next_state = if MENU_TO_MODE.key?(action)
                     current.with_mode(MENU_TO_MODE.fetch(action))
                   elsif actionable?(action)
                     current.with_mode("idle")
                   else
                     current
                   end
      @repository.save(chat_id, next_state)
      next_state
    end

    private

    def actionable?(action)
      %i[file_stats youtube python short_link help].include?(action)
    end
  end
end
