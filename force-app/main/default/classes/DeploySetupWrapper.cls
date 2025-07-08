/**
 * @description Wrapper DTO class used to transfer deployment configuration data between LWC and Apex.
 * @author develop@mpdigitals.com
 */
public class DeploySetupWrapper {
    @AuraEnabled public Datetime startTime {get;set;}
    @AuraEnabled public Boolean isEnabled {get;set;}
    @AuraEnabled public String frequencyUnit {get;set;}
    @AuraEnabled public String frequencyValue {get;set;}
    @AuraEnabled public Boolean retrieveComponents {get;set;}
    @AuraEnabled public Boolean retrieveTests {get;set;}
    @AuraEnabled public Boolean retrieveIntermediateStates {get;set;}
    @AuraEnabled public Integer batchSize {get;set;}
    @AuraEnabled public String namedCredential {get;set;}
    @AuraEnabled public Boolean sessionId {get;set;}

    /**
     * @description Empty constructor required for AuraEnabled deserialization.
     */
    @SuppressWarnings('PMD.EmptyStatementBlock')
    public DeploySetupWrapper() {}

    /**
     * @description Constructor to map a DeploySetup__c record to a wrapper object.
     * @param rec The setup configuration record.
     */
    public DeploySetupWrapper(DeploySetup__c rec) {
        startTime = rec.StartTime__c;
        isEnabled = rec.IsEnabled__c;
        frequencyUnit = rec.FrequencyUnit__c;
        frequencyValue = String.valueOf(rec.FrequencyValue__c);
        retrieveComponents = rec.RetrieveComponents__c;
        retrieveTests = rec.RetrieveTests__c;
        retrieveIntermediateStates = rec.RetrieveIntermediateStates__c;
        batchSize = rec.BatchSize__c == null ? DeployConstants.MAX_BATCH_SIZE : Integer.valueOf(rec.BatchSize__c);
        namedCredential = rec.NamedCredential__c;
        sessionId = rec.SessionId__c;
    }
}