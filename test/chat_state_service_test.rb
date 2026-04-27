require_relative "test_helper"
require "tmpdir"

class ChatStateServiceTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir("rubybot_state_test")
    @store_path = File.join(@tmp_dir, "chat_states.json")
    repository = ProgrammerHelperBot::FileStateRepository.new(path: @store_path)
    @service = ProgrammerHelperBot::ChatStateService.new(repository: repository)
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && Dir.exist?(@tmp_dir)
  end

  def test_persists_menu_transition_for_chat
    @service.persist_for_action(chat_id: 123, action: :menu_python)
    state = @service.load(123)
    assert_equal "awaiting_python", state.mode
  end

  def test_resets_to_idle_after_action_execution
    @service.persist_for_action(chat_id: 123, action: :menu_short_link)
    @service.persist_for_action(chat_id: 123, action: :short_link)
    state = @service.load(123)
    assert_equal "idle", state.mode
  end

  def test_keeps_state_isolated_between_chats
    @service.persist_for_action(chat_id: 100, action: :menu_python)
    @service.persist_for_action(chat_id: 200, action: :menu_youtube)
    assert_equal "awaiting_python", @service.load(100).mode
    assert_equal "awaiting_youtube", @service.load(200).mode
  end
end
