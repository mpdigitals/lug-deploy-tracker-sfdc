/**
 * @description Maps test result details from a DeployRequest to DeployResultTest__c records.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployResultTestMapper {

    /**
     * @description Maps successful and failed test results from the DeployRequest to custom records.
     * @param deploy The DeployRequest wrapper containing deploy result details.
     * @param parentId The Id of the associated DeployResult__c record.
     * @return List<DeployResultTest__c> of mapped test records.
     */
    public static List<DeployResultTest__c> mapResultTests(
        DeployApiWrapper.DeployRequest deploy,
        Id parentId
    ) {
        List<DeployResultTest__c> results = new List<DeployResultTest__c>();
        if (deploy == null
            || deploy.deployResult == null
            || deploy.deployResult.details == null
            || deploy.deployResult.details.runTestResult == null) {
            return results;
        }
        DeployApiWrapper.RunTestResult testResults = deploy.deployResult.details.runTestResult;

        if (testResults.successes != null) {
            for (DeployApiWrapper.TestSuccess s : testResults.successes) {
                String rawId = deploy.deployResult.id + s.Id + s.name + s.methodName;
                DeployResultTest__c record = new DeployResultTest__c();
                record.ExtId__c = DeployCoreUtils.generateMd5Short(rawId);
                record.Id__c = s.Id;
                record.DeployResult__c = parentId;
                record.Name__c = s.name;
                record.MethodName__c = s.methodName;
                record.Time__c = s.timeValue;
                record.Success__c = true;
                results.add(record);
            }
        }
        if (testResults.failures != null) {
            for (DeployApiWrapper.TestFailure f : testResults.failures) {
                String rawId = deploy.deployResult.id + f.Id + f.name + f.methodName + f.message + f.stackTrace;
                DeployResultTest__c record = new DeployResultTest__c();
                record.ExtId__c = DeployCoreUtils.generateMd5Short(rawId);
                record.Id__c = f.Id;
                record.DeployResult__c = parentId;
                record.Name__c = f.name;
                record.MethodName__c = f.methodName;
                record.Time__c = f.timeValue;
                record.Success__c = false;
                record.Message__c = f.message;
                record.StackTrace__c = f.stackTrace;
                results.add(record);
            }
        }
        return results;
    }
}