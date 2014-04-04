module Spree
  CheckoutController.class_eval do
    after_filter :create_dwolla_payment, :only => [:update]
    def checkout_params
    	unless params[checkout].blank?
    		params.require(checkout).permit(:source, :payment_method)
    	end
    end
    def payment_method
      Spree::PaymentMethod.find(:first, :conditions => [ "lower(name) = ?", 'dwolla' ]) || raise(ActiveRecord::RecordNotFound)
    end

    def create_dwolla_payment
      return unless (params[:state] == "payment")
      return unless params[:order][:payments_attributes]

      return unless Spree::PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id]).kind_of?(Spree::Gateway::Dwolla)

      payment = @order.payments.create!({
        :source => Spree::DwollaCheckout.create({
          :oauth_token => session[:dwolla_oauth_token],
          :pin => params[:dwolla_pin],
          :funding_source_id => params[:dwolla_funding_source] || payment_method.preferred_default_funding_source
        }),
        :amount => @order.total,
        :payment_method => payment_method
      })
    end

  end
end
