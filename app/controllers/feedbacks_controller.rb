class FeedbacksController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create, by: -> { Current.user.id }, with: -> { render_rate_limited }

  def new
    @feedback = Current.user.feedbacks.new(page: request.referer)
    authorize! @feedback
    @back_path = back_path
  end

  def create
    @feedback = Current.user.feedbacks.new(feedback_params)
    @feedback.user_agent = request.user_agent.to_s.first(1_000)
    @feedback.revision = Rails.configuration.x.revision
    authorize! @feedback

    if @feedback.save
      redirect_to feedback_path(@feedback), notice: "Your feedback was sent.", status: :see_other
    else
      @back_path = back_path
      render :new, status: :unprocessable_content
    end
  end

  def show
    @feedback = Current.user.feedbacks.find(params[:id])
    authorize! @feedback
    @group = Current.user.current_groups.find_by(id: @feedback.page_group_id)
    @back_path = back_path
  end

  private
    # WHY: rendered rather than redirected, because a redirect makes the form its own referer and loses the page it was first opened from, along with what was typed.
    def render_rate_limited
      @feedback = Current.user.feedbacks.new(feedback_params)
      @back_path = back_path
      flash.now[:alert] = "You've sent a lot of feedback just now. Please try again later."
      render :new, status: :too_many_requests
    end

    # WHY: the page is a stored URL, so the links back to it go through `url_from`, which answers only for a location on this host.
    def back_path
      url_from(@feedback.page) || root_path
    end

    def feedback_params
      params.expect(feedback: [
        :description, :page, :viewport_width, :viewport_height, :screen_width, :screen_height, :pixel_ratio,
        :orientation, :color_scheme, :reduced_motion, :pointer, :display_mode, :time_zone, :language, :connection,
        screenshots: []
      ])
    end
end
