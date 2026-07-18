class OrdersController < ApplicationController
  PER_PAGE = 10

  page Orders::IndexPage
  def index(params)
    scope = Order.order(placed_at: :desc)
    scope = scope.where(status: params.status.serialize) if params.status
    scope = scope.where("customer_name LIKE :q OR customer_email LIKE :q", q: "%#{params.query}%") if params.query
    paginated_orders = scope.offset((params.page - 1) * PER_PAGE).limit(PER_PAGE).map { OrderDTO.from_model(it) }

    Orders::IndexPage::Props.new(
      orders: paginated_orders,
      total_count: scope.count,
      page: params.page,
      per_page: PER_PAGE,
      status_counts: Order.group(:status).count
    )
  end

  page Orders::ShowPage
  def show(params)
    order = Order.find(params.id)

    Orders::ShowPage::Props.new(
      order: OrderDTO.from_model(order),
      line_items: order.line_items.order(:id).map { LineItemDTO.from_model(it) },
      activity: order.order_events.order(created_at: :desc).map { OrderEventDTOMapper.from_model(it) }
    )
  end

  page Orders::NewPage
  def new
    Orders::NewPage::Props.new(suggested_products: LineItem.distinct.order(:product_name).pluck(:product_name))
  end

  mutation Orders::CreateMutation
  def create(params)
    if params.line_items.empty?
      return invalid(base: [ "Add at least one line item" ])
    end

    order = Order.new(
      customer_name: params.customer_name,
      customer_email: params.customer_email,
      notes: params.notes,
      status: "pending",
      placed_at: Time.current
    )

    Order.transaction do
      order.save!
      params.line_items.each do |li|
        order.line_items.create!(
          product_name: li.product_name, quantity: li.quantity, unit_price_cents: li.unit_price_cents
        )
      end
      order.recalculate_total!
      order.order_events.create!(kind: "note", body: "Order received", author: "web", created_at: Time.current)
    end

    flash[:notice] = "Order ##{order.id} created"
    redirect_page order_path(order)
  rescue ActiveRecord::RecordInvalid => e
    invalid(e.record.errors)
  end

  mutation Orders::UpdateStatusMutation
  def update_status(params)
    order = Order.find(params.id)
    from = order.status

    return invalid(base: [ "Order is already #{from}" ]) if from == params.status.serialize

    order.update!(status: params.status.serialize)
    order.order_events.create!(
      kind: "status_change", from_status: from, to_status: order.status,
      author: "web", created_at: Time.current
    )
    flash[:notice] = "Status changed to #{order.status}"
    redirect_page order_path(order)
  end

  mutation Orders::AddNoteMutation
  def add_note(params)
    order = Order.find(params.id)
    return invalid(fields: { body: [ "can't be blank" ] }) if params.body.strip.empty?

    order.order_events.create!(kind: "note", body: params.body, author: "web", created_at: Time.current)
    flash[:notice] = "Note added"
    redirect_page order_path(order)
  end

  mutation Orders::DestroyMutation
  def destroy(params)
    Order.find(params.id).destroy!
    flash[:notice] = "Order ##{params.id} deleted"
    redirect_page orders_path
  end
end
