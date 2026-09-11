require 'rails_helper'

RSpec.describe "User", type: :request do
  describe "GET /user" do
    context "when not signed in" do
      it "redirects to the login page" do
        get user_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows user page" do
        sign_in_as(create(:user))

        get user_path

        expect(response).to have_http_status :ok
      end

      it "names each group the reader is the only active owner of" do
        member = create(:member, :owner)
        sign_in_as(member.user)

        get user_path

        expect(response.body).to include("You still own #{member.group.name}.")
      end

      it "says nothing where the reader owns no group alone" do
        sign_in_as(create(:member).user)

        get user_path

        expect(response.body).not_to include("You still own")
      end
    end
  end

  describe "GET /user/edit" do
    context "when not signed in" do
      it "redirects to the login page" do
        get edit_user_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows edit user page" do
        sign_in_as(create(:user))

        get edit_user_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "PATCH /user" do
    context "when not signed in" do
      it "redirects to the login page" do
        patch user_path, params: { user: { email: "changed@example.com" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "updates the user" do
        user = create(:user)
        sign_in_as(user)

        patch user_path, params: { user: { email: "changed@example.com" } }

        expect(response).to redirect_to user_path
        expect(user.reload.email).to eq "changed@example.com"
      end
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

        expect(response).to redirect_to user_path
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
