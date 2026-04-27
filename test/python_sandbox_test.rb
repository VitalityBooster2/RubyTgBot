require_relative "test_helper"

class PythonSandboxTest < Minitest::Test
  def test_executes_code
    sandbox = ProgrammerHelperBot::PythonSandbox.new(timeout_seconds: 2)
    result = sandbox.execute("print(2+2)")

    assert_equal true, result[:ok]
    assert_equal "4", result[:stdout]
  end

  def test_timeout
    sandbox = ProgrammerHelperBot::PythonSandbox.new(timeout_seconds: 1)
    result = sandbox.execute("while True: pass")

    assert_equal false, result[:ok]
    assert_match(/timed out/i, result[:stderr])
  end
end
