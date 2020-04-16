public class cc_api_ShippingAndHandlingOverride extends ccrz.cc_api_ShippingAndHandling {

    public override List<ccrz.cc_ctrl_hlpr_ShippingOption> getShippingOptions(String zipCode, String stateCode, String countryCode, Id cartId, String storeName) {
  
        // realizar uma nova listagem de "Helper Shipping Option" - que eh o dropdown "Shipping Method" da pagina de Shipping Information do CheckOut
        List <ccrz.cc_ctrl_hlpr_ShippingOption> shippingOptions = new List<ccrz.cc_ctrl_hlpr_ShippingOption>();
    
        // listar o carrinho ativo que vem como parametro no metodo
        ccrz__E_Cart__c cart = [
            SELECT ccrz__Account__c, ccrz__ActiveCart__c, ccrz__CartStatus__c, ccrz__CCEmailAddress__c, ccrz__BuyerCompanyName__c, 	ccrz__Contact__c,
            ccrz__CurrencyISOCode__c, ccrz__BuyerEmail__c, ccrz__ShipAmount__c, ccrz__ShipTo__c,
            ccrz__Storefront__c, ccrz__SubtotalAmount__c, ccrz__TotalAmount__c, ccrz__TotalQuantity__c, ccrz__User__c
            FROM ccrz__E_Cart__c
            WHERE Id =: cartId
        ][0];

        // CallContex para obter o id da effective Account do usuario
        String idAcct = ccrz.cc_CallContext.effAccountId;
        
        // Nova Account para armazenar as informacoes da Account para utilizarmos as informações de ShippingState & BillingState
        Account aInfo = new Account();
        
        //Listar as Accounts
		List <Account> accts = [
            SELECT ShippingState, BillingState 
            FROM Account 
            WHERE Id=: idAcct
        ];
        
        // obter o resultado do id armazenado no idAcct que chamamos via CallContext e armazenar na account que criamos
        for(Account a1 : accts){
            aInfo.ShippingState = a1.ShippingState;
            aInfo.BillingState = a1.BillingState;
        }
        
        ccrz.ccLog.log(LoggingLevel.DEBUG, 'ShippingState do usuário Logado -> ' + aInfo.ShippingState);
 		
        
        //se o ShippingState estiver nulo e o Billing state preenchido, utilizar o Billing State para fazer a Query abaixo
        if(aInfo.ShippingState == Null && aInfo.BillingState != Null){
            aInfo.ShippingState = aInfo.BillingState;
        }
 
        // listar os shipping rates cadastrados, utilizar o ShippingState como filtro
        List <ccrz__E_ShippingRate__c> options = [
            SELECT Name, Estado__c, Cidade__c, ccrz__CurrencyISOCode__c, ccrz__MaxWeight__c, ccrz__MinWeight__c, ccrz__Shipper__c, ccrz__ShippingRate__c, ccrz__Storefront__c
            FROM ccrz__E_ShippingRate__c
            WHERE Estado__c =: aInfo.ShippingState
        ];

        // listar os itens do carrinho, passando como filtro da query o id do carrinho ativo
        List <ccrz__E_CartItem__c> items = [
            SELECT ccrz__cartItemType__c, ccrz__SubAmount__c, ccrz__ParentCartItem__r.ccrz__SubAmount__c, ccrz__ParentCartItem__c, ccrz__Quantity__c, 
            ccrz__Product__r.ccrz__ShippingWeight__c, ccrz__Product__r.ccrz__ProductType__c, ccrz__Product__c, ccrz__Product__r.ccrz__SKU__c, Id 
            FROM ccrz__E_CartItem__c
            WHERE ccrz__Cart__c =: cartId
        ];
        
        
        ccrz.ccLog.log(LoggingLevel.DEBUG, 'Call Context -> ' + ccrz.cc_CallContext.effAccountId);
                             
        
        // inicializar o peso total dos produtos
        double weight = 0.0;

		// para cada item no carrinho, se o peso armazenado no campo Shipping Weight nao for nulo
        for(ccrz__E_CartItem__c item : items) {
            double auxWeight = 0.0;
            double itemQty = item.ccrz__Quantity__c;
            ccrz.ccLog.log(LoggingLevel.DEBUG, 'itemqty -> ' + itemQty);
            if(item.ccrz__Product__r.ccrz__ShippingWeight__c != null){  
                //adicionar o peso na variavel weight, somar todos os pesos                
                auxWeight += item.ccrz__Product__r.ccrz__ShippingWeight__c;
                ccrz.ccLog.log(LoggingLevel.DEBUG, 'resultado da soma -> ' + auxWeight);
                auxWeight = auxWeight * itemQty;
                ccrz.ccLog.log(LoggingLevel.DEBUG, 'resultado da conta -> ' + auxWeight);
            }
            weight += auxWeight;
            ccrz.ccLog.log(LoggingLevel.DEBUG, 'peso -> ' + weight);
        }

        weight = convert(weight).round();
            

        ccrz.ccLog.log(LoggingLevel.DEBUG, 'Peso convertido -> ' + weight);  
     
        // para cada shipping rate, criaremos um novo Shipping Options para ser adicionado na lista de Shipping Options que criamos no inicio da classe;
        for(ccrz__E_ShippingRate__c option : options){
            double rate = 0.0;
            rate = option.ccrz__ShippingRate__c;
            ccrz.cc_ctrl_hlpr_ShippingOption ship = new ccrz.cc_ctrl_hlpr_ShippingOption();
            //se o shipping options tiver FOB no nome, adicionar o rate de valor 0 no shipping
			if(option.Name.contains('FOB')){
				ship.provider = option.Name;
            	ship.serviceName = option.ccrz__Shipper__c;
				ship.currencyCode = option.ccrz__CurrencyISOCode__c;
           		ship.price = 0.00;
            	ship.uniqueId = ship.provider;
            	shippingOptions.add(ship);
                //caso contrário, ele segue o fluxo normal de cálculo de frete
            }else {
            	ship.provider = option.Name;
            	ship.serviceName = option.ccrz__Shipper__c + ' - R$/t ' + option.ccrz__ShippingRate__c;
				ship.currencyCode = option.ccrz__CurrencyISOCode__c;
           		ship.price = weight * rate;
            	ship.uniqueId = ship.provider;
            	shippingOptions.add(ship); 
            }
        }
		
        // retorna a lista com os shipping options filtrados por estado e com o frete calculado para o peso dos produtos
        return shippingOptions;
    }
    
    public static double convert(double peso){
        Double tonelada = 1000.0;
        return peso/tonelada;
    }

}