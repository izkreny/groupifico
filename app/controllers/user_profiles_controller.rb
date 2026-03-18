class UserProfilesController < ApplicationController
  before_action :set_user_profile, only: %i[ show edit update destroy ]

  # GET /user_profiles
  def index
    @user_profiles = UserProfile.all
  end

  # GET /user_profiles/1
  def show
  end

  # GET /user_profiles/new
  def new
    @user_profile = UserProfile.new
  end

  # GET /user_profiles/1/edit
  def edit
  end

  # POST /user_profiles
  def create
    @user_profile = UserProfile.new(user_profile_params)

    if @user_profile.save
      redirect_to @user_profile, notice: "User profile was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /user_profiles/1
  def update
    if @user_profile.update(user_profile_params)
      redirect_to @user_profile, notice: "User profile was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /user_profiles/1
  def destroy
    @user_profile.destroy!

    redirect_to user_profiles_path, notice: "User profile was successfully destroyed.", status: :see_other
  end

  private
    def set_user_profile
      @user_profile = UserProfile.find(params.expect(:id))
    end

    def user_profile_params
      params.expect(user_profile: [ :first_name, :last_name, :mobile_phone, :user_id ])
    end
end
