/**
 * @description Repository class to handle access to deployment configuration stored in a Custom Setting,
 * including retrieval, validation, updates, and cron job management.
 * @author develop@mpdigitals.com
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeploySetupRepository {

    /**
     * @description Retrieves the raw Custom Setting configuration record.
     * @return DeploySetup__c record.
     */
    public static DeploySetup__c getRawConfig() {
        DeployAccessValidator.enforceAccess();
        return DeploySetup__c.getOrgDefaults();
    }

    /**
     * @description Retrieves the deployment configuration as a wrapper DTO.
     * @return DeploySetupWrapper object representing configuration.
     */
    public static DeploySetupWrapper getConfigWrapper() {
        return new DeploySetupWrapper(getRawConfig());
    }

    /**
     * @description Returns all Named Credential DeveloperNames without namespace.
     * @return List of Named Credential developer names.
     */
    public static List<String> getNamedCredentials() {
        DeployAccessValidator.enforceAccess();
        List<String> creds = new List<String>();
        for (NamedCredential nc : [
            SELECT DeveloperName
            FROM NamedCredential
            WHERE NamespacePrefix = null
        ]) {
            creds.add(nc.DeveloperName);
        }
        return creds;
    }

    /**
     * @description Returns currently active deployment cron jobs.
     * @return List of active CronTrigger records.
     */
    public static List<CronTrigger> getActiveDeployJobs() {
        DeployAccessValidator.enforceAccess();
        return [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE : (DeployConstants.JOB_NAME + ' - %')
            AND State = 'WAITING'
        ];
    }

    /**
     * @description Updates schedule configuration fields in Custom Setting using the provided wrapper.
     * @param config DeploySetupWrapper object containing the schedule configuration data.
     */
    public static void updateScheduleSettings(DeploySetupWrapper config) {
        DeployAccessValidator.enforceAccess();

        DeployValidator.validateScheduleInput(config);

        Datetime startDt = config.startTime;
        Decimal freqVal = Decimal.valueOf(config.frequencyValue);

        DeploySetup__c cfg = DeploySetup__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new DeploySetup__c();
        }

        cfg.StartTime__c = startDt;
        cfg.FrequencyUnit__c = config.frequencyUnit;
        cfg.FrequencyValue__c = freqVal;
        cfg.IsEnabled__c = config.isEnabled;

        upsert cfg;
    }

    /**
     * @description Updates advanced deployment settings using the provided DeploySetupWrapper.
     * @param config DeploySetupWrapper containing advanced settings.
     */
    public static void updateAdvancedSettings(DeploySetupWrapper config) {
        DeployAccessValidator.enforceAccess();
        DeployValidator.validateNamedCredential(config.namedCredential);

        if (config.batchSize == null
            || config.batchSize < DeployConstants.MIN_BATCH_SIZE
            || config.batchSize > DeployConstants.MAX_BATCH_SIZE) {
            throw new AuraHandledException(String.format(
                DeployConstants.ERR_BATCH_RANGE,
                new List<String>{
                    String.valueOf(DeployConstants.MIN_BATCH_SIZE),
                    String.valueOf(DeployConstants.MAX_BATCH_SIZE)
                }
            ));
        }

        DeploySetup__c cfg = DeploySetup__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new DeploySetup__c();
        }

        cfg.RetrieveIntermediateStates__c = config.retrieveIntermediateStates;
        cfg.RetrieveComponents__c = config.retrieveComponents;
        cfg.RetrieveTests__c = config.retrieveTests;
        cfg.BatchSize__c = config.batchSize;
        cfg.NamedCredential__c = config.namedCredential;

        upsert cfg;
    }

    /**
     * @description Updates schedule configuration and reprograms the cron job if enabled using the provided wrapper.
     * @param config DeploySetupWrapper object containing the schedule configuration data.
     */
    public static void enqueueScheduleUpdate(DeploySetupWrapper config) {
        DeployAccessValidator.enforceAccess();
        updateScheduleSettings(config);
        rescheduleJobIfEnabled();
    }

    /**
     * @description Reschedules the cron job based on the current configuration in Custom Setting.
     */
    public static void rescheduleJobIfEnabled() {
        DeployAccessValidator.enforceAccess();
        for (CronTrigger ct : getActiveDeployJobs()) {
            System.abortJob(ct.Id);
        }

        DeploySetup__c cfg = getRawConfig();
        if (cfg != null && cfg.IsEnabled__c && cfg.StartTime__c != null) {
            String cron = DeployUtils.buildCron(cfg.StartTime__c);
            String jobName = DeployConstants.JOB_NAME + ' - ' + cfg.StartTime__c.format('yyyy-MM-dd HH:mm');
            System.schedule(jobName, cron, new DeployScheduleService());
        }
    }
}