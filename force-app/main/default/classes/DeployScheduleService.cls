/**
 * @description Schedulable that triggers the DeployRequestBatch at the configured interval
 * and reschedules itself based on the configuration in DeploySetup__c.
 * Author: develop@mpdigitals.com
 */
public with sharing class DeployScheduleService implements Schedulable {

    /**
     * @description Entry point of the scheduled job. Executes the deployment sync batch
     * and reschedules the next run based on current configuration.
     * @param sc The SchedulableContext passed by the system.
     */
    public void execute(SchedulableContext sc) {
        DeployAccessValidator.enforceAccess();
        DeploySetupWrapper cfg = DeploySetupRepository.getConfigWrapper();

        if (cfg == null || !cfg.isEnabled || cfg.startTime == null) {
            return;
        }

        Datetime toTime = cfg.startTime;
        Datetime fromTime = DeployUtils.calculateFromTime(DeploySetupRepository.getRawConfig(), toTime);

        Integer batchSize = cfg.batchSize != null ? cfg.batchSize : DeployCoreUtils.getBatchSize();

        Database.executeBatch(
            new DeployRequestBatch(fromTime, toTime, cfg, false),
            batchSize
        );

        scheduleNextRun(cfg);
    }

    /**
     * @description Calculates next execution time based on frequency, updates StartTime__c,
     * and schedules a new job with dynamic name including start time.
     * @param cfg The current DeploySetupWrapper object with frequency data.
     */
    public static void scheduleNextRun(DeploySetupWrapper cfg) {
        Datetime nextStart = cfg.startTime;
        Integer amount = String.isNotBlank(cfg.frequencyValue)
            ? Integer.valueOf(cfg.frequencyValue)
            : 1;
        String unit = String.isNotBlank(cfg.frequencyUnit)
            ? cfg.frequencyUnit.toLowerCase()
            : '';

        if (unit == 'days') {
            nextStart = nextStart.addDays(amount);
        } else if (unit == 'months') {
            nextStart = nextStart.addMonths(amount);
        } else if (unit == 'hours') {
            nextStart = nextStart.addHours(amount);
        } else {
            nextStart = nextStart.addHours(1);
        }

        String cronExpr = DeployUtils.buildCron(nextStart);
        String jobName = DeployConstants.JOB_NAME + ' - ' + nextStart.format('yyyy-MM-dd HH:mm');

        System.schedule(jobName, cronExpr, new DeployScheduleService());

        if (Schema.sObjectType.DeploySetup__c.isUpdateable()) {
            DeploySetup__c setup = DeploySetup__c.getOrgDefaults();
            setup.StartTime__c = nextStart;
            update setup;
        }
    }
}