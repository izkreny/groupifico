class UserProfilesController < ApplicationController
  before_action :set_user_profile

  def show
    authorize! @user_profile
  end

  def edit
    authorize! @user_profile
  end

  def update
    authorize! @user_profile

    if @user_profile.update(user_profile_params)
      redirect_to user_profile_path,
        notice: "User profile was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    # Its own copy rather than `Current.user.profile`, which the layout's avatar reads: a refused
    # save leaves the typed values assigned, email included, and the header would show them as
    # though they had been saved - or raise, when a cleared email leaves no name to take initials
    # from.
    def set_user_profile
      @user_profile = UserProfile.find_by!(user: Current.user)
    end

    def user_profile_params
      params.expect(user_profile: [ :first_name, :last_name, :mobile_phone, user_attributes: [ :email ] ])
    end
end
