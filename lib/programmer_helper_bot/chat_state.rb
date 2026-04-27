module ProgrammerHelperBot
  class ChatState
    attr_reader :mode

    def initialize(mode: "idle")
      @mode = mode.to_s
    end

    def with_mode(new_mode)
      self.class.new(mode: new_mode)
    end

    def idle?
      @mode == "idle"
    end

    def to_h
      { "mode" => @mode }
    end

    def self.from_h(data)
      return new unless data.is_a?(Hash)

      new(mode: data["mode"] || "idle")
    end
  end
end
