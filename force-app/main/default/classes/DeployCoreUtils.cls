/**
 * @description Core utility class that exposes methods for deployment configuration handling.
 * Delegates logic to helper classes for validation, metadata access, and utility processing.
 * @author develop@mpdigitals.com
 */
public without sharing class DeployCoreUtils {

    /**
     * @description Checks if the current user has access to the Deploy App using Custom Permission.
     * @return True if the user has the DeployAppUserAccess permission, false otherwise.
     */
    @AuraEnabled
    public static Boolean hasDeployAppAccess() {
        DeployAccessValidator.enforceAccess();
        return true;
    }

    /**
     * @description Returns the deployment configuration record as a wrapper object for the frontend.
     * @return DeploySetupWrapper DTO with current setup configuration.
     */
    @AuraEnabled(cacheable = false)
    public static DeploySetupWrapper getDeployConfig() {
        return new DeploySetupWrapper(DeploySetupRepository.getRawConfig());
    }

    /**
     * @description Retrieves the next scheduled execution time for the deployment job.
     * @return Datetime of the next scheduled job or null if none exist.
     */
    @AuraEnabled(cacheable = false)
    public static Datetime getNextRun() {
        List<CronTrigger> jobs = DeploySetupRepository.getActiveDeployJobs();
        return jobs.isEmpty() ? null : jobs[0].NextFireTime;
    }

    /**
     * @description Returns all Named Credential DeveloperNames without namespace.
     * @return List of Named Credential developer names.
     */
    @AuraEnabled
    public static List<String> getNamedCredentials() {
        return DeploySetupRepository.getNamedCredentials();
    }

    /**
     * @description Updates the schedule configuration for deployment execution using a wrapper object.
     * @param config DeploySetupWrapper object with schedule-related fields filled in.
     */
    @AuraEnabled
    public static void updateDeployConfig(DeploySetupWrapper config) {
        DeploySetupRepository.enqueueScheduleUpdate(config);
    }

    /**
     * @description Updates advanced configuration settings using a wrapper object.
     * @param config DeploySetupWrapper object with advanced settings.
     */
    @AuraEnabled
    public static void updateAdvancedSettings(DeploySetupWrapper config) {
        DeploySetupRepository.updateAdvancedSettings(config);
    }

    /**
     * @description Returns the current batch size defined in the configuration.
     * @return Integer representing the batch size.
     */
    public static Integer getBatchSize() {
        return DeployValidator.getBatchSize();
    }

    /**
     * @description Calculates the starting time based on configuration and reference date.
     * @param cfg The configuration setting record.
     * @param ref The reference Datetime to calculate from.
     * @return Calculated Datetime for deployment.
     */
    public static Datetime calculateFromTime(DeploySetup__c cfg, Datetime ref) {
        return DeployUtils.calculateFromTime(cfg, ref);
    }

    /**
     * @description Builds a cron expression from a Datetime.
     * @param dt The datetime to convert into a cron expression.
     * @return Cron expression string.
     */
    public static String buildCron(Datetime dt) {
        return DeployUtils.buildCron(dt);
    }

    /**
     * @description Generates a short MD5 hash from input string.
     * @param input The input string to hash.
     * @return Short MD5 hash string.
     */
    public static String generateMd5Short(String input) {
        return DeployUtils.generateMd5Short(input);
    }

    /**
     * @description Applies key replacement mapping to a JSON string.
     * @param body The JSON string.
     * @param rep Map of key replacements.
     * @return Modified JSON string with replacements applied.
     */
    public static String patchJsonKeys(String body, Map<String, String> rep) {
        return DeployUtils.patchJsonKeys(body, rep);
    }
}