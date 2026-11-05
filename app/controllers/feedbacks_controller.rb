class FeedbacksController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create, by: -> { Current.user.id },
    with: -> { redirect_to new_feedback_path, alert: "You've sent a lot of feedback just now. Please try again later." }

  def new
    @feedback = Current.user.feedbacks.new(page: request.referer)
    authorize! @feedback
  end

  def create
    @feedback = Current.user.feedbacks.new(feedback_params)
    @feedback.user_agent = request.user_agent.to_s.first(1_000)
    @feedback.revision = Rails.configuration.x.revision
    authorize! @feedback

    if @feedback.save
      redirect_to feedback_path(@feedback), notice: "Your feedback was sent.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @feedback = Current.user.feedbacks.find(params[:id])
    authorize! @feedback
    @group = Current.user.current_groups.find_by(id: @feedback.page_group_id)
  end

  private
    def feedback_params
      params.expect(feedback: [
        :description, :page, :viewport_width, :viewport_height, :screen_width, :screen_height, :pixel_ratio,
        :orientation, :color_scheme, :reduced_motion, :pointer, :display_mode, :time_zone, :language, :connection,
        screenshots: []
      ])
    end
end
