class UsersController < ApplicationController
  # Permanent, all six, and for two different reasons.
  #
  # `show`, `edit`, `update` and `destroy` reach their record through `set_user`, which answers
  # `Current.user`. The record is named by the caller's own signed cookie and never by the request,
  # so a policy here would have one possible input and one possible answer. That is the argument
  # `SessionsController` makes for its own `destroy`, arriving by the same route: having something
  # to authorize against is not the same as having a decision to make.
  #
  # `new` and `create` do raise a question, and it is not an authorization one. Whether a signed-in
  # user may create a second user at all is a question about what the application offers, so no
  # rule this file could write would answer it; a policy added here would be answering the wrong
  # question in the right place.
  #
  # Named actions rather than a bare skip, so an action added later cannot inherit an exemption
  # nobody chose for it - same reason `SessionsController` names its own.
  skip_verify_authorized only: %i[ show new edit create update destroy ]

  before_action :set_user, only: %i[ show edit update destroy ]

  def show
  end

  def new
    @user = User.new
  end

  def edit
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to user_path,
        notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @user.update(user_params)
      redirect_to user_path,
        notice: "User was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy!

    redirect_to user_path,
      notice: "User was successfully destroyed.",
      status: :see_other
  end

  private
    def set_user
      @user = Current.user
    end

    def user_params
      params.expect(user: [ :email, :password ])
    end
end
