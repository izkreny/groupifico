require 'rails_helper'

RSpec.describe "registrations/edit", type: :view do
  let(:registration) {
    Registration.create!()
  }

  before(:each) do
    assign(:registration, registration)
  end

  it "renders the edit registration form" do
    render

    assert_select "form[action=?][method=?]", registration_path(registration), "post" do
    end
  end
end
