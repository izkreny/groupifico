require 'rails_helper'

RSpec.describe "user_profiles/edit", type: :view do
  let(:user_profile) {
    UserProfile.create!()
  }

  before(:each) do
    assign(:user_profile, user_profile)
  end

  it "renders the edit user_profile form" do
    render

    assert_select "form[action=?][method=?]", user_profile_path(user_profile), "post" do
    end
  end
end
