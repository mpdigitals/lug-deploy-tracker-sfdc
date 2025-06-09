/**
 * @description Handles validation logic for deployment configuration, including frequency input and batch size.
 * @author develop@mpdigitals.com
 */
@SuppressWarnings('PMD.CognitiveComplexity, PMD.ApexCRUDViolation')
public with sharing class DeployValidator {

    public static Boolean validateNCInTest = false;

    /**
     * @description Validates sync date range parameters.
     * @param startIso Start date as ISO string.
     * @param endIso End date as ISO string.
     */
    public static void validateSyncDates(String startIso, String endIso) {
        Datetime now = System.now();

        if (startIso != null) {
            Datetime startDt = DeployUtils.parseIso(startIso);
            if (startDt > now) {
                throw new AuraHandledException(DeployConstants.ERR_START_AFTER_TODAY);
            }
            Date minStart = now.addDays(-DeployConstants.MAX_RANGE_DAYS).date();
            if (startDt < minStart) {
                throw new AuraHandledException(minStart.format());
            }
        }

        if (endIso != null) {
            Datetime endDt = DeployUtils.parseIso(endIso);
            if (endDt > now) {
                throw new AuraHandledException(DeployConstants.ERR_END_AFTER_TODAY);
            }
        }

        if (startIso != null && endIso != null) {
            Datetime startDt = DeployUtils.parseIso(startIso);
            Datetime endDt = DeployUtils.parseIso(endIso);
            if (endDt < startDt) {
                throw new AuraHandledException(DeployConstants.ERR_END_BEFORE_START);
            }
        }

        if (startIso == null && endIso != null) {
            Datetime endDt = DeployUtils.parseIso(endIso);
            Datetime maxEnd = now.addDays(DeployConstants.MAX_RANGE_DAYS);
            if (endDt > maxEnd) {
                throw new AuraHandledException(String.format(
                    DeployConstants.ERR_END_TOO_FAR,
                    new List<String>{ String.valueOf(DeployConstants.MAX_RANGE_DAYS) }
                ));
            }
        }
    }

    /**
     * @description Validates the deployment schedule input parameters using DeploySetupWrapper.
     * @param config DeploySetupWrapper containing schedule configuration.
     */
    public static void validateScheduleInput(DeploySetupWrapper config) {
        assertNotBlank(
            config.startTime == null ? null : String.valueOf(config.startTime),
            DeployConstants.ERR_START_REQUIRED
        );
        assertNotBlank(config.frequencyUnit, DeployConstants.ERR_UNIT_REQUIRED);
        assertNotBlank(config.frequencyValue, DeployConstants.ERR_VAL_REQUIRED);

        DeploySetup__c cfg = DeploySetupRepository.getRawConfig();
        if (cfg != null) {
            validateNamedCredential(cfg.NamedCredential__c);
        }

        if (!config.isEnabled && DeploySetupRepository.getActiveDeployJobs().isEmpty()) {
            throw new AuraHandledException(DeployConstants.ERR_JOB_NONE);
        }

        Datetime startDt = config.startTime;
        if (startDt < System.now() && config.isEnabled) {
            throw new AuraHandledException(DeployConstants.ERR_START_PAST);
        }

        Integer val = Integer.valueOf(config.frequencyValue);

        if (val == null || val <= 0) {
            throw new AuraHandledException(DeployConstants.ERR_VAL_POSITIVE);
        }

        validateFrequency(config.frequencyUnit, val);
    }

    /**
     * @description Validates advanced settings (batch size and named credential).
     * @param batchSize Batch size.
     * @param namedCredential Named credential developer name.
     */
    public static void validateAdvancedSettings(Integer batchSize, String namedCredential) {
        validateNamedCredential(namedCredential);

        if (
            batchSize == null ||
            batchSize < DeployConstants.MIN_BATCH_SIZE ||
            batchSize > DeployConstants.MAX_BATCH_SIZE
        ) {
            throw new AuraHandledException(String.format(
                DeployConstants.ERR_BATCH_RANGE,
                new List<String>{
                    String.valueOf(DeployConstants.MIN_BATCH_SIZE),
                    String.valueOf(DeployConstants.MAX_BATCH_SIZE)
                }
            ));
        }
    }

    /**
     * @description Returns current batch size from config.
     * @return Integer batch size.
     */
    public static Integer getBatchSize() {
        DeploySetup__c cfg = DeploySetupRepository.getRawConfig();
        if (cfg == null || cfg.BatchSize__c == null) {
            return DeployConstants.MAX_BATCH_SIZE;
        }
        return Integer.valueOf(cfg.BatchSize__c);
    }

    /**
     * @description Asserts no DeployRequestBatch is currently running.
     */
    public static void assertNoSyncInProgress() {
        List<AsyncApexJob> jobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'DeployRequestBatch'
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        if (!jobs.isEmpty()) {
            throw new AuraHandledException(DeployConstants.ERR_SYNC_IN_PROGRESS);
        }
    }

    /**
     * @description Validates existence of NamedCredential.
     * @param nc Named credential developer name.
     */
    public static void validateNamedCredential(String nc) {
        if (Test.isRunningTest() && !validateNCInTest) {
            return;
        }

        if (String.isBlank(nc)) {
            throw new AuraHandledException(DeployConstants.ERR_NC_BLANK);
        }

        Integer count = [
            SELECT COUNT()
            FROM NamedCredential
            WHERE DeveloperName = :nc AND NamespacePrefix = null
        ];

        if (count == 0) {
            throw new AuraHandledException(String.format(
                DeployConstants.ERR_NC_MISSING,
                new List<String>{ nc }
            ));
        }
    }

    /**
     * @description Asserts that NamedCredential is not blank.
     * @param namedCredential Named credential developer name.
     */
    public static void assertNamedCredential(String namedCredential) {
        if (String.isBlank(namedCredential)) {
            throw new IllegalArgumentException(DeployConstants.ERR_NAMED_CREDENTIAL_BLANK);
        }
    }

    private static void assertNotBlank(String val, String message) {
        if (String.isBlank(val)) {
            throw new AuraHandledException(message);
        }
    }

    private static void validateFrequency(String unit, Integer val) {
        String u = unit != null ? unit.toLowerCase() : '';
        if (!DeployConstants.LIMITS.containsKey(u)) {
            throw new AuraHandledException(String.format(
                DeployConstants.ERR_UNIT_INVALID,
                new List<String>{ unit }
            ));
        }

        Integer max = DeployConstants.LIMITS.get(u);
        if (val > max) {
            throw new AuraHandledException(String.format(
                DeployConstants.ERR_VAL_RANGE,
                new List<String>{ unit, String.valueOf(max) }
            ));
        }
    }
}