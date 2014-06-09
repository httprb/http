require 'spec_helper'

RSpec.describe URI do
  describe '.encode_www_form' do
    it 'properly encodes arrays' do
      expect(URI.encode_www_form :a => [:b, :c]).to eq 'a=b&a=c'
    end
  end
end
