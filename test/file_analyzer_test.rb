require_relative "test_helper"

class FileAnalyzerTest < Minitest::Test
  def setup
    @analyzer = ProgrammerHelperBot::FileAnalyzer.new
  end

  def test_python_file_stats
    content = <<~PY
      import os
      from sys import argv
      print("hello")
    PY

    result = @analyzer.analyze(content, "sample.py")
    assert_equal 3, result[:lines]
    assert_equal content.length, result[:characters]
    assert_equal 2, result[:imports]
  end

  def test_text_file_has_zero_imports
    result = @analyzer.analyze("a\nb\n", "note.txt")
    assert_equal 2, result[:lines]
    assert_equal 0, result[:imports]
  end
end
