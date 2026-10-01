require 'rails_helper'

RSpec.describe "Members", type: :request do
  describe "GET /groups/:group_id/members" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get group_members_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get group_members_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the members page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_members_path(member.group)

        expect(response).to have_http_status :ok
      end

      it "lists only members from groups the acting user belongs to" do
        member = create(:member, :active)
        other_member = create(:member)
        sign_in_as(member.user)

        get group_members_path(member.group)

        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(member))
        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(other_member))
      end

      it "does not say who has not signed in yet" do
        member = create(:member, :active)
        create(:member, group: member.group, user: create(:user, first_signed_in_at: nil))
        sign_in_as(member.user)

        get group_members_path(member.group)

        expect(response.body).not_to include "not signed in yet"
      end
    end

    context "when signed in as a members administrator" do
      it "marks a member who has never signed in" do
        actor = create(:member, :active, :members_administrator)
        added = create(:member, group: actor.group, user: create(:user, first_signed_in_at: nil))
        sign_in_as(actor.user)

        get group_members_path(actor.group)

        row = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(added, :row)}")
        expect(row.text).to include "not signed in yet"
      end

      it "leaves unmarked a member who has signed in" do
        actor  = create(:member, :active, :members_administrator)
        joined = create(:member, group: actor.group, user: create(:user, first_signed_in_at: 1.day.ago))
        sign_in_as(actor.user)

        get group_members_path(actor.group)

        row = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(joined, :row)}")
        expect(row.text).not_to include "not signed in yet"
      end
    end
  end

  describe "GET /groups/:group_id/members/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        get group_member_path(member.group, member)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        member = create(:member)
        sign_in_as(create(:user))

        get group_member_path(member.group, member)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the member page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_member_path(member.group, member)

        expect(response).to have_http_status :ok
      end
    end

    # The mark belongs to the members list alone, per #208's criterion.
    context "when signed in as a members administrator" do
      it "leaves the mark off the page of a member who has never signed in" do
        actor = create(:member, :active, :members_administrator)
        added = create(:member, group: actor.group, user: create(:user, first_signed_in_at: nil))
        sign_in_as(actor.user)

        get group_member_path(actor.group, added)

        expect(response.body).not_to include "not signed in yet"
      end
    end

    context "when signed in as a paused member" do
      it "shows the member page" do
        target = create(:member)
        viewer = create(:member, :paused, group: target.group)
        sign_in_as(viewer.user)

        get group_member_path(target.group, target)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as an inactive member" do
      it "returns 404, exactly like a non-member" do
        target = create(:member)
        viewer = create(:member, :inactive, group: target.group)
        sign_in_as(viewer.user)

        get group_member_path(target.group, target)

        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "GET /groups/:group_id/members/new" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get new_group_member_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get new_group_member_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an owner" do
      it "offers every role as an unticked checkbox" do
        owner = create(:member, :active, :owner)
        sign_in_as(owner.user)

        get new_group_member_path(owner.group)

        boxes = Nokogiri::HTML(response.body).css("input[type=checkbox][name='member[roles][]']")
        expect(boxes.map { it["value"] }).to eq [ "owner", "administrator", "events_administrator", "members_administrator" ]
        expect(boxes.select { it["checked"] }).to be_empty
      end
    end

    context "when signed in as a members administrator" do
      it "asks for the new member's email address" do
        member = create(:member, :active, :members_administrator)
        sign_in_as(member.user)

        get new_group_member_path(member.group)

        expect(Nokogiri::HTML(response.body).css("input[type=email][name='member[email]']")).to be_one
      end

      it "offers no role checkboxes" do
        member = create(:member, :active, :members_administrator)
        sign_in_as(member.user)

        get new_group_member_path(member.group)

        expect(Nokogiri::HTML(response.body).css("[name='member[roles][]']")).to be_empty
      end
    end

    context "when signed in as a member who cannot add anybody" do
      it "refuses the form rather than offering one the submission would reject" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get new_group_member_path(member.group)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "GET /groups/:group_id/members/:id/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        get edit_group_member_path(member.group, member)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        member = create(:member)
        sign_in_as(create(:user))

        get edit_group_member_path(member.group, member)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an owner" do
      it "offers every role as a checkbox, ticking the ones the member holds" do
        owner  = create(:member, :active, :owner)
        member = create(:member, :active, :events_administrator, group: owner.group)
        sign_in_as(owner.user)

        get edit_group_member_path(member.group, member)

        boxes = Nokogiri::HTML(response.body).css("input[type=checkbox][name='member[roles][]']")
        expect(boxes.map { it["value"] }).to eq [ "owner", "administrator", "events_administrator", "members_administrator" ]
        expect(boxes.select { it["checked"] }.map { it["value"] }).to eq [ "events_administrator" ]
      end
    end

    context "when signed in as a members administrator" do
      it "shows the edit member page without an email field, since a membership keeps its user" do
        member = create(:member, :active, :members_administrator)
        sign_in_as(member.user)

        get edit_group_member_path(member.group, member)

        expect(response).to have_http_status :ok
        expect(Nokogiri::HTML(response.body).css("[name='member[email]']")).to be_empty
      end

      it "offers no role checkboxes" do
        member = create(:member, :active, :members_administrator)
        sign_in_as(member.user)

        get edit_group_member_path(member.group, member)

        expect(Nokogiri::HTML(response.body).css("[name='member[roles][]']")).to be_empty
      end
    end

    context "when signed in as an administrator" do
      it "offers no role checkboxes, so never an owner box" do
        actor  = create(:member, :active, :administrator)
        member = create(:member, :active, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_member_path(member.group, member)

        expect(Nokogiri::HTML(response.body).css("[name='member[roles][]']")).to be_empty
      end
    end

    context "when signed in as a member who cannot change anybody" do
      it "refuses the form" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get edit_group_member_path(member.group, member)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "POST /groups/:group_id/members" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        group = create(:group)

        post group_members_path(group), params: { member: { email: create(:user).email } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not create the membership - closing the self-promotion path" do
        group = create(:group)
        user  = create(:user)
        sign_in_as(user)

        expect { post group_members_path(group), params: { member: { email: user.email } } }
          .not_to change(Member, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an owner" do
      it "refuses a posted role name outside the vocabulary, creating nobody" do
        actor   = create(:member, :active, :owner)
        invitee = create(:user)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: invitee.email, roles: [ "events_administrator", "bogus" ] } } }
          .not_to change(Member, :count)

        expect(response).to have_http_status :unprocessable_content
      end

      it "creates the member with the roles posted for them" do
        actor   = create(:member, :active, :owner)
        invitee = create(:user)
        sign_in_as(actor.user)

        post group_members_path(actor.group), params: { member: { email: invitee.email, roles: [ "events_administrator" ] } }

        expect(Member.find_by(user: invitee).roles.map(&:name)).to eq [ "events_administrator" ]
      end
    end

    context "when signed in as a members administrator" do
      it "creates the member" do
        actor   = create(:member, :active, :members_administrator)
        invitee = create(:user)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: invitee.email } } }
          .to change(Member, :count).by(1)

        expect(response).to redirect_to group_member_path(actor.group, Member.find_by!(user: invitee, group: actor.group))
      end

      it "creates the user too when no account holds the address" do
        actor = create(:member, :active, :members_administrator)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: "new.person@example.com" } } }
          .to change(User, :count).by(1)

        expect(actor.group.members.where(user: User.find_by!(email: "new.person@example.com"))).to exist
      end

      it "emails the person added a link to the sign-in form" do
        actor = create(:member, :active, :members_administrator)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: "new.person@example.com" } } }
          .to have_enqueued_mail(MemberMailer, :welcome)
      end

      it "emails nobody when the member is added as inactive, since they could not see the group" do
        actor = create(:member, :active, :members_administrator)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: "new.person@example.com", status: "inactive" } } }
          .not_to have_enqueued_mail(MemberMailer, :welcome)

        expect(actor.group.members.inactive.sole.user.email).to eq "new.person@example.com"
      end

      it "refuses an address that already belongs to the group, saying so and emailing nobody" do
        actor    = create(:member, :active, :members_administrator)
        existing = create(:member, group: actor.group)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: existing.user.email } } }
          .not_to have_enqueued_mail(MemberMailer, :welcome)

        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include "already belongs to a member of this group"
      end

      it "re-renders the new page when the member is invalid" do
        actor = create(:member, :active, :members_administrator)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: "" } } }
          .not_to change(Member, :count)

        expect(response).to have_http_status :unprocessable_content
      end
    end

    # Adding a person and granting them a role are two decisions, and the second is the owner's.
    # Granting a role while adding somebody is the same decision as granting it afterwards, so the
    # controller asks `manage_roles?` on create as well.
    context "when signed in as an administrator" do
      it "adds a member" do
        actor   = create(:member, :active, :administrator)
        invitee = create(:user)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: invitee.email } } }
          .to change(Member, :count).by(1)
      end

      it "cannot add one carrying a role" do
        actor   = create(:member, :active, :administrator)
        invitee = create(:user)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: invitee.email, roles: [ "events_administrator" ] } } }
          .not_to change(Member, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a member who cannot add anybody" do
      it "refuses and creates nobody" do
        actor   = create(:member, :active)
        invitee = create(:user)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: invitee.email } } }
          .not_to change(Member, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not create the membership" do
        actor = create(:member, :paused)
        invitee = create(:user)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { email: invitee.email } } }
          .not_to change(Member, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /groups/:group_id/members/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator" ] } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and leaves the member unchanged" do
        member = create(:member)
        sign_in_as(create(:user))

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator" ] } }

        expect(response).to have_http_status :not_found
        expect(member.reload.roles).to be_empty
      end
    end

    context "when signed in as an owner" do
      it "grants a member their roles" do
        owner  = create(:member, :active, :owner)
        member = create(:member, group: owner.group)
        sign_in_as(owner.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator", "events_administrator" ] } }

        expect(response).to redirect_to group_member_path(member.group, member)
        expect(member.reload.roles.map(&:name)).to contain_exactly("administrator", "events_administrator")
      end

      it "refuses a posted role name outside the vocabulary, leaving the roles alone" do
        owner  = create(:member, :active, :owner)
        member = create(:member, :administrator, group: owner.group)
        sign_in_as(owner.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "bogus" ] } }

        expect(response).to have_http_status :unprocessable_content
        expect(member.reload.roles.map(&:name)).to eq [ "administrator" ]
      end

      it "revokes every role when the form posts none" do
        owner  = create(:member, :active, :owner)
        member = create(:member, :administrator, group: owner.group)
        sign_in_as(owner.user)

        patch group_member_path(member.group, member), params: { member: { status: "active", roles: [ "" ] } }

        expect(response).to redirect_to group_member_path(member.group, member)
        expect(member.reload.roles).to be_empty
      end

      it "saves their own form posting the roles they already hold, as the group's only owner" do
        owner = create(:member, :active, :owner)
        sign_in_as(owner.user)

        patch group_member_path(owner.group, owner), params: { member: { status: "active", roles: [ "", "owner" ] } }

        expect(flash[:alert]).to be_nil
        expect(flash[:notice]).to eq "Member was successfully updated."
      end

      it "grants a role posted twice exactly once" do
        owner  = create(:member, :active, :owner)
        member = create(:member, group: owner.group)
        sign_in_as(owner.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator", "administrator" ] } }

        expect(response).to redirect_to group_member_path(member.group, member)
        expect(member.reload.roles.map(&:name)).to eq [ "administrator" ]
      end

      it "makes another member an owner" do
        owner  = create(:member, :active, :owner)
        member = create(:member, group: owner.group)
        sign_in_as(owner.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "owner" ] } }

        expect(member.reload).to be_owner
      end
    end

    context "when signed in as a members administrator" do
      it "changes a member's status" do
        actor  = create(:member, :active, :members_administrator)
        member = create(:member, :active, group: actor.group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { status: "paused" } }

        expect(member.reload).to be_paused
      end

      it "re-renders the edit page when the member is invalid" do
        actor  = create(:member, :active, :members_administrator)
        member = create(:member, group: actor.group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { status: "" } }

        expect(response).to have_http_status :unprocessable_content
      end

      it "ignores a posted group_id, leaving the membership in its own group" do
        actor  = create(:member, :active, :members_administrator)
        member = create(:member, group: actor.group)
        other_group = create(:group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { group_id: other_group.id } }

        expect(member.reload.group).to eq actor.group
      end

      it "ignores a posted user_id, leaving the membership with the user it had" do
        actor  = create(:member, :active, :members_administrator)
        member = create(:member, group: actor.group)
        original_user = member.user
        other_user = create(:user)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { user_id: other_user.id } }

        expect(member.reload.user).to eq original_user
      end

      it "ignores a posted email, leaving the membership with the user it had" do
        actor  = create(:member, :active, :members_administrator)
        member = create(:member, group: actor.group)
        original_user = member.user
        other_user = create(:user)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { email: other_user.email } }

        expect(member.reload.user).to eq original_user
      end
    end

    # The roles check asks whether the posted set differs from the one the member holds, not whether
    # a `roles` key arrived. The form posts roles only for an acting user who may grant them, but one
    # loaded while they could and submitted after they no longer can still carries the unchanged list,
    # and an administrator must keep their own row.
    context "when signed in as an administrator" do
      it "changes a status while posting the roles the member already holds" do
        actor  = create(:member, :active, :administrator)
        member = create(:member, :active, :events_administrator, group: actor.group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member),
          params: { member: { status: "paused", roles: [ "events_administrator" ] } }

        expect(member.reload).to be_paused
        expect(member.roles.map(&:name)).to eq [ "events_administrator" ]
      end

      it "cannot grant a role" do
        actor  = create(:member, :active, :administrator)
        member = create(:member, group: actor.group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "events_administrator" ] } }

        expect(response).to redirect_to root_path
        expect(member.reload.roles).to be_empty
      end

      it "cannot revoke a role" do
        actor  = create(:member, :active, :administrator)
        member = create(:member, :events_administrator, group: actor.group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "" ] } }

        expect(response).to redirect_to root_path
        expect(member.reload.roles.map(&:name)).to eq [ "events_administrator" ]
      end
    end

    context "when the status change would leave the group without an active owner" do
      it "re-renders the edit page and leaves the member active" do
        owner = create(:member, :active, :owner)
        create(:member, group: owner.group)
        sign_in_as(owner.user)

        patch group_member_path(owner.group, owner), params: { member: { status: "paused" } }

        expect(response).to have_http_status :unprocessable_content
        expect(owner.reload).to be_active
      end
    end

    context "when revoking the last owner's role" do
      it "refuses and leaves the role in place" do
        owner = create(:member, :active, :owner)
        sign_in_as(owner.user)

        patch group_member_path(owner.group, owner), params: { member: { roles: [ "" ] } }

        expect(response).to redirect_to group_member_path(owner.group, owner)
        expect(flash[:alert]).to be_present
        expect(owner.reload).to be_owner
      end
    end

    context "when signed in as a member who cannot change anybody" do
      it "refuses and leaves the member unchanged" do
        actor  = create(:member, :active)
        member = create(:member, :active, group: actor.group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { status: "paused" } }

        expect(response).to redirect_to root_path
        expect(member.reload).to be_active
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and leaves the member unchanged" do
        member = create(:member)
        actor = create(:member, :paused, group: member.group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator" ] } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(member.reload.roles).to be_empty
      end
    end
  end

  describe "DELETE /groups/:group_id/members/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        expect { delete group_member_path(member.group, member) }
          .not_to change(Member, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not destroy the member" do
        member = create(:member)
        sign_in_as(create(:user))

        expect { delete group_member_path(member.group, member) }
          .not_to change(Member, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as a members administrator" do
      it "destroys the member" do
        target = create(:member)
        actor = create(:member, :active, :members_administrator, group: target.group)
        sign_in_as(actor.user)

        expect { delete group_member_path(target.group, target) }
          .to change(Member, :count).by(-1)

        expect(response).to redirect_to group_members_path(target.group)
      end
    end

    # A group must keep an owner whoever is asking, so the last one is refused even to themselves.
    # The refusal is a message rather than a 500: Member throws :abort, and the controller turns the
    # RecordNotDestroyed that follows into something the acting member can act on.
    context "when the removal would leave the group without an owner" do
      it "refuses, says why, and keeps the member" do
        owner = create(:member, :active, :owner)
        create(:member, group: owner.group)
        sign_in_as(owner.user)

        expect { delete group_member_path(owner.group, owner) }
          .not_to change(Member, :count)

        expect(response).to redirect_to group_member_path(owner.group, owner)
        expect(flash[:alert]).to be_present
      end

      it "allows it once a second owner exists" do
        owner = create(:member, :active, :owner)
        create(:member, :owner, group: owner.group)
        sign_in_as(owner.user)

        expect { delete group_member_path(owner.group, owner) }
          .to change(Member, :count).by(-1)
      end
    end

    context "when signed in as a member who cannot remove anybody" do
      it "refuses and removes nobody" do
        target = create(:member)
        actor = create(:member, :active, group: target.group)
        sign_in_as(actor.user)

        expect { delete group_member_path(target.group, target) }
          .not_to change(Member, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not destroy the member" do
        target = create(:member)
        actor = create(:member, :paused, group: target.group)
        sign_in_as(actor.user)

        expect { delete group_member_path(target.group, target) }
          .not_to change(Member, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end
end
