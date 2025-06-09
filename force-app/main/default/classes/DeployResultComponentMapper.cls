/**
 * @description Maps Tooling API deploy component messages to custom metadata components.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployResultComponentMapper {

    /**
     * @description Maps component messages from a deployment response to custom records.
     * @param deploy The DeployRequest wrapper containing deploy result details.
     * @param parentId The Id of the parent DeployResult__c record.
     * @return A list of DeployResultComponent__c records.
     */
    public static List<DeployResultComponent__c> mapComponents(
        DeployApiWrapper.DeployRequest deploy,
        Id parentId
    ) {
        List<DeployResultComponent__c> results = new List<DeployResultComponent__c>();
        if (
            deploy == null ||
            deploy.deployResult == null ||
            deploy.deployResult.details == null ||
            deploy.deployResult.details.allComponentMessages == null
        ) {
            return results;
        }
        for (DeployApiWrapper.Component comp : deploy.deployResult.details.allComponentMessages) {
            if (comp.forPackageManifestFile) {
                continue;
            }
            DeployResultComponent__c record = new DeployResultComponent__c();
            String uniqueId = deploy.deployResult.id + comp.fullName + comp.lineNumber + comp.columnNumber + comp.problem;
            record.ExtId__c = DeployCoreUtils.generateMd5Short(uniqueId);
            record.Id__c = comp.id;
            record.DeployResult__c = parentId;
            record.ComponentType__c = comp.componentType;
            record.FileName__c = comp.fileName;
            record.FullName__c = comp.fullName;
            record.Problem__c = comp.problem;
            record.Success__c = comp.success;
            record.Changed__c = comp.changed;
            record.Deleted__c = comp.deleted;
            record.Warning__c = comp.warning;
            record.LineNumber__c = comp.lineNumber;
            record.ColumnNumber__c = comp.columnNumber;
            record.RequiresProductionTestRun__c = comp.requiresProductionTestRun;
            record.Created__c = comp.created;
            record.ProblemType__c = comp.problemType;
            record.KnownPackagingProblem__c = comp.knownPackagingProblem;
            record.ForPackageManifestFile__c = comp.forPackageManifestFile;
            results.add(record);
        }
        return results;
    }
}