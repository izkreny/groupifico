class RegistrationsController < ApplicationController
  before_action :set_registration, only: %i[ show edit update destroy ]

  # GET /registrations
  def index
    @registrations = Registration.all
  end

  # GET /registrations/1
  def show
  end

  # GET /registrations/new
  def new
    @registration = Registration.new
  end

  # GET /registrations/1/edit
  def edit
  end

  # POST /registrations
  def create
    @registration = Registration.new(registration_params)

    if @registration.save
      redirect_to @registration, notice: "Registration was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /registrations/1
  def update
    if @registration.update(registration_params)
      redirect_to @registration, notice: "Registration was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /registrations/1
  def destroy
    @registration.destroy!

    redirect_to registrations_path, notice: "Registration was successfully destroyed.", status: :see_other
  end

  private
    def set_registration
      @registration = Registration.find(params.expect(:id))
    end

    def registration_params
      params.expect(registration: [ :status, :event_id, :member_id ])
    end
end
