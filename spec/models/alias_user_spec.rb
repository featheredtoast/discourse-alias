# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ::User do
  describe "alias" do

    let!(:user) do
      user = Fabricate(:user)
      user.upsert_custom_fields(test: 1)
      user.save
      user
    end
    let(:alias1) { Fabricate(:user) }
    let(:alias2) { Fabricate(:user) }

    it "can link and unlink" do
      user.add_user_alias alias1
      user.add_user_alias alias2

      expect(user.aliases).to eq([alias1, alias2])

      user.remove_user_alias alias1

      expect(user.aliases).to eq([alias2])
    end

    it "can find underlying record for an alias" do
      user.add_user_alias alias1
      user.add_user_alias alias2

      expect(alias1.record_for_alias).to eq(user)
    end
  end
end
