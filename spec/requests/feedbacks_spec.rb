require "rails_helper"

RSpec.describe "Feedbacks", type: :request do
  describe "GET /feedbacks/new" do
    context "when signed in" do
      it "records the page the form was opened from, without its query string" do
        sign_in_as(create(:user))

        get new_feedback_path, headers: { "Referer" => "http://www.example.com/groups/3/events?token=secret" }
        page_field = Nokogiri::HTML(response.body).at_css("input[name='feedback[page]']")

        expect(page_field["value"]).to eq "/groups/3/events"
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get new_feedback_path

        expect(response).to redirect_to new_session_path
      end
    end
  end

  describe "POST /feedbacks" do
    context "when signed in" do
      it "saves the feedback with the request's user agent and shows the thank-you page" do
        user = create(:user)
        sign_in_as(user)

        post feedbacks_path, params: { feedback: { description: "The dock covers Save.", page: "/groups/3", viewport_width: "390", user_agent: "Forged/1.0" } },
          headers: { "User-Agent" => "TestPhone/1.0" }
        feedback = user.feedbacks.sole

        expect(response).to redirect_to feedback_path(feedback)
        expect(response).to have_http_status :see_other
        expect(flash[:notice]).to eq "Your feedback was sent."
        expect([ feedback.description, feedback.page, feedback.viewport_width, feedback.user_agent ]).to eq [ "The dock covers Save.", "/groups/3", "390", "TestPhone/1.0" ]
      end

      it "saves the picked screenshots with the feedback" do
        user = create(:user)
        sign_in_as(user)

        post feedbacks_path, params: { feedback: { description: "See the picture.", screenshots: [ fixture_file_upload("screenshot.png", "image/png") ] } }

        expect(user.feedbacks.sole.screenshots.map { it.filename.to_s }).to eq [ "screenshot.png" ]
      end

      it "files the saved feedback as an issue in the background" do
        sign_in_as(create(:user))

        expect { post feedbacks_path, params: { feedback: { description: "The dock covers Save." } } }
          .to have_enqueued_job(Feedback::FileIssueJob)
      end

      it "refuses a blank description and saves nothing" do
        sign_in_as(create(:user))

        expect { post feedbacks_path, params: { feedback: { description: "" } } }.not_to change(Feedback, :count)
        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include "Description can&#39;t be blank"
      end

      it "accepts five submissions within ten minutes and refuses the sixth" do
        user = create(:user)
        sign_in_as(user)

        5.times { post feedbacks_path, params: { feedback: { description: "Another thing." } } }

        expect(user.feedbacks.count).to eq 5

        post feedbacks_path, params: { feedback: { description: "One more thing." } }

        expect(response).to redirect_to new_feedback_path
        expect(flash[:alert]).to eq "You've sent a lot of feedback just now. Please try again later."
        expect(user.feedbacks.count).to eq 5
      end
    end

    context "when not signed in" do
      it "redirects to sign in and saves nothing" do
        expect { post feedbacks_path, params: { feedback: { description: "Hello" } } }.not_to change(Feedback, :count)
        expect(response).to redirect_to new_session_path
      end
    end
  end

  describe "GET /feedbacks/:id" do
    context "when signed in" do
      it "thanks the user and leads back to the page they came from" do
        feedback = create(:feedback, page: "/groups/3/events")
        sign_in_as(feedback.user)

        get feedback_path(feedback)
        back = Nokogiri::HTML(response.body).at_css("main a.btn-primary")

        expect(response.body).to include "Thank you"
        expect([ back.text.squish, back["href"] ]).to eq [ "Back to where you were", "/groups/3/events" ]
      end

      it "answers not found for another user's feedback" do
        sign_in_as(create(:user))

        get feedback_path(create(:feedback))

        expect(response).to have_http_status :not_found
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get feedback_path(create(:feedback))

        expect(response).to redirect_to new_session_path
      end
    end
  end
end
