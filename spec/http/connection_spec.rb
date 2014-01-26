require 'spec_helper'

describe HTTP::Connection do
  let(:fixture_path) { File.expand_path("../../fixtures/example.txt", __FILE__) }

  it "reads responses without bodies" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)
      client << ExampleResponse.new.to_s
      response = connection.current_response

      response.url.should     eq "/"
      response.version.should eq "1.1"

      response['Host'].should eq "www.example.com"
      response['Connection'].should eq "keep-alive"
      response['User-Agent'].should eq "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.78 S"
      response['Accept'].should eq "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      response['Accept-Encoding'].should eq "gzip,deflate,sdch"
      response['Accept-Language'].should eq "en-US,en;q=0.8"
      response['Accept-Charset'].should eq "ISO-8859-1,utf-8;q=0.7,*;q=0.3"
    end
  end

  it "reads responses with bodies" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)
      body = "Hello, world!"
      example_response = ExampleResponse.new
      example_response.body = body

      client << example_response.to_s
      response = connection.current_response

      response.url.should     eq "/"
      response.version.should eq "1.1"
      response['Content-Length'].should eq body.length.to_s
      response.body.to_s.should eq example_response.body
    end
  end

  it "reads responses with large bodies" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)
      client << ExampleResponse.new.to_s
      response = connection.current_response

      fixture_text = File.read(fixture_path)
      File.open(fixture_path) do |file|
        connection.respond :ok, file
        connection.close
      end

      response = client.read(4096)
      response[(response.length - fixture_text.length)..-1].should eq fixture_text
    end
  end

  it "enumerates responses with #each_response" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)
      client << ExampleResponse.new.to_s

      response_count = 0
      connection.each_response do |response|
        response_count += 1
        response.url.should eq "/"
        response.respond :ok
        client.close
      end

      response_count.should eq 1
    end
  end

  context "streams responses when transfer-encoding is chunked" do
    def test_chunked_response(response, client)
      # Sending transfer_encoding chunked without a body enables streaming mode
      response.respond :ok, :transfer_encoding => :chunked

      # This will send individual chunks
      response << "Hello"
      response << "World"
      response.finish_response # Write trailer and reset connection to header mode

      response = ""

      begin
        while chunk = client.readpartial(4096)
          response << chunk
          break if response =~ /0\r\n\r\n$/
        end
      rescue EOFError
      end

      crlf = "\r\n"
      fixture = "5#{crlf}Hello#{crlf}5#{crlf}World#{crlf}0#{crlf*2}"
      response[(response.length - fixture.length)..-1].should eq fixture
    end
    
    it "with keep-alive" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        client << ExampleResponse.new.to_s
        response = connection.current_response

        test_chunked_response(response, client)
        connection.close
      end
    end

    it "without keep-alive" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        client << ExampleResponse.new.tap{ |r|
          r['Connection'] = 'close'
        }.to_s
        response = connection.current_response

        test_chunked_response(response, client)
        connection.close
      end
    end

    it "with pipelined responses" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)

        2.times do
          client << ExampleResponse.new.to_s
        end
        client << ExampleResponse.new.tap { |r|
          r['Connection'] = 'close'
        }.to_s

        3.times do
          response = connection.current_response
          test_chunked_response(response, client)
        end
        connection.close
      end
    end
  end
  
  it "reset the response after a response is sent" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)
      example_response = ExampleResponse.new(:get, "/", "1.1", {'Connection' => 'close'})
      client << example_response

      connection.current_response.should_not be_nil

      connection.respond :ok, "Response sent"

      connection.current_response.should be_nil
    end
  end

  it "raises an error trying to read two pipelines without responding first" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)

      2.times do
        client << ExampleResponse.new.to_s
      end

      expect do
        2.times { response = connection.current_response }
      end.to raise_error(HTTP::StateError)
    end
  end

  it "reads pipelined responses without bodies" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)

      3.times { client << ExampleResponse.new.to_s }

      3.times do
        response = connection.current_response

        response.url.should     eq "/"
        response.version.should eq "1.1"

        response['Host'].should eq "www.example.com"
        response['Connection'].should eq "keep-alive"
        response['User-Agent'].should eq "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.78 S"
        response['Accept'].should eq "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        response['Accept-Encoding'].should eq "gzip,deflate,sdch"
        response['Accept-Language'].should eq "en-US,en;q=0.8"
        response['Accept-Charset'].should eq "ISO-8859-1,utf-8;q=0.7,*;q=0.3"
        connection.respond :ok, {}, ""
      end
    end
  end

  it "reads pipelined responses with bodies" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)

      3.times do |i|
        body = "Hello, world number #{i}!"
        example_response = ExampleResponse.new
        example_response.body = body

        client << example_response.to_s
      end

      3.times do |i|
        response = connection.current_response

        expected_body = "Hello, world number #{i}!"
        response.url.should     eq "/"
        response.version.should eq "1.1"
        response['Content-Length'].should eq expected_body.length.to_s
        response.body.to_s.should eq expected_body

        connection.respond :ok, {}, ""
      end
    end
  end

  it "reads pipelined responses with streamed bodies" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer, 4)

      3.times do |i|
        body = "Hello, world number #{i}!"
        example_response = ExampleResponse.new
        example_response.body = body

        client << example_response.to_s
      end

      3.times do |i|
        response = connection.current_response

        expected_body = "Hello, world number #{i}!"
        response.url.should     eq "/"
        response.version.should eq "1.1"
        response['Content-Length'].should eq expected_body.length.to_s
        response.should_not be_finished_reading
        new_content = ""
        while chunk = response.body.readpartial(1)
          new_content << chunk
        end
        new_content.should == expected_body
        response.should be_finished_reading

        connection.respond :ok, {}, ""
      end
    end
  end

  # This test will deadlock rspec waiting unless
  # connection.current_response works properly
  it "does not block waiting for body to read before handling response" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)
      example_response = ExampleResponse.new

      content = "Hi guys! Sorry I'm late to the party."
      example_response['Content-Length'] = content.length
      client << example_response.to_s

      response = connection.current_response
      response.should be_a(HTTP::Response)
      client << content
      response.body.to_s.should == content
    end
  end

  it "blocks on read until written" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)
      example_response = ExampleResponse.new

      content = "Hi guys! Sorry I'm late to the party."
      example_response['Content-Length'] = content.length
      client << example_response.to_s

      response = connection.current_response
      timers = Timers.new
      timers.after(0.2){
        client << content
      }
      read_body = ""
      timers.after(0.1){
        timers.wait # continue timers, the next bit will block waiting for content
        read_body = response.read(8)
      }
      timers.wait

      response.should be_a(HTTP::Response)
      read_body.should == content[0..7]
    end
  end

  it "streams body properly with #read and buffered body" do
    with_socket_pair do |client, peer|
      connection = HTTP::Connection.new(peer)
      example_response = ExampleResponse.new

      content = "I'm data you can stream!"
      example_response['Content-Length'] = content.length
      client << example_response.to_s

      response = connection.current_response
      response.should be_a(HTTP::Response)
      response.should_not be_finished_reading
      client << content
      rebuilt = []
      connection.readpartial(64) # Buffer some body
      while chunk = response.read(8)
        rebuilt << chunk
      end
      response.should be_finished_reading
      rebuilt.should == ["I'm data", " you can", " stream!"]
    end
  end

  context "#readpartial" do
    it "streams response bodies" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer, 8)
        example_response = ExampleResponse.new

        content = "I'm data you can stream!"
        example_response['Content-Length'] = content.length
        client << example_response.to_s

        response = connection.current_response
        response.should be_a(HTTP::Response)
        response.should_not be_finished_reading
        client << content
        rebuilt = []
        while chunk = response.body.readpartial(8)
          rebuilt << chunk
        end
        response.should be_finished_reading
        rebuilt.should == ["I'm data", " you can", " stream!"]
      end
    end
  end

  context "#each" do
    it "streams response bodies" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        example_response = ExampleResponse.new

        content = "I'm data you can stream!"
        example_response['Content-Length'] = content.length
        client << example_response.to_s

        response = connection.current_response
        response.should be_a(HTTP::Response)
        response.should_not be_finished_reading
        client << content

        data = ""
        response.body.each { |chunk| data << chunk }
        response.should be_finished_reading
        data.should == "I'm data you can stream!"
      end
    end
  end

  describe "IO#read duck typing" do
    it "raises an exception if length is a negative value" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        example_response = ExampleResponse.new

        client << example_response.to_s
        response = connection.current_response

        lambda { response.read(-1) }.should raise_error(ArgumentError)
      end
    end

    it "returns an empty string if the length is zero" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        example_response = ExampleResponse.new

        client << example_response.to_s
        response = connection.current_response

        response.read(0).should be_empty
      end
    end

    it "reads to EOF if length is nil, even small buffer" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer, 4)
        example_response = ExampleResponse.new
        example_response.body = "Hello, world!"
        connection.buffer_size.should == 4

        client << example_response.to_s
        response = connection.current_response

        response.read.should eq "Hello, world!"
      end
    end

    it "reads to EOF if length is nil" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        example_response = ExampleResponse.new
        example_response.body = "Hello, world!"


        client << example_response.to_s
        response = connection.current_response

        response.read.should eq "Hello, world!"
      end
    end

    it "uses the optional buffer to recieve data" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        example_response = ExampleResponse.new
        example_response.body = "Hello, world!"

        client << example_response.to_s
        response = connection.current_response

        buffer = ''
        response.read(nil, buffer).should eq "Hello, world!"
        buffer.should eq "Hello, world!"
      end
    end

    it "returns with the content it could read when the length longer than EOF" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        example_response = ExampleResponse.new
        example_response.body = "Hello, world!"

        client << example_response.to_s
        response = connection.current_response

        response.read(1024).should eq "Hello, world!"
      end
    end

    it "returns nil at EOF if a length is passed" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        example_response = ExampleResponse.new

        client << example_response.to_s
        response = connection.current_response

        response.read(1024).should be_nil
      end
    end

    it "returns an empty string at EOF if length is nil" do
      with_socket_pair do |client, peer|
        connection = HTTP::Connection.new(peer)
        example_response = ExampleResponse.new

        client << example_response.to_s
        response = connection.current_response

        response.read.should be_empty
      end
    end
  end
end
