# frozen_string_literal: true

require 'uri'
require 'net/http'

module ProgrammerHelperBot
  class LinkShortener
    API_URL = 'https://tinyurl.com/api-create.php'

    def shorten(url)
      validate_url!(url)
      uri = URI(API_URL)
      uri.query = URI.encode_www_form(url: url)
      response = Net::HTTP.get_response(uri)
      raise "TinyURL API error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body.strip
    end

    private

    def validate_url!(url)
      parsed = URI.parse(url)
      return if parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)

      raise ArgumentError, 'Invalid URL'
    rescue URI::InvalidURIError
      raise ArgumentError, 'Invalid URL'
    end
  end
end
