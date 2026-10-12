require 'rails_helper'

RSpec.describe "Styleguides::Sessions", type: :request do
  describe "POST /styleguide/session" do
    context "when not signed in" do
      it "redirects to the sign-in page and signs nobody in" do
        member = create(:member, group: plant_styleguide_group)

        expect { post "/styleguide/session", params: { member_id: member.id } }.not_to change(Session, :count)
        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in" do
      it "signs in as the picked member's user and returns to the styleguide" do
        member = create(:member, group: plant_styleguide_group)
        sign_in_as(create(:user))

        expect { post "/styleguide/session", params: { member_id: member.id } }.to change { member.user.sessions.count }.by(1)
        expect(response).to redirect_to styleguide_path
      end

      it "ends the session it switched from" do
        member = create(:member, group: plant_styleguide_group)
        developer = create(:user)
        sign_in_as(developer)

        expect { post "/styleguide/session", params: { member_id: member.id } }.to change { developer.sessions.count }.from(1).to(0)
      end

      it "refuses a member of any other group, and signs nobody in as them" do
        plant_styleguide_group
        member = create(:member)
        sign_in_as(create(:user))

        expect { post "/styleguide/session", params: { member_id: member.id } }.not_to change { member.user.sessions.count }
        expect(response).to redirect_to root_path
      end

      # WHY: `Rails.env` stubbed, because the route is drawn only where the environment is local, so this is the one way to reach the action as production would if a route ever drew it there. The path is read through its helper before the stub, which draws the routes if nothing has yet: they load lazily, and a first draw under the stub would be production's for every later example in the process.
      it "answers 404 outside development and test, and signs nobody in" do
        member = create(:member, group: plant_styleguide_group)
        sign_in_as(create(:user))
        path = styleguide_session_path
        allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

        expect { post path, params: { member_id: member.id } }.not_to change { member.user.sessions.count }
        expect(response).to have_http_status :not_found
      end
    end
  end
end
