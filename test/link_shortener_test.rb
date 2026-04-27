require_relative "test_helper"

class LinkShortenerTest < Minitest::Test
  def setup
    @shortener = ProgrammerHelperBot::LinkShortener.new
  end

  def test_shorten_success
    stub_request(:get, "https://tinyurl.com/api-create.php?url=https%3A%2F%2Fexample.com")
      .to_return(status: 200, body: "https://tinyurl.com/abc123")

    result = @shortener.shorten("https://example.com")
    assert_equal "https://tinyurl.com/abc123", result
  end

  def test_invalid_url
    assert_raises(ArgumentError) { @shortener.shorten("not_url") }
  end
end
