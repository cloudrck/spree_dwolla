module Spree
  class DwollaController < StoreController
  	  def create
  	  	  Dwolla.create(person_params)
  	  end
  	  	  
    def cancel
      flash[:notice] = Spree.t(:cancel, :scope => :dwolla)
      redirect_to checkout_state_path(current_order.state)
    end

    def auth
      redirect_to provider::OAuth.get_auth_url(dwolla_return_url)
    end

    def logout
      session.delete :dwolla_oauth_token
      session.delete :dwolla_name
      session.delete :dwolla_id
      session.delete :dwolla_funding_sources

      redirect_to checkout_state_path(:payment, :method => 'dwolla')
    end

    def return
      begin
        code = params['code']
        return render 'spree/checkout/payment/dwolla_cancel', :layout => false if code.nil?

        token = provider::OAuth.get_token(code, dwolla_return_url)
        me = Dwolla::Users.me(token)

        if payment_method.preferred_allow_funding_sources
          session[:dwolla_funding_sources] = {}

          funding_sources = Dwolla::FundingSources.get(nil, token)
          funding_sources.each do |source|
            if source['Id'] == 'Credit' or source['Id'] == 'Balance' or payment_method.preferred_allow_ach
              session[:dwolla_funding_sources][source['Name']] = source['Id']
            end
          end
        end

        session[:dwolla_oauth_token] = token
        session[:dwolla_name] = me['Name'][0..(me['Name'].index(' ')-1)]
        session[:dwolla_id] = me['Id']

        flash[:notice] = Spree.t(:oauth_success, :scope => :dwolla)
      rescue ::Dwolla::APIError => exception
        flash[:notice] = Spree.t(:oauth_fail, :scope => :dwolla) % exception
      end

      url = checkout_state_path(:payment, :method => 'dwolla')
      render 'spree/checkout/payment/dwolla_return', :locals => { :url => url }, :layout => false
    end

    def update
      number = params["number"]
      payment_id = params["payment_id"]
      log "Updating order with number: #{number} and payment ID: #{payment_id}"

      order = Spree::Order.find_by_number(number)
      if(order)
        log "Found order! Looking for DwollaCheckout source payment"

        order.payments.where(:id => payment_id, :source_type => 'Spree::DwollaCheckout').each { |payment|
          log "Found a DwollaCheckout type payment with ID #{payment.id}! Updating..."

          begin
            tx = provider::Transactions.get(payment.source.transaction_id, {}, false)
            payment_status = tx["Status"]

            log "#{payment.id} has Dwolla status: #{payment_status}"

            payment.log_entries.create(:details => "Manually polling transaction status from Dwolla... Current status on the Dwolla server: #{payment_status}")

            case payment_status
              when "failed"
              when "cancelled"
              when "reclaimed"
                payment.failure!
                new_status = 'Failure'

              when "pending"
              when "completed"
                payment.pend!
                new_status = 'Pending'

              when "processed"
                payment.complete!
                new_status = 'Complete'
            end

            log "Setting #{payment.id} to status: #{new_status}"

            payment.log_entries.create(:details => "Changing payment status to: #{new_status}")
          rescue ::Dwolla::APIError => exception
            log "Problem polling this transaction from Dwolla. Dwolla said: #{exception}"

            payment.log_entries.create(:details => "Problem polling this transaction from Dwolla. Dwolla said: #{exception}")
          rescue => exception
            log "Problem updating this transaction. Spree said: #{exception}"

            payment.log_entries.create(:details => "Problem updating this transaction. Spree said: #{exception}")
          end
        }
      else
        log "Couldn't find any orders matching that number"
      end

      redirect_to :back
    end

    private

      def enable_debug
        payment_method.preferred_enable_debug
      end

      def log(string)
        logger.info string if @enable_debug
      end

      def payment_method
        @payment_method ||= Spree::PaymentMethod.find(:first, :conditions => [ "lower(name) = ?", 'dwolla' ]) || raise(ActiveRecord::RecordNotFound)
      end

      def provider
        payment_method.provider
      end

    # def refund
    #   number = params["number"]

    #   order = Spree::Order.find_by_number(number)
    #   if(order)
    #     order.payments.where(:source_type => Spree::DwollaCheckout).each { |payment|
    #       begin
    #         tx = provider::Transactions.get(payment.source.transaction_id)
    #         senders_transaction_id = tx["Id"]

    #         refund_tx = provider::Transactions.refund({
    #           :transactionId => senders_transaction_id,
    #           :amount => '0.01',
    #           :pin => payment_method.preferred_your_pin,
    #           :fundsSource => 'Balance'
    #         })

    #         payment.log_entries.create(:details => "Refunding transaction on Dwolla... Refund ID: #{refund_tx}")
    #       rescue ::Dwolla::APIError => exception
    #         payment.log_entries.create(:details => "Problem refunding this transaction. Dwolla said: #{exception}")
    #       end
    #     }
    #   end

    #   redirect_to :back
    # end
	private

		def dwolla_params
			params.require(:dwolla).permit(:preferred_dwolla_id, :preferred_key, :preferred_secret, :preferred_oauth_scope, :preferred_sandbox, :preferred_allow_funding_sources, :preferred_default_funding_source, :preferred_allow_ach, :preferred_your_oauth_token, :preferred_your_pin, :preferred_enable_debug)
		end
  end
end
