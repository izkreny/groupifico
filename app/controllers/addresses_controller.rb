class AddressesController < ApplicationController
  before_action :set_address, only: %i[ show edit update ]

  def index
    authorize! Address, to: :index?

    @addresses = authorized_scope(Address.all)
  end

  def show
    authorize! @address
  end

  def edit
    authorize! @address
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

  private
    def set_address
      @address = Address.find(params.expect(:id))
    end

    def address_params
      params.expect(address: [ :name, :street_name, :building_number, :city, :postal_code, :state_code, :country_code, :latitude, :longitude ])
    end
end
