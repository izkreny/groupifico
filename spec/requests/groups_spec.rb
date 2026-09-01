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

      it "lists only the groups the acting user belongs to" do
        member = create(:member)
        other_group = create(:group) # the acting user does not belong to this one
        sign_in_as(member.user)

        get groups_path

        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(member.group))
        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(other_group))
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

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get group_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the group page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a paused member" do
      it "shows the group page" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response).to have_http_status :ok
      end

      it "reads successfully and writes unsuccessfully for the same member" do
        member = create(:member, :paused, group: create(:group, name: "Original"))
        sign_in_as(member.user)

        get group_path(member.group)
        expect(response).to have_http_status :ok

        patch group_path(member.group), params: { group: { name: "Renamed" } }
        expect(response).to redirect_to root_path
        expect(member.group.reload.name).to eq "Original"
      end
    end

    context "when signed in as an inactive member" do
      it "returns 404, exactly like a non-member" do
        member = create(:member, :inactive)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response).to have_http_status :not_found
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

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get edit_group_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an owner" do
      it "shows the edit group page" do
        member = create(:member, :active, :owner)
        sign_in_as(member.user)

        get edit_group_path(member.group)

        expect(response).to have_http_status :ok
      end

      # Opening the form is a read, so the status pre-check lets a paused owner through and stops
      # them at the submission instead. `edit?` therefore answers `membership.owner?` under its own
      # name rather than through an alias or a `check?`, both of which rename the running rule to
      # `update?` and refuse this.
      it "shows the edit group page to a paused owner, who is stopped at the submission" do
        member = create(:member, :paused, :owner)
        sign_in_as(member.user)

        get edit_group_path(member.group)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a member who does not own the group" do
      it "refuses an administrator with a redirect rather than a 404" do
        member = create(:member, :active, :administrator)
        sign_in_as(member.user)

        get edit_group_path(member.group)

        expect(response).to redirect_to root_path
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

      it "creates a Member joining the acting user to the group with the owner role" do
        user = create(:user)
        sign_in_as(user)

        expect { post groups_path, params: { group: { name: "Choraliers" } } }
          .to change(Member, :count).by(1)

        member = Member.sole
        expect(member.user).to eq user
        expect(member.group).to eq Group.sole
        expect(member.roles.map(&:name)).to eq [ "owner" ]
      end

      it "lands the creator on the group page instead of a 404" do
        sign_in_as(create(:user))

        post groups_path, params: { group: { name: "Choraliers" } }
        follow_redirect!

        expect(response).to have_http_status :ok
      end

      it "responds :unprocessable_content and creates no records when the group is invalid" do
        sign_in_as(create(:user))

        group_count  = Group.count
        member_count = Member.count

        post groups_path, params: { group: { name: "" } }

        expect(Group.count).to eq group_count
        expect(Member.count).to eq member_count
        expect(response).to have_http_status :unprocessable_content
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

    context "when signed in as a non-member" do
      it "returns 404 and leaves the group unchanged" do
        group = create(:group, name: "Original")
        sign_in_as(create(:user))

        patch group_path(group), params: { group: { name: "Renamed" } }

        expect(response).to have_http_status :not_found
        expect(group.reload.name).to eq "Original"
      end
    end

    context "when signed in as an owner" do
      it "updates the group" do
        member = create(:member, :active, :owner)
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to group_path(member.group)
        expect(member.group.reload.name).to eq "Renamed"
      end

      it "re-renders the edit page when the group is invalid" do
        member = create(:member, :active, :owner)
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "" } }

        expect(response).to have_http_status :unprocessable_content
      end
    end

    # The distinction ADR 0003 records, and the one the role rules add: a non-member is told
    # nothing and gets the 404 above, while a member who lacks the role is refused plainly. The
    # refusal is the redirect every other denial gets rather than a bare 403 status, because a
    # refused Turbo submission that lands back on its own form looks like a dead button.
    context "when signed in as a member who does not own the group" do
      it "refuses an ordinary member, and does not answer as a missing record does" do
        member = create(:member, :active, group: create(:group, name: "Original"))
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(member.group.reload.name).to eq "Original"
      end

      it "refuses an administrator, who administers members and not the group itself" do
        member = create(:member, :active, :administrator, group: create(:group, name: "Original"))
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(member.group.reload.name).to eq "Original"
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and leaves the group unchanged" do
        member = create(:member, :paused, group: create(:group, name: "Original"))
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(member.group.reload.name).to eq "Original"
      end

      # The submit arrives from the page that refuses it, which is what a browser actually sends and
      # what an earlier redirect_back_or_to got wrong: the referer is the edit form, so the refused
      # member landed back on it and the button looked dead. Setting HTTP_REFERER is the only way a
      # request spec sees that at all.
      it "does not send the refused member back to the page that refused them" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        patch group_path(member.group),
          params: { group: { name: "Renamed" } },
          headers: { "HTTP_REFERER" => edit_group_url(member.group) }

        expect(response).to redirect_to root_path
      end

      # Asserting the rendered page, not flash[:alert]. The value was present in the hash for months
      # while layouts/_flash rendered only `notice`, so every alert in this application was set and
      # silently dropped - the refusal, and the sign-in rate limiter alongside it.
      it "shows the refusal to the member after the redirect" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }
        follow_redirect!

        expect(response.body).to include "You are not allowed to do that."
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

    context "when signed in as a non-member" do
      it "returns 404 and does not destroy the group" do
        group = create(:group)
        sign_in_as(create(:user))

        expect { delete group_path(group) }
          .not_to change(Group, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an owner" do
      it "destroys the group" do
        member = create(:member, :active, :owner)
        sign_in_as(member.user)

        expect { delete group_path(member.group) }
          .to change(Group, :count).by(-1)

        expect(response).to redirect_to groups_path
      end
    end

    context "when signed in as a member who does not own the group" do
      it "refuses an administrator and does not destroy the group" do
        member = create(:member, :active, :administrator)
        sign_in_as(member.user)

        expect { delete group_path(member.group) }
          .not_to change(Group, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not destroy the group" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        expect { delete group_path(member.group) }
          .not_to change(Group, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  # The refusal and a genuinely missing record must be the same response, not merely the same
  # status. `head :not_found` sent zero bytes while an absent id renders the 404 page, so the two
  # were trivially distinguishable by body length and the existence oracle ADR 0003 chose 404 over
  # 403 to close stayed open.
  describe "a refused group and a missing one" do
    # Rendered the way production renders, because the test environment does not: it answers both
    # with its debug page, and two different exceptions produce two different debug pages, so the
    # comparison would fail for a reason that has nothing to do with the oracle. Production renders
    # public/404.html for both, which is the whole point of raising rather than `head`. Restored in
    # an ensure so the suite still passes in any order.
    around do |example|
      original = Rails.application.env_config.slice(
        "action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions"
      )
      Rails.application.env_config["action_dispatch.show_exceptions"] = :all
      Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

      example.run
    ensure
      Rails.application.env_config.merge!(original)
    end

    it "answer identically" do
      non_member = create(:member)
      sign_in_as(non_member.user)

      get group_path(create(:group))
      refused = [ response.status, response.body.bytesize ]

      get "/groups/#{Group.maximum(:id) + 1}"
      missing = [ response.status, response.body.bytesize ]

      expect(refused).to eq missing
    end
  end


  # A relation_scope is not a rule, so the pre-checks never run for it: every scope asked
  # `user.groups`, which is every group ever joined. The list leaked what the detail page refused.
  describe "an inactive member's group list" do
    it "does not include the group they left" do
      actor = create(:member, :inactive, group: create(:group, name: "Left Behind"))
      sign_in_as(actor.user)

      get groups_path

      # dom_id rather than the name: `_group.html.erb` renders `group.name.upcase`, so asserting
      # the name passes against a page that lists the group in capitals. Watched doing exactly
      # that, with the defect fully restored.
      expect(response.body).not_to include "group_#{actor.group_id}"
    end
  end
end
