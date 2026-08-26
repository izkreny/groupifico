require 'rails_helper'

RSpec.describe "Groups", type: :request do
  describe "GET /groups" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get groups_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the groups page" do
        sign_in_as(create(:user))

        get groups_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /groups/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get group_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the group page" do
        sign_in_as(create(:user))

        get group_path(create(:group))

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /groups/new" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get new_group_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the new group page" do
        sign_in_as(create(:user))

        get new_group_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /groups/:id/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get edit_group_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the edit group page" do
        sign_in_as(create(:user))

        get edit_group_path(create(:group))

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "POST /groups" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        post groups_path, params: { group: { name: "Choraliers" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "creates the group" do
        sign_in_as(create(:user))

        expect { post groups_path, params: { group: { name: "Choraliers" } } }
          .to change(Group, :count).by(1)

        expect(response).to redirect_to group_path(Group.sole)
      end

      it "re-renders the new page when the group is invalid" do
        sign_in_as(create(:user))

        expect { post groups_path, params: { group: { name: "" } } }
          .not_to change(Group, :count)

        expect(response).to have_http_status :unprocessable_entity
      end
    end
  end

  describe "PATCH /groups/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        patch group_path(create(:group)), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "updates the group" do
        group = create(:group)
        sign_in_as(create(:user))

        patch group_path(group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to group_path(group)
        expect(group.reload.name).to eq "Renamed"
      end

      it "re-renders the edit page when the group is invalid" do
        group = create(:group)
        sign_in_as(create(:user))

        patch group_path(group), params: { group: { name: "" } }

        expect(response).to have_http_status :unprocessable_entity
      end
    end
  end

  describe "DELETE /groups/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        create(:group)

        expect { delete group_path(Group.sole) }
          .not_to change(Group, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "destroys the group" do
        group = create(:group)
        sign_in_as(create(:user))

        expect { delete group_path(group) }
          .to change(Group, :count).by(-1)

        expect(response).to redirect_to groups_path
      end
    end
  end
end
