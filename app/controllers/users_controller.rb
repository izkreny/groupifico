class UsersController < ApplicationController
  # Permanent, all four. Each reaches its record through `set_user`, which answers `Current.user`,
  # so the record is named by the caller's own signed cookie and never by the request: a policy
  # here would have one possible input and one possible answer. That is the argument
  # `SessionsController` makes for its own `destroy`, arriving by the same route - having something
  # to authorize against is not the same as having a decision to make.
  #
  # Named actions rather than a bare skip, so an action added later cannot inherit an exemption
  # nobody chose for it - same reason `SessionsController` names its own.
  skip_verify_authorized only: %i[ show edit update destroy ]

  before_action :set_user, only: %i[ show edit update destroy ]

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to user_path,
        notice: "User was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_content
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
      params.expect(user: [ :email ])
    end
end
