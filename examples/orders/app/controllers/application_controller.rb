class ApplicationController < ActionController::Base
  include Fond::Controller

  def fond_shared_props
    SharedProps.new(
      app_name: "Fond Orders",
      flash: SharedProps::Flash.new(notice: flash[:notice], alert: flash[:alert]),
      open_order_count: Order.where(status: "pending").count
    )
  end
end
