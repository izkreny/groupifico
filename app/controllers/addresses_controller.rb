class AddressesController < ApplicationController
  # TODO(#172): remove this skip when index is scoped and creation is role-gated. The record-bearing
  # actions below are authorized already; these three have no record to authorize against yet.
  skip_verify_authorized only: %i[ index new create ]

  before_action :set_address, only: %i[ show edit update destroy ]

  def index
    @addresses = Address.all
  end

  def show
    authorize! @address
  end

  def new
    @address = Address.new
  end

  def edit
    authorize! @address
  end

  def create
    @address = Address.new(address_params)

    if @address.save
      redirect_to address_path(@address),
        notice: "Address was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! @address

    if @address.update(address_params)
      redirect_to address_path(@address),
        notice: "Address was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! @address

    @address.destroy!

    redirect_to addresses_path,
      notice: "Address was successfully destroyed.",
      status: :see_other
  end

  private
    def set_address
      @address = Address.find(params.expect(:id))
    end

    def address_params
      params.expect(address: [ :name, :street_name, :building_number, :city, :postal_code, :state_code, :country_code, :latitude, :longitude ])
    end
end
