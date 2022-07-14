# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ::User do
  describe "alias reviewable" do

    let!(:user) do
      user = Fabricate(:user)
      user.upsert_custom_fields(test: 1)
      user.save
      user
    end
    let(:alias1) { Fabricate(:user) }
    let(:alias2) { Fabricate(:user) }

    before do
      user.add_user_alias alias1
      user.add_user_alias alias2
    end

    it "creates reviewable from the shared user record" do
    end
  end
end
