require 'minifinancier_services_pb' # 自動生成されたコードのロード

module Mutations
  class CreateOrder < BaseMutation
    # field :client_mutation_id, String, null: false
    # 自動生成されたコードから gRPC Stub を作成 #=> "payment-42"


    field :order, Types::OrderType, null: false

    argument :pickup_location_id, ID, required: true
    argument :items, [Types::OrderItemInputType], required: true

    def resolve(pickup_location_id:, items:)
      total_amount = 0
      items.each do |item|
        puts item[:product_id]
        total_amount += Product.find_by(id: item[:product_id]).price * item[:quantity].to_i
      end
      pickup_location = PickupLocation.find_by(id: pickup_location_id)
      order = Order.create!(
        user: context[:current_user],
        pickup_location: pickup_location,
        ordered_at: Time.now,
        delivery_date: Date.tomorrow + 12.hours,
        total_amount: total_amount
      )
      items.each do |item|
        ProductOrder.create!(order: order, product: Product.find_by(id: item[:product_id]), product_count: item[:quantity])
      end

      service = Minifinancier::PaymentGateway::Stub.new(
        'localhost:50051',
        :this_channel_is_insecure,
        )
      # gRPC Stub のメソッドを呼ぶと minifinancier の RPC が呼ばれる
      payment = service.charge(
        Minifinancier::ChargeRequest.new(user_id: context[:current_user].id, amount: total_amount),
        )
      puts payment.id

      if order
        { order: order }
      else
        raise GraphQL::ExecutionError, order.error.full_messages
      end
    end
  end
end
