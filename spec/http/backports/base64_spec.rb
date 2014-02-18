require 'spec_helper'

describe Base64 do
  specify { expect(Base64).to respond_to :strict_encode64 }

  describe '.strict_encode64' do
    let(:long_string) { (0...256).map { ('a'..'z').to_a[rand(26)] }.join }

    it 'returns a String without whitespaces' do
      expect(Base64.strict_encode64 long_string).to_not match(/\s/)
    end
  end
end
