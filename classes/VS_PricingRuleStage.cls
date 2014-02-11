global class VS_PricingRuleStage implements Database.Batchable<sobject> {
	String query;
	global VS_PricingRuleStage() {}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
        // This is the base query that dirves the chunking.
        // We are grabbing all the plans are currently active and
        // have a start or end date that is currently in need of calculation.
        
        query = 'SELECT Id, Pricing_Rule__c, Pricing_Rule__r.Contract_vod__c, Terr_List__c from Pr_Rule_Stage__c where Pricing_Rule__r.Contract_vod__c != null';
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<sObject> batch) {
        
        Set<Id> contrIds = new Set<Id>();  
        for (sObject obj : batch) {
            Pr_Rule_Stage__c pr = (Pr_Rule_Stage__c)obj;
            
            contrIds.add(pr.Pricing_Rule__r.Contract_vod__c);
        }
        
        Map<Id, List<Id>> contMap = new Map<Id, List<Id>>();
        Contract_Partner_vod__c[] cp = [Select Id, Contract_vod__c, Account_vod__c from Contract_Partner_vod__c where Contract_vod__c in :contrIds];
        
        for (Contract_Partner_vod__c partn : cp) {
        	if (contMap.containsKey(partn.Contract_vod__c)) {
        		//contMap.get(partn.Contract_vod__c).add(partn.Id);
        	} else {
        		contMap.put(partn.Contract_vod__c, new List<Id>());
        	}
        	contMap.get(partn.Contract_vod__c).add(partn.Account_vod__c);
        }
        
        system.debug('map:'+contMap);
        Set<Id> accts = new Set<Id>();
        List<List<Id>> vals = contMap.values();
        for (List<Id> ids : vals) {
        	accts.addAll(ids);
        }
        
        Account_Territory_Loader_vod__c[] atls = [select Id, Account_vod__c, Territory_vod__c from Account_Territory_Loader_vod__c where Account_vod__c in :accts];
        
        Map<Id, Account_Territory_Loader_vod__c> atlMap = new Map<Id, Account_Territory_Loader_vod__c>();
        for (Account_Territory_Loader_vod__c atl : atls) {
        	atlMap.put(atl.Account_vod__c, atl);
        }
        
        system.debug('atlmap:'+atlmap);
        
        // go through each pr rule, get contract, get list of partner accounts, get terr for each account and combine into a text field
        // save this back to the pr rule
        
        for (sObject obj : batch) {
            // pr rule
            Pr_Rule_Stage__c pr = (Pr_Rule_Stage__c)obj;
            
            String terrs;
            
            // get contract for the rule from contMap
            // returns list of accounts
            List<Id> accIds = contMap.get(pr.Pricing_Rule__r.Contract_vod__c);
            
            // go through each account, get atl list from atlMap
            // returns list<atl> - only 1 value though
            for (Id accId : accIds) {
            	Account_Territory_Loader_vod__c atl = atlMap.get(accId);
            	
            	// pull out terr_vod__c
            	terrs += atl.Territory_vod__c;
            }
            

            // add back into the pr rule.terr list
            
            pr.Terr_List__c = terrs;
        }
        
        // update the batch
        update batch;
        
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
    
    
}