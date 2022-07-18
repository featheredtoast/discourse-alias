# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ::User do
  describe "aliased trust level" do

    let!(:user) do
      user = Fabricate(:user)
      user.save
      user
    end
    let(:alias1) { Fabricate(:user) }
    let(:alias2) { Fabricate(:user) }
    let(:other_user) { Fabricate(:user) }

    before do
      user.add_user_alias alias1
      user.add_user_alias alias2
    end

    it "finds trust level from the base record" do
      user.trust_level = TrustLevel[4]
      user.save!
      expect(user.has_trust_level?(TrustLevel[3])).to be_truthy
      expect(alias1.has_trust_level?(TrustLevel[3])).to be_truthy
    end

    it "returns the correct trust level in serializers" do
      user.trust_level = TrustLevel[4]
      user.save!
      json = UserCardSerializer.new(alias1, scope: Guardian.new(alias1), root: false).as_json
      expect(json[:trust_level]).to eq(4)
    end

    it "calculates the trust level based on alias activity" do
    end
  end
end
