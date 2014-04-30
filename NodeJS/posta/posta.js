
var request = require('request');
var jsdom = require("jsdom");


request.get('http://www.posta.md:8081/IPSWeb_item_events.asp?itemid=RM133644505DE&Submit=Accept', function (error, response, body) {
      if(response.statusCode == 201){
        	//console.log('document saved as: http://mikeal.iriscouch.com/testjs/'+ rand)
      } else {
        	//console.log('error: '+ response.statusCode)
       	 	//console.log(body)

       	 	jsdom.env(body, ["http://code.jquery.com/jquery.js"], function (errors, window) {
						    //var tabproperty = window.$(".tabproperty");
						    //var tabproperty = window.$('tr[class^="tab"]');

						    window.$('tr[class^="tab"]').each(function(i, row) {
    							if (i > 0) {
    								console.log(window.$(row).html());
    							};
							})

						    //var trs = tabproperty.('tr[class^="tab"]');

						    //console.log("Table: ", tabproperty.text());
						  }
				);

      }
})