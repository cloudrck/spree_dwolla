SpreeDwolla = {
  qs: function(key) {
    key = key.replace(/[*+?^$.\[\]{}()|\\\/]/g, "\\$&");
    var match = location.search.match(new RegExp("[?&]"+key+"=([^&]+)(&|$)"));
    return match && decodeURIComponent(match[1].replace(/\+/g, " "));
  },

  hidePaymentSaveAndContinueButton: function(paymentMethod, preauth) {
    if (SpreeDwolla.paymentMethodID && paymentMethod.val() == SpreeDwolla.paymentMethodID) {
      if(preauth) { $('.continue').hide(); }
    } else {
      if(preauth) { $('.continue').show(); }
    }
  }
}

$(document).ready(function() {
  var oauthWindow
    , checkedPaymentMethod = $('div[data-hook="checkout_payment_step"] input[type="radio"]:checked')
    , paymentMethods = $('div[data-hook="checkout_payment_step"] input[type="radio"]').click(function(e) {
      var preauth = SpreeDwolla.dwollaId ? false : true;
      SpreeDwolla.hidePaymentSaveAndContinueButton($(e.target), preauth);
    })
    ;

  SpreeDwolla.hidePaymentSaveAndContinueButton(checkedPaymentMethod)

  if(SpreeDwolla.qs('method') == 'dwolla') {
    // Switch to the Dwolla payment tab
  }

  $('#dwolla_button').on('click', function(e) {
    e.preventDefault();

    oauthWindow = window.open($(this).attr('href'), 'Dwolla OAuth', 'height=400,width=700');

    return false;
  });

})
