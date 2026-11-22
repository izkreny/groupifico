require 'rails_helper'

RSpec.describe "JoinRequests", type: :request do
  describe "GET /join/new" do
    # WHY: #472 AC1, the join page reaching a signed-out visitor too, so the gate cannot lean on `Current.user` having been resumed.
    context "when signed in without a first name and a mobile" do
      it "sends them to the profile form, carrying the join page to come back to" do
        token = JoinLink.mint(create(:group))
        sign_in_as(create(:user, :not_set_up))

        get new_join_request_path(token:)

        expect(response).to redirect_to edit_user_profile_path(return_to: new_join_request_path(token:))
      end
    end

    context "when not signed in" do
      it "names the group a live link belongs to" do
        token = JoinLink.mint(create(:group, name: "Riverside Choir"))

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("Riverside Choir")
      end

      # WHY: #446 AC1, the form asking for an email alone and carrying the link's token to the submission.
      it "offers a form asking only for an email, posting the link's token to the sign-in link" do
        token = JoinLink.mint(create(:group))

        get new_join_request_path(token:)

        expect(response.body).to include(%(action="#{join_request_sign_in_link_path}"), 'name="user[email]"')
        expect(response.body).to match(/<input type="hidden" name="token" [^>]*value="#{token}"/)
        expect(response.body.scan(/<input(?![^>]*type="hidden")[^>]*>/).size).to eq 1
      end

      # WHY: #445 AC2, since turning the link off is what an owner does to stop it working.
      it "answers 404 for a link that was turned off" do
        group = create(:group)
        token = JoinLink.mint(group)
        group.join_link.destroy!

        get new_join_request_path(token:)

        expect(response).to have_http_status :not_found
      end

      # WHY: #445 AC3, since regenerating retires the link that travelled too far.
      it "answers 404 for a link the group has since regenerated" do
        group = create(:group)
        token = JoinLink.mint(group)
        JoinLink.mint(group)

        get new_join_request_path(token:)

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a token never minted" do
        JoinLink.mint(create(:group))

        get new_join_request_path(token: "never-minted")

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a request carrying no token at all" do
        JoinLink.mint(create(:group))

        get new_join_request_path

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a token sent as a hash" do
        JoinLink.mint(create(:group))

        get new_join_request_path, params: { token: { x: "1" } }

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in" do
      it "names the group a live link belongs to" do
        sign_in_as create(:user)
        token = JoinLink.mint(create(:group, name: "Riverside Choir"))

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("Riverside Choir")
      end

      # WHY: #447 AC1, opening the page is a GET that writes nothing, so a link previewed or opened by accident adds nobody.
      it "adds nobody by opening the page" do
        sign_in_as create(:user)
        token = JoinLink.mint(create(:group))

        expect { get new_join_request_path(token:) }.not_to change(Member, :count)
      end

      # WHY: #447 AC1, the button carries the link's token so pressing it resolves the same link.
      it "offers a visitor with no membership a button asking to join, posting the link's token" do
        sign_in_as create(:user)
        token = JoinLink.mint(create(:group, name: "Riverside Choir"))

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("Ask to join Riverside Choir")
        expect(response.body).to include(%(action="#{join_request_path}"))
        expect(response.body).to match(/<input type="hidden" name="token" value="#{token}"/)
      end

      # WHY: #447 AC4, one example per status, each answered with what it means instead of the button.
      it "tells an active member they are already in the group, offering no button" do
        member = create(:member, :active)
        sign_in_as member.user
        token = JoinLink.mint(member.group)

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("You are already in this group.")
        expect(response.body).not_to include(%(action="#{join_request_path}"))
      end

      it "tells a paused member they are already in the group, offering no button" do
        member = create(:member, :paused)
        sign_in_as member.user
        token = JoinLink.mint(member.group)

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("You are already in this group.")
        expect(response.body).not_to include(%(action="#{join_request_path}"))
      end

      # WHY: #505's one screen, a pending member being somebody invited, so the join link offers them the invitation's Join and Decline rather than a second ask.
      it "offers a pending member the invitation's Join and Decline, and no ask" do
        member = create(:member, :pending)
        sign_in_as member.user
        token = JoinLink.mint(member.group)

        get new_join_request_path(token:)

        methods = Nokogiri::HTML(response.body).css(%(form[action="#{group_invitation_path(member.group)}"] input[name="_method"])).map { it["value"] }
        expect(page_text(response.body)).to include("You are invited to join this group.")
        expect(methods).to eq %w[ patch delete ]
        expect(response.body).not_to include(%(action="#{join_request_path}"))
      end

      it "tells a member who left that only an owner or administrator can bring them back, offering no button" do
        member = create(:member, :inactive)
        sign_in_as member.user
        token = JoinLink.mint(member.group)

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("You left this group. Only an owner or administrator can bring you back.")
        expect(response.body).not_to include(%(action="#{join_request_path}"))
      end

      # WHY: a signed-in visitor has nothing to ask a sign-in link for.
      it "offers no email form" do
        sign_in_as create(:user)
        token = JoinLink.mint(create(:group))

        get new_join_request_path(token:)

        expect(response.body).not_to include(join_request_sign_in_link_path)
      end

      it "answers 404 for a link that was turned off" do
        sign_in_as create(:user)
        group = create(:group)
        token = JoinLink.mint(group)
        group.join_link.destroy!

        get new_join_request_path(token:)

        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "POST /join" do
    context "when not signed in" do
      it "redirects to sign in and adds nobody" do
        token = JoinLink.mint(create(:group))

        expect { post join_request_path(token:) }.not_to change(Member, :count)
        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in" do
      # WHY: #504 AC1, active from the moment they ask rather than pending an approval, and #517 AC1, landing in the group they just joined rather than back on the join page.
      it "adds the visitor to the link's group as an active member and takes them to the group's page" do
        user = create(:user)
        sign_in_as user
        group = create(:group)
        token = JoinLink.mint(group)

        expect { post join_request_path(token:) }.to change { group.members.active.where(user:).count }.from(0).to(1)
        expect(group.members.where(user:).count).to eq 1
        expect(response).to redirect_to group_path(group)
      end

      # WHY: #504 AC2, the group's page answered as it is for any member, rather than with the 404 a pending member gets.
      it "lets the new member open the group's page" do
        sign_in_as create(:user)
        group = create(:group)
        token = JoinLink.mint(group)

        post join_request_path(token:)
        get group_path(group)

        expect(response).to have_http_status :ok
      end

      # WHY: #447 AC4, a second press or a page left open leaves the membership as it is; one example per status, since the inactive one is the member who must not let themselves back in; and #517 AC2, each answered with the join page and no notice that they joined.
      it "leaves an active member as they are" do
        member = create(:member, :active)
        sign_in_as member.user
        token = JoinLink.mint(member.group)

        expect { post join_request_path(token:) }.not_to change(Member, :count)
        expect(member.reload).to be_active
        expect(response).to redirect_to new_join_request_path(token:)
        expect(flash[:notice]).to be_nil
      end

      it "leaves a paused member as they are" do
        member = create(:member, :paused)
        sign_in_as member.user
        token = JoinLink.mint(member.group)

        expect { post join_request_path(token:) }.not_to change(Member, :count)
        expect(member.reload).to be_paused
        expect(response).to redirect_to new_join_request_path(token:)
        expect(flash[:notice]).to be_nil
      end

      it "leaves a pending member as they are" do
        member = create(:member, :pending)
        sign_in_as member.user
        token = JoinLink.mint(member.group)

        expect { post join_request_path(token:) }.not_to change(Member, :count)
        expect(member.reload).to be_pending
        expect(response).to redirect_to new_join_request_path(token:)
        expect(flash[:notice]).to be_nil
      end

      it "leaves a member who left inactive rather than letting them back in" do
        member = create(:member, :inactive)
        sign_in_as member.user
        token = JoinLink.mint(member.group)

        expect { post join_request_path(token:) }.not_to change(Member, :count)
        expect(member.reload).to be_inactive
        expect(response).to redirect_to new_join_request_path(token:)
        expect(flash[:notice]).to be_nil
      end

      # WHY: #447 AC6, the link turned off between opening the page and pressing the button.
      it "answers 404 and adds nobody for a link that was turned off" do
        sign_in_as create(:user)
        group = create(:group)
        token = JoinLink.mint(group)
        group.join_link.destroy!

        expect { post join_request_path(token:) }.not_to change(Member, :count)
        expect(response).to have_http_status :not_found
      end

      # WHY: #447 AC6, the link regenerated between opening the page and pressing the button.
      it "answers 404 and adds nobody for a link the group has since regenerated" do
        sign_in_as create(:user)
        group = create(:group)
        token = JoinLink.mint(group)
        JoinLink.mint(group)

        expect { post join_request_path(token:) }.not_to change(Member, :count)
        expect(response).to have_http_status :not_found
      end

      it "answers 404 and adds nobody for a token never minted" do
        sign_in_as create(:user)
        JoinLink.mint(create(:group))

        expect { post join_request_path(token: "never-minted") }.not_to change(Member, :count)
        expect(response).to have_http_status :not_found
      end
    end
  end
end
