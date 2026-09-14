require 'rails_helper'

RSpec.describe "User", type: :request do
  # Router redirects, answered before `require_authentication` runs, so there is no signed-in and
  # signed-out pair to assert: no action sits behind either path to be signed in to. A signed-out
  # visitor reaches the sign-in page one hop later, from the profile's own guard.
  describe "GET /user" do
    it "redirects to the Me screen" do
      get "/user"

      expect(response).to redirect_to user_profile_path
    end
  end

  describe "GET /user/edit" do
    it "redirects to the Edit me screen" do
      get "/user/edit"

      expect(response).to redirect_to edit_user_profile_path
    end
  end

  describe "DELETE /user" do
    context "when not signed in" do
      it "redirects to the login page" do
        create(:user)

        expect { delete user_path }
          .not_to change(User, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "destroys the user" do
        sign_in_as(create(:user))

        expect { delete user_path }
          .to change(User, :count).by(-1)

        # Known-wrong target: destroying the user destroys their session too,
        # so `user_path` can never render for them. #179 fixes the controller.
        expect(response).to redirect_to user_path
      end

      it "refuses while the reader is a group's only active owner, and says nothing happened" do
        member = create(:member, :owner)
        sign_in_as(member.user)

        expect { delete user_path }
          .not_to change(User, :count)

        expect(response).to redirect_to user_profile_path
        expect(flash[:alert]).to eq "Your account was not deleted."
      end

      it "destroys the user when every group they own has another active owner" do
        member = create(:member, :owner)
        create(:member, :owner, group: member.group)
        sign_in_as(member.user)

        expect { delete user_path }
          .to change(User, :count).by(-1)

        expect(response).to redirect_to user_path
      end
    end
  end
end
