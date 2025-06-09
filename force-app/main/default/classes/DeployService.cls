/**
 * @description Public service class to manually trigger deployment synchronization
 * over a configurable date range.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployService {

    /**
     * @description Triggers a batch job to fetch deployment data between dates.
     * - If only startDate is provided, syncs up to now.
     * - If both are null, syncs from 2000-01-01 to now.
     * - Uses batch size from custom metadata.
     * @param startDate The start of the date range.
     * @param endDate The optional end of the date range.
     */
    @AuraEnabled
    public static void syncDeployments(DateTime startDate, DateTime endDate) {
        // Validate access early to avoid launching batch if unauthorized
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
        Database.executeBatch(new DeployRequestBatch(fromDateTime, toDateTime), batchSize);
    }

    /**
     * @description Checks if a DeployRequestBatch job is currently running or queued.
     * @return True if a sync is already in progress; false otherwise.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Boolean isSyncInProgress() {
        List<AsyncApexJob> jobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'DeployRequestBatch'
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        return !jobs.isEmpty();
    }
}