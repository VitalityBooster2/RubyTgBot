require_relative "test_helper"

class MessageRouterTest < Minitest::Test
  def setup
    @router = ProgrammerHelperBot::MessageRouter.new(
      file_analyzer: ProgrammerHelperBot::FileAnalyzer.new,
      link_shortener: ProgrammerHelperBot::LinkShortener.new,
      python_sandbox: ProgrammerHelperBot::PythonSandbox.new,
      youtube_downloader: ProgrammerHelperBot::YoutubeAudioDownloader.new
    )
  end

  def test_detects_python
    action = @router.detect_action(text: "python print(2+2)", document: nil, state: ProgrammerHelperBot::ChatState.new)
    assert_equal :python, action
  end

  def test_detects_short_link
    action = @router.detect_action(text: "shorten https://example.com", document: nil, state: ProgrammerHelperBot::ChatState.new)
    assert_equal :short_link, action
  end

  def test_detects_youtube
    action = @router.detect_action(text: "https://youtu.be/abc123", document: nil, state: ProgrammerHelperBot::ChatState.new)
    assert_equal :youtube, action
  end

  def test_detects_file
    action = @router.detect_action(text: nil, document: Object.new, state: ProgrammerHelperBot::ChatState.new)
    assert_equal :file_stats, action
  end

  def test_shorten_youtube_url_prioritized_as_short_link
    action = @router.detect_action(text: "shorten https://www.youtube.com/watch?v=abc123", document: nil, state: ProgrammerHelperBot::ChatState.new)
    assert_equal :short_link, action
  end

  def test_detects_raw_link_when_waiting_for_short_link
    state = ProgrammerHelperBot::ChatState.new(mode: "awaiting_short_link")
    action = @router.detect_action(text: "https://example.com", document: nil, state: state)
    assert_equal :short_link, action
  end

  def test_detects_raw_python_when_waiting_for_python
    state = ProgrammerHelperBot::ChatState.new(mode: "awaiting_python")
    action = @router.detect_action(text: "print(40+2)", document: nil, state: state)
    assert_equal :python, action
  end
end
