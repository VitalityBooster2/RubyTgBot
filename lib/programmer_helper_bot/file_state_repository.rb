# frozen_string_literal: true

require 'json'
require 'fileutils'

module ProgrammerHelperBot
  class FileStateRepository
    def initialize(path:)
      @path = path
      ensure_storage!
    end

    def load(chat_id)
      store = read_store
      ChatState.from_h(store[chat_id.to_s])
    end

    def save(chat_id, state)
      store = read_store
      store[chat_id.to_s] = state.to_h
      write_store(store)
    end

    private

    def ensure_storage!
      directory = File.dirname(@path)
      FileUtils.mkdir_p(directory)
      return if File.exist?(@path)

      write_store({})
    end

    def read_store
      content = File.read(@path)
      JSON.parse(content)
    rescue Errno::ENOENT, JSON::ParserError
      {}
    end

    def write_store(store)
      File.write(@path, JSON.pretty_generate(store))
    end
  end
end
