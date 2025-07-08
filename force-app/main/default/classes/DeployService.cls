/**
 * @description Public service class to manually trigger deployment synchronization
 * over a configurable date range.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployService {

    /**
     * @description Triggers a batch job to fetch deployment data between dates.
     * @param startDate The start of the date range.
     * @param endDate The optional end of the date range.
     * @param enableStreaming Whether to emit Platform Events for progress tracking.
     * @return The Id of the AsyncApexJob started.
     */
    @AuraEnabled
    public static Id syncDeployments(DateTime startDate, DateTime endDate, Boolean enableStreaming) {
        DeployAccessValidator.enforceAccess();

        String startIso = startDate != null ? startDate.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : null;
        String endIso = endDate != null ? endDate.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : null;

        DeployValidator.validateSyncDates(startIso, endIso);
        DeployValidator.assertNoSyncInProgress();

        DateTime fromDateTime;
        DateTime toDateTime;

        if (startDate != null && endDate == null) {
            fromDateTime = DateTime.newInstance(startDate.date(), Time.newInstance(0, 0, 0, 0));
            toDateTime = System.now();
        } else if (startDate != null && endDate != null) {
            fromDateTime = DateTime.newInstance(startDate.date(), Time.newInstance(0, 0, 0, 0));
            toDateTime = DateTime.newInstance(endDate.date(), Time.newInstance(23, 59, 59, 999));
        } else {
            fromDateTime = DateTime.newInstance(2000, 1, 1, 0, 0, 0);
            toDateTime = System.now();
        }

        Integer batchSize = DeployCoreUtils.getBatchSize();
        DeployRequestBatch batch = new DeployRequestBatch(fromDateTime, toDateTime, enableStreaming);
        return Database.executeBatch(batch, batchSize);
    }
}