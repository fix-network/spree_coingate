module Spree
  class CoingateController < StoreController

    skip_before_action :verify_authenticity_token

    def redirect
      order = current_order || raise(ActiveRecord::RecordNotFound)

      if order.state != 'payment'
        redirect_to root_url() # Order is not ready for payment / has already been paid
        return
      end

      auth_token = payment_method.preferences[:auth_token]

      raise 'Please enter an API Auth token in Spree payment method settings' if auth_token.nil?

      CoinGate.config do |config|
        config.auth_token = auth_token
        config.environment = payment_method.preferences[:sandbox_environment] == true ? 'sandbox' : 'live'
      end

      secret_token = SecureRandom.base64(30)

      post_params = {
          order_id: order.number,
          price_amount: order.total.to_f,
          price_currency: order.currency,
          receive_currency: 'BTC',
          callback_url: spree_coingate_callback_url(payment_method_id: params[:payment_method_id], secret_token: secret_token),
          cancel_url: spree_coingate_cancel_url(payment_method_id: params[:payment_method_id]),
          success_url: spree_coingate_success_url(payment_method_id: params[:payment_method_id], order_num: order.number),
          description: 'Description here'
      }

      coingate_order = CoinGate::Merchant::Order.create!(post_params)

      if coingate_order

        # Add a "processing" payment that is used to verify the callback
        transaction = Spree::CoingateTransaction.new
        transaction.secret_token = secret_token

        payment = order.payments.create({amount: order.total, source: transaction, payment_method: payment_method})
        payment.started_processing!

        flash.notice = Spree.t(:order_processed_successfully)
        redirect_to coingate_order.payment_url
      else
        redirect_to checkout_state_path(current_order.state), notice: Spree.t(:spree_coingate_checkout_error)
      end
    end

    def callback

      order = Spree::Order.find_by(number: params[:order_id]) || raise(ActiveRecord::RecordNotFound)

      render(inline: 'Order canceled', status: 200) and return if params[:status] == 'canceled'

      render(inline: 'Invalid order ID', status: 401) and return unless order.present?

      render(inline: 'Invalid order status', status: 402) and return unless params[:status] == 'paid'

      payments = order.payments.includes(:source).where(order_id: order.id, state: ['processing', 'pending'], payment_method_id: payment_method)
      payment = payments.select {|p| p.source.secret_token == params[:secret_token]}.to_a.first

      render(inline: 'No matching payment for order', status: 403) and return if payment.nil?

      # Verify secret_token
      render(inline: 'Invalid secret token', status: 404) and return if payment.source.secret_token != params[:secret_token]

      # Verify order amount
      order_amount = order.total * 100
      render(inline: 'Invalid order amount', status: 405) and return if params[:receive_amount].to_i < order_amount.to_i

      transaction = payment.source
      transaction.order_id = params[:id]
      transaction.save

      # Mark payment as paid/complete
      payment.complete!

      order.next

      render(inline: 'Could not transition order: %s' % order.errors, status: 405) and return unless order.complete?

      render(inline: 'Callback successful', status: 200)
    end

    def cancel

      order = current_order || raise(ActiveRecord::RecordNotFound)
      payments = order.payments.where(state: ['processing', 'pending'], payment_method_id: payment_method)

      payments.each(&:void)

      redirect_to checkout_state_path(current_order.state), notice: Spree.t(:spree_coingate_checkout_cancelled)
    end

    def success

      order = Spree::Order.find_by_number(params[:order_num]) || raise(ActiveRecord::RecordNotFound)

      if order.complete?
        session[:order_id] = nil # Reset cart
        redirect_to spree.order_path(order), notice: Spree.t(:order_processed_successfully)
      end

      # If order not complete, wait for callback to come in... (page will automatically refresh, see view)
    end

    private

    def payment_method
      m = Spree::PaymentMethod.find(params[:payment_method_id])
      if !(m.is_a? Spree::PaymentMethod::Coingate)
        raise 'Invalid payment_method_id'
      end
      m
    end

  end
end