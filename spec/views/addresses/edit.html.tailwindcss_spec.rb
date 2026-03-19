require 'rails_helper'

RSpec.describe "addresses/edit", type: :view do
  let(:address) {
    Address.create!()
  }

  before(:each) do
    assign(:address, address)
  end

  it "renders the edit address form" do
    render

    assert_select "form[action=?][method=?]", address_path(address), "post" do
    end
  end
end
