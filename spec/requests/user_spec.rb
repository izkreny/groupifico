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
    end
  end

  describe "GET /user/new" do
    context "when not signed in" do
      it "redirects to the login page" do
        get new_user_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows new user page" do
        sign_in_as(create(:user))

        get new_user_path

        expect(response).to have_http_status :ok
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

  describe "POST /user" do
    let (:user_attributes) { attributes_for(:user) }

    context "when not signed in" do
      it "redirects to the login page" do
        post user_path params: { user: user_attributes }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "creates new user" do
        sign_in_as(create(:user))

        expect { post user_path params: { user: user_attributes } }
          .to change(User, :count).by(1)

        expect(response).to redirect_to user_path
      end
    end
  end

  describe "PATCH /user" do
    let! (:user)                { create(:user) }
    let  (:new_user_attributes) { attributes_for(:user) }

    context "when not signed in" do
      it "redirects to the login page" do
        patch user_path params: { user: new_user_attributes }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "update user" do
        sign_in_as(user)

        patch user_path params: { user: new_user_attributes }

        expect(response).to redirect_to user_path
        expect(user.reload.email).to eq new_user_attributes[:email]
      end
    end
  end

  describe "DELETE /user" do
    let! (:user) { create(:user) }

    context "when not signed in" do
      it "redirects to the login page" do
        expect { delete user_path }
          .not_to change(User, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "creates new user" do
        sign_in_as(user)

        expect { delete user_path }
          .to change(User, :count).by(-1)

        expect(response).to redirect_to user_path
      end
    end
  end
end
