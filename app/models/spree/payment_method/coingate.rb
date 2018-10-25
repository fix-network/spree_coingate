module Spree
  class PaymentMethod::Coingate < PaymentMethod
    preference :auth_token, :string
    preference :sandbox_environment, :boolean, default: true

    def auto_capture?
      false
    end

    def provider_class
      nil
    end

    def payment_source_class
      nil
    end

    def source_required?
      false
    end
  end
end