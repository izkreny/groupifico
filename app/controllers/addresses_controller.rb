class AddressesController < ApplicationController
  # An address created stand-alone has no group or event pointing at it yet to be reachable
  # through, so there is nothing for AddressPolicy to check membership against at creation time.
  skip_verify_authorized only: %i[ new create ]

  before_action :set_address, only: %i[ show edit update ]

  def index
    authorize! Address, to: :index?

    @addresses = authorized_scope(Address.all)
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

  private
    def set_address
      @address = Address.find(params.expect(:id))
    end

    def address_params
      params.expect(address: [ :name, :street_name, :building_number, :city, :postal_code, :state_code, :country_code, :latitude, :longitude ])
    end
end
