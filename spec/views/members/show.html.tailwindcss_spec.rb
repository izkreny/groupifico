require 'rails_helper'

RSpec.describe "members/show", type: :view do
  before(:each) do
    assign(:member, Member.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
