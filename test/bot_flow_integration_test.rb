require_relative "test_helper"
require "tmpdir"

class BotFlowIntegrationTest < Minitest::Test
  FakeMessage = Struct.new(:text, :document, keyword_init: true)

  class FakeYoutubeDownloader
    def youtube_url?(text)
      text.to_s.include?("youtube.com") || text.to_s.include?("youtu.be")
    end
  end

  def setup
    tmp_dir = Dir.mktmpdir("rubybot_flow_test")
    @tmp_dir = tmp_dir
    repository = ProgrammerHelperBot::FileStateRepository.new(path: File.join(tmp_dir, "chat_states.json"))
    @state_service = ProgrammerHelperBot::ChatStateService.new(repository: repository)
    @router = ProgrammerHelperBot::MessageRouter.new(
      file_analyzer: Minitest::Mock.new,
      link_shortener: Minitest::Mock.new,
      python_sandbox: Minitest::Mock.new,
      youtube_downloader: FakeYoutubeDownloader.new
    )
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && Dir.exist?(@tmp_dir)
  end

  def test_stateful_flow_for_short_link_button_and_plain_link
    chat_id = 777
    state = @state_service.load(chat_id)
    action = @router.detect_action(text: "4) Сократить ссылку", document: nil, state: state)
    assert_equal :menu_short_link, action
    @state_service.persist_for_action(chat_id: chat_id, action: action)

    persisted = @state_service.load(chat_id)
    assert_equal "awaiting_short_link", persisted.mode

    action2 = @router.detect_action(text: "https://example.com", document: nil, state: persisted)
    assert_equal :short_link, action2
    @state_service.persist_for_action(chat_id: chat_id, action: action2)

    assert_equal "idle", @state_service.load(chat_id).mode
  end

  def test_stateful_flow_for_python_button_and_plain_code
    chat_id = 888
    action = @router.detect_action(text: "3) Выполнить Python", document: nil, state: @state_service.load(chat_id))
    assert_equal :menu_python, action
    @state_service.persist_for_action(chat_id: chat_id, action: action)

    action2 = @router.detect_action(text: "print(2+2)", document: nil, state: @state_service.load(chat_id))
    assert_equal :python, action2
  end
end
