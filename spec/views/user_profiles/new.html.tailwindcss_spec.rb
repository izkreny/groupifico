require 'rails_helper'

RSpec.describe "user_profiles/new", type: :view do
  before(:each) do
    assign(:user_profile, UserProfile.new())
  end

  it "renders new user_profile form" do
    render

    assert_select "form[action=?][method=?]", user_profiles_path, "post" do
    end
  end
end
