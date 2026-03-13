require 'rails_helper'

RSpec.describe "user_profiles/index", type: :view do
  before(:each) do
    assign(:user_profiles, [
      UserProfile.create!(),
      UserProfile.create!()
    ])
  end

  it "renders a list of user_profiles" do
    render
    cell_selector = 'div>p'
  end
end
