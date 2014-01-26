require 'time'
require 'forwardable'

class ExampleResponse
  extend Forwardable
  def_delegators :@headers, :[], :[]=
  attr_accessor  :status, :version, :date, :body

  def initialize(status = 200, body_or_headers = nil, body = nil)
    @status  = status.to_i
    @version = "1.1"
    @date    = Time.now.utc.rfc2822

    if body_or_headers.is_a?(Hash)
      headers = body_or_headers.dup
      @body   = body.to_s
    else
      headers = {}
      @body   = body_or_headers.to_s
    end

    @headers = {
      'Content-Type'  => 'text/html',
      'Date'          => @date,
      'Server'        => 'example_response.rb'
    }.merge(headers)
  end

  def to_s
    if body && !@headers['Content-Length']
      @headers['Content-Length'] = @body.length
    end

    "HTTP/#{version} #{status} #{HTTP::Response::STATUS_CODES[status]}\r\n" <<
    @headers.map { |k, v| "#{k}: #{v}" }.join("\r\n") << "\r\n\r\n" <<
    (body || '')
  end
end
