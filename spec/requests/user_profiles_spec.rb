require 'rails_helper'

RSpec.describe "UserProfiles", type: :request do
  describe "GET /user/profile" do
    it "redirects to Edit profile, the profile's one screen" do
      get "/user/profile"

      expect(response).to redirect_to edit_user_profile_path
    end
  end

  describe "the avatar's menu" do
    it "names the member and offers the account's actions" do
      user = create(:user, email: "ada@example.com")
      user.profile.update!(first_name: "Ada", last_name: "Lovelace")
      sign_in_as(user)

      get groups_path
      menu = Nokogiri::HTML(response.body).at_css("header details#me-menu")

      expect(menu.at_css("summary")["aria-label"]).to eq "AL, me"
      expect(menu.css(".dropdown-content p").map { it.text.squish }).to eq [ "Ada Lovelace", "ada@example.com" ]
      expect(menu.css("li").map { it.text.squish }).to eq [ "Edit profile", "New group", "Sign out" ]
      expect(menu.css("li a").map { [ it.text.squish, it["href"] ] }).to eq [ [ "Edit profile", edit_user_profile_path ], [ "New group", new_group_path ] ]
    end

    it "leads each row with its legend glyph, in the muted icon ink" do
      sign_in_as(create(:user))

      get groups_path
      menu = Nokogiri::HTML(response.body).at_css("header details#me-menu")

      drawing = ->(name) { File.read(Rails.root.join("app/assets/svg/icons/heroicons/mini/#{name}.svg"))[/ d="([^"]+)"/, 1] }
      expect(menu.css("li").map { it.at_css("svg.size-icon-control.text-icon-muted path")&.[]("d") }).to eq %w[ user plus arrow-right-start-on-rectangle ].map(&drawing)
    end

    it "signs out through a delete form the Sign out button names" do
      sign_in_as(create(:user))

      get groups_path
      menu = Nokogiri::HTML(response.body).at_css("header details#me-menu")
      form = menu.at_css("form##{menu.at_css("li button")["form"]}")

      expect(form["action"]).to eq session_path
      expect(form.at_css("input[name=_method]")["value"]).to eq "delete"
    end
  end

  describe "GET /user/profile/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get edit_user_profile_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the edit profile page" do
        sign_in_as(create(:user))

        get edit_user_profile_path

        expect(response).to have_http_status :ok
      end

      it "goes back home, there being no profile screen to return to" do
        sign_in_as(create(:user))

        get edit_user_profile_path

        expect(Nokogiri::HTML(response.body).at_css("header a[aria-label='Back']")&.[]("href")).to eq root_path
      end

      it "edits the name, the mobile and the email in one form" do
        sign_in_as(create(:user))

        get edit_user_profile_path
        document = Nokogiri::HTML(response.body)

        expect(document.css("form label").map { it.text.squish }).to eq [ "First name", "Last name", "Mobile", "Email" ]
        expect(document.at_css("#user_profile_mobile_phone_hint").text).to eq "Optional. Shown to members of your groups."
      end

      it "leads the form's button row with Delete my account" do
        user = create(:user)
        sign_in_as(user)

        get edit_user_profile_path
        row = Nokogiri::HTML(response.body).at_css("form[action='#{user_profile_path}'] button[type=submit].btn-primary").parent

        expect(row.css("a, button").map { it.text.squish }).to eq [ "Delete my account", "Cancel", "Save" ]
      end

      it "asks for the word before deleting, naming the groups the reader leaves" do
        member = create(:member, group: create(:group, name: "Ninth Street Band"))
        sign_in_as(member.user)

        get edit_user_profile_path
        sheet = Nokogiri::HTML(response.body).at_css("dialog")

        expect(sheet.at_css("p").text).to eq "You leave Ninth Street Band and every registration goes with you. This can't be undone."
        expect(sheet.at_css("label").text.squish).to eq "Type DELETE to confirm"
        expect(sheet.at_css("button[form][disabled]")).to be_present
        expect(sheet["data-controller"]).to eq "type-to-confirm"
      end

      it "blocks the sheet on each group the reader is the only active owner of, and does not name it as left" do
        choir = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
        create(:member, user: choir.user, group: create(:group, name: "Ninth Street Band"))
        sign_in_as(choir.user)

        get edit_user_profile_path
        sheet = Nokogiri::HTML(response.body).at_css("dialog")

        expect(sheet.at_css("[role=alert]").text.squish).to eq "You still own Riverside Choir. Give another member the owner role first."
        expect(sheet.at_css("p").text).to eq "You leave Ninth Street Band and every registration goes with you. This can't be undone."
        expect(sheet["data-controller"]).to be_nil
      end

      it "leaves the sheet unblocked where the reader owns no group alone" do
        sign_in_as(create(:member).user)

        get edit_user_profile_path

        expect(response.body).not_to include("You still own")
      end
    end
  end

  describe "PATCH /user/profile" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        patch user_profile_path, params: { user_profile: { first_name: "Ada" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "updates the profile" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { first_name: "Ada", last_name: "Lovelace" } }

        expect(response).to redirect_to root_path
        expect(user.profile.reload.full_name).to eq "Ada Lovelace"
      end

      it "writes the email with the name in one save" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { first_name: "Ada", user_attributes: { email: "ada@example.com" } } }

        expect(response).to redirect_to root_path
        expect(user.profile.reload.first_name).to eq "Ada"
        expect(user.reload.email).to eq "ada@example.com"
      end

      # The account write is skipped rather than repeated: an unchanged email writes nothing to
      # `users`, so `User`'s email-change callback never consumes the reader's outstanding links.
      it "leaves the account untouched when the email is unchanged" do
        user = create(:user)
        sign_in_as(user)
        travel 1.day

        expect { patch user_profile_path, params: { user_profile: { first_name: "Ada", user_attributes: { email: user.email } } } }
          .not_to change { user.reload.updated_at }
      end

      it "keeps the name unsaved when the email is refused" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { first_name: "Ada", user_attributes: { email: "ada.example.com" } } }

        expect(response).to have_http_status :unprocessable_content
        expect(user.profile.reload.first_name).not_to eq "Ada"
        expect(user.reload.email).not_to eq "ada.example.com"
      end

      # The summary saying "fix the highlighted fields" is only true if the field it means carries
      # the message, and the email's error arrives on the profile keyed `user.email`.
      it "puts a refused email under the Email field rather than in the summary" do
        sign_in_as(create(:user))

        patch user_profile_path, params: { user_profile: { user_attributes: { email: "ada.example.com" } } }
        document = Nokogiri::HTML(response.body)

        expect(document.at_css("#user_profile_user_attributes_email_error").text).to eq "Email is invalid"
        expect(document.at_css("#error_explanation").text.squish).to eq "Please fix the highlighted fields."
      end

      # The header's avatar and menu read the member's stored profile, so a refused write never reaches them: a blank email and no name would otherwise leave `initials` nothing to take a letter from, and the menu would name an address that was never saved.
      it "keeps the stored initials and email in the header when a cleared email is refused" do
        user = create(:user, email: "ada@example.com")
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { user_attributes: { email: "" } } }

        expect(response).to have_http_status :unprocessable_content
        expect(header_text(response.body)).to include "A", "ada@example.com"
      end

      # The account written is always the one the profile belongs to, whatever the request names.
      it "writes the reader's own email when the params name another account" do
        user = create(:user)
        other = create(:user, email: "other@example.com")
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { user_attributes: { id: other.id, email: "taken@example.com" } } }

        expect(other.reload.email).to eq "other@example.com"
        expect(user.reload.email).to eq "taken@example.com"
      end

      it "re-renders the edit page when the update is invalid" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { mobile_phone: "x" * 51 } }

        expect(response).to have_http_status :unprocessable_content
      end
    end
  end
end
