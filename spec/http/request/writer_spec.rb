# coding: utf-8

require 'spec_helper'

describe HTTP::Request::Writer do
  describe '#initalize' do
    def construct(body)
      HTTP::Request::Writer.new(nil, body, [], '')
    end

    it "doesn't throw on a nil body" do
      expect { construct nil }.not_to raise_error
    end

    it "doesn't throw on a String body" do
      expect { construct 'string body' }.not_to raise_error
    end

    it "doesn't throw on an Enumerable body" do
      expect { construct %w[bees cows] }.not_to raise_error
    end

    it "does throw on a body that isn't string, enumerable or nil" do
      expect { construct true }.to raise_error
    end

    it 'writes a chunked request from an Enumerable correctly' do
      io = StringIO.new
      writer = HTTP::Request::Writer.new(io, %w[bees cows], [], '')
      writer.send_request_body
      io.rewind
      expect(io.string).to eq "4\r\nbees\r\n4\r\ncows\r\n0\r\n\r\n"
    end
  end

  describe '#add_body_type_headers' do
    it 'properly calculates length of unicode string' do
      writer = HTTP::Request::Writer.new(nil, 'Привет, мир!', {}, '')
      writer.add_body_type_headers
      expect(writer.join_headers).to match(/\r\nContent-Length: 21\r\n/)
    end
  end
end
