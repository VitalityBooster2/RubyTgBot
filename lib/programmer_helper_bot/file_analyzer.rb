# frozen_string_literal: true

module ProgrammerHelperBot
  class FileAnalyzer
    PYTHON_IMPORT_REGEX = /^\s*(import\s+[\w.]+|from\s+[\w.]+\s+import\s+.+)\s*$/

    def analyze(content, filename)
      extension = File.extname(filename.to_s).downcase
      imports = extension == '.py' ? count_python_imports(content) : 0

      {
        lines: content.empty? ? 0 : content.lines.count,
        characters: content.length,
        imports: imports
      }
    end

    private

    def count_python_imports(content)
      content.lines.count { |line| line.match?(PYTHON_IMPORT_REGEX) }
    end
  end
end
