# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ::User do

  describe "aliased user flag limits" do

    let!(:user) do
      user = Fabricate(:user)
      user.save
      user
    end

    fab!(:post) { Fabricate(:post) }
    let(:topic) { public_post.topic }

    let(:alias1) { Fabricate(:user) }
    let(:alias2) { Fabricate(:user) }
    let(:other_user) { Fabricate(:user) }

    before do
      user.add_user_alias alias1
      user.add_user_alias alias2
    end

    it "shares flagging limits between all aliases" do
      result = PostActionCreator.create(alias1, post, :inappropriate)
      reviewable = result.reviewable
      expect(result.success?).to eq(true)
      result = PostActionCreator.create(alias2, post, :inappropriate)

      PostAction.alias_counts_for([post], alias1)

      expect(result.success?).to eq(false)
      expect(reviewable.reviewable_scores.count).to eq(1)
    end

  end
end
