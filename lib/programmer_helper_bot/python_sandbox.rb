require 'open3'
require 'timeout'

module ProgrammerHelperBot
  class PythonSandbox
    DEFAULT_TIMEOUT_SECONDS = 3

    def initialize(timeout_seconds: DEFAULT_TIMEOUT_SECONDS)
      @timeout_seconds = timeout_seconds
    end

    def execute(code)
      output = nil
      error = nil
      status = nil

      Timeout.timeout(@timeout_seconds) do
        output, error, status = Open3.capture3('python', '-I', '-S', '-c', code)
      end

      {
        ok: status.success?,
        stdout: output.strip,
        stderr: error.strip
      }
    rescue Timeout::Error
      {
        ok: false,
        stdout: '',
        stderr: 'Execution timed out'
      }
    end
  end
end
