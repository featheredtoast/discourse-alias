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

    context "one alias is tl2 ready" do

      let!(:alias3) { Fabricate(:user, trust_level: TrustLevel[1], created_at: (SiteSetting.tl2_requires_time_spent_mins * 60).minutes.ago) }

      before do
        stat = alias3.user_stat
        stat.topics_entered = SiteSetting.tl2_requires_topics_entered
        stat.posts_read_count = SiteSetting.tl2_requires_read_posts
        stat.time_read = SiteSetting.tl2_requires_time_spent_mins * 60
        stat.days_visited = SiteSetting.tl2_requires_days_visited
        stat.likes_received = SiteSetting.tl2_requires_likes_received
        stat.likes_given = SiteSetting.tl2_requires_likes_given
        SiteSetting.tl2_requires_topic_reply_count = 0

        user.add_user_alias alias3
      end

      it "calculates the trust level based on alias activity" do
        Promotion.new(alias3).review
        expect(alias3.reload.trust_level).to eq(2)
        expect(user.reload.trust_level).to eq(2)
        expect(user.has_trust_level?(TrustLevel[2])).to be_truthy
        expect(alias1.reload.has_trust_level?(TrustLevel[2])).to be_truthy
        expect(alias3.has_trust_level?(TrustLevel[2])).to be_truthy
      end
    end
  end
end
