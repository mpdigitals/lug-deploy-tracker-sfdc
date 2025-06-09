/**
 * @description Maps a DeployRequest Tooling API response to a DeployResult__c record.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployResultMapper {

    /**
     * @description Maps fields from a DeployRequest query result to a DeployResult__c record.
     * @param deploy Map<String, Object> representing a DeployRequest record.
     * @return DeployResult__c instance or null if input is invalid.
     */
    public static DeployResult__c mapResult(Map<String, Object> deploy) {
        if (deploy == null || !deploy.containsKey('Id')) {
            return null;
        }

        DeployResult__c record = new DeployResult__c();
        record.Id__c = (String) deploy.get('Id');
        record.CreatedDate__c = parseDate(deploy.get('CreatedDate'));
        record.CreatedBy__c = (String) deploy.get('CreatedById');
        record.CreatedByName__c = extractName(deploy, 'CreatedBy');
        record.NumberComponentsDeployed__c = parseInt(deploy.get('NumberComponentsDeployed'));
        record.NumberComponentErrors__c = parseInt(deploy.get('NumberComponentErrors'));
        record.NumberComponentsTotal__c = parseInt(deploy.get('NumberComponentsTotal'));
        record.NumberTestsCompleted__c = parseInt(deploy.get('NumberTestsCompleted'));
        record.NumberTestErrors__c = parseInt(deploy.get('NumberTestErrors'));
        record.NumberTestsTotal__c = parseInt(deploy.get('NumberTestsTotal'));
        record.CheckOnly__c = (Boolean) deploy.get('CheckOnly');
        record.IgnoreWarnings__c = (Boolean) deploy.get('IgnoreWarnings');
        record.RollbackOnError__c = (Boolean) deploy.get('RollbackOnError');
        record.Type__c = (String) deploy.get('Type');
        record.StartDate__c = parseDate(deploy.get('StartDate'));
        record.CompletedDate__c = parseDate(deploy.get('CompletedDate'));
        record.CanceledBy__c = (String) deploy.get('CanceledById');
        record.CanceledByName__c = extractName(deploy, 'CanceledBy');
        record.RunTestsEnabled__c = (Boolean) deploy.get('RunTestsEnabled');
        record.ChangeSetName__c = (String) deploy.get('ChangeSetName');
        record.ErrorStatusCode__c = (String) deploy.get('ErrorStatusCode');
        record.Status__c = (String) deploy.get('Status');
        record.StateDetail__c = (String) deploy.get('StateDetail');
        record.ErrorMessage__c = (String) deploy.get('ErrorMessage');
        record.AllowMissingFiles__c = (Boolean) deploy.get('AllowMissingFiles');
        record.AutoUpdatePackage__c = (Boolean) deploy.get('AutoUpdatePackage');
        record.PurgeOnDelete__c = (Boolean) deploy.get('PurgeOnDelete');
        record.SinglePackage__c = (Boolean) deploy.get('SinglePackage');
        record.TestLevel__c = (String) deploy.get('TestLevel');
        return record;
    }

    /**
     * @description Appends CodeCoverageWarnings to ErrorMessage__c of DeployResult__c if present.
     * @param record DeployResult__c record to update.
     * @param deploy DeployApiWrapper.DeployRequest containing detailed results.
     */
    public static void appendCoverageWarnings(DeployResult__c record, DeployApiWrapper.DeployRequest deploy) {
        if (record == null || deploy == null || deploy.deployResult == null || 
            deploy.deployResult.details == null || 
            deploy.deployResult.details.runTestResult == null || 
            deploy.deployResult.details.runTestResult.codeCoverageWarnings == null || 
            deploy.deployResult.details.runTestResult.codeCoverageWarnings.isEmpty()) {
            return;
        }

        List<String> warnings = new List<String>();
        Integer warningCount = 0;
        for (DeployApiWrapper.CodeCoverageWarning warning : deploy.deployResult.details.runTestResult.codeCoverageWarnings) {
            if (warning != null && !String.isBlank(warning.id)) {
                warnings.add(warning.name + ': ' + warning.message);
                warningCount++;
            }
        }

        if (!warnings.isEmpty()) {
            String coverageWarnings = String.join(warnings, '\n');
            record.ErrorStatusCode__c = DeployConstants.ERR_TEST_COVERAGE;
            if (String.isBlank(record.ErrorMessage__c)) {
                record.ErrorMessage__c = coverageWarnings;
            } else {
                record.ErrorMessage__c += '\n' + coverageWarnings;
            }
            record.NumberComponentErrors__c = warningCount;
        }
    }

    /**
     * @description Parses an Object into a Datetime, stripping milliseconds and timezone.
     * @param raw Raw date value.
     * @return Datetime or null.
     */
    private static Datetime parseDate(Object raw) {
        if (raw == null) {
            return null;
        }
        String s = String.valueOf(raw);
        if (s.contains('.')) {
            s = s.substringBefore('.');
        } else if (s.endsWith('Z')) {
            s = s.replace('Z', '');
        }
        s = s.replace('T', ' ');
        try {
            return Datetime.valueOfGmt(s);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to parse date: ' + s);
            return null;
        }
    }

    /**
     * @description Converts an Object into Integer.
     * @param raw Raw numeric value.
     * @return Integer or null.
     */
    private static Integer parseInt(Object raw) {
        return raw != null ? Integer.valueOf(String.valueOf(raw)) : null;
    }

    /**
     * @description Extracts the 'Name' field from a nested map entry.
     * @param parent Map containing sub-map.
     * @param key Key of the sub-map.
     * @return Name string or null.
     */
    private static String extractName(Map<String, Object> parent, String key) {
        Map<String, Object> sub = (Map<String, Object>) parent.get(key);
        return sub != null ? (String) sub.get('Name') : null;
    }
}