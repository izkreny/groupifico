require 'rails_helper'

RSpec.describe "user_profiles/show", type: :view do
  before(:each) do
    assign(:user_profile, UserProfile.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
