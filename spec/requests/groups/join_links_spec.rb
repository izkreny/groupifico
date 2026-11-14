require 'rails_helper'

RSpec.describe "Groups::JoinLinks", type: :request do
  describe "POST /groups/:group_id/join_link" do
    context "when not signed in" do
      it "redirects to the sign-in page and mints nothing" do
        group = create(:group)

        expect { post group_join_link_path(group) }.not_to change(JoinLink, :count)
        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and leaves the link working" do
        group = create(:group)
        token = JoinLink.mint(group)
        sign_in_as(create(:user))

        post group_join_link_path(group)

        expect(response).to have_http_status :not_found
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as the owner" do
      # WHY: #445 AC1, since the members page it lands on is where the owner copies the link from.
      it "creates the link and lands on the members page" do
        actor = create(:member, :active, :owner)
        sign_in_as(actor.user)

        expect { post group_join_link_path(actor.group) }.to change { JoinLink.where(group: actor.group).count }.from(0).to(1)
        expect(response).to redirect_to group_members_path(actor.group)
      end

      # WHY: #445 AC3, since regenerating is what retires a link that travelled too far.
      it "regenerates the link, retiring the one before it" do
        actor = create(:member, :active, :owner)
        old_token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        post group_join_link_path(actor.group)

        expect(JoinLink.find_by_token(old_token)).to be_nil
        expect(JoinLink.where(group: actor.group)).to exist
      end
    end

    # WHY: #445 AC4, one context per Group table column the join link row leaves blank, and a paused owner, since the row is a write.
    context "when signed in as an administrator" do
      it "refuses and leaves the link working" do
        actor = create(:member, :active, :administrator)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        post group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as an events administrator" do
      it "refuses and leaves the link working" do
        actor = create(:member, :active, :events_administrator)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        post group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as a members administrator" do
      it "refuses and leaves the link working" do
        actor = create(:member, :active, :members_administrator)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        post group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses and leaves the link working" do
        actor = create(:member, :active)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        post group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as a paused owner" do
      it "refuses and leaves the link working" do
        actor = create(:member, :paused, :owner)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        post group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end
  end

  describe "DELETE /groups/:group_id/join_link" do
    context "when not signed in" do
      it "redirects to the sign-in page and leaves the link working" do
        group = create(:group)
        token = JoinLink.mint(group)

        delete group_join_link_path(group)

        expect(response).to redirect_to new_session_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and leaves the link working" do
        group = create(:group)
        token = JoinLink.mint(group)
        sign_in_as(create(:user))

        delete group_join_link_path(group)

        expect(response).to have_http_status :not_found
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as the owner" do
      # WHY: #445 AC2, since deleting the link is what an owner does to stop it working.
      it "deletes the link" do
        actor = create(:member, :active, :owner)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        delete group_join_link_path(actor.group)

        expect(response).to redirect_to group_members_path(actor.group)
        expect(JoinLink.find_by_token(token)).to be_nil
      end

      it "answers 303, so the redirect is followed with a GET" do
        actor = create(:member, :active, :owner)
        JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        delete group_join_link_path(actor.group)

        expect(response).to have_http_status :see_other
      end

      it "lands on the members page when there is no link to delete" do
        actor = create(:member, :active, :owner)
        sign_in_as(actor.user)

        delete group_join_link_path(actor.group)

        expect(response).to redirect_to group_members_path(actor.group)
      end
    end

    # WHY: #445 AC4, as for POST above.
    context "when signed in as an administrator" do
      it "refuses and leaves the link working" do
        actor = create(:member, :active, :administrator)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        delete group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as an events administrator" do
      it "refuses and leaves the link working" do
        actor = create(:member, :active, :events_administrator)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        delete group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as a members administrator" do
      it "refuses and leaves the link working" do
        actor = create(:member, :active, :members_administrator)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        delete group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses and leaves the link working" do
        actor = create(:member, :active)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        delete group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end

    context "when signed in as a paused owner" do
      it "refuses and leaves the link working" do
        actor = create(:member, :paused, :owner)
        token = JoinLink.mint(actor.group)
        sign_in_as(actor.user)

        delete group_join_link_path(actor.group)

        expect(response).to redirect_to root_path
        expect(JoinLink.find_by_token(token)).to be_present
      end
    end
  end
end
