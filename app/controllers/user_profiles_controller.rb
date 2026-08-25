class UserProfilesController < ApplicationController
  before_action :set_user_profile

  def show
  end

  def edit
  end

  def update
    if @user_profile.update(user_profile_params)
      redirect_to user_profile_path,
        notice: "User profile was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_user_profile
      @user_profile = Current.user.profile
    end

    def user_profile_params
      params.expect(user_profile: [ :first_name, :last_name, :mobile_phone ])
    end
end
