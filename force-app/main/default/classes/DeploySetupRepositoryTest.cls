@IsTest
private class DeploySetupRepositoryTest {

    static String isoShift(Integer min) {
        return System.now().addMinutes(min).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    @TestSetup
    static void baseSetup() {
        delete [SELECT Id FROM DeploySetup__c WHERE SetupOwnerId = :UserInfo.getOrganizationId()];
        DeploySetup__c cfg = new DeploySetup__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            StartTime__c = System.now(),
            IsEnabled__c = false,
            FrequencyUnit__c = 'hours',
            FrequencyValue__c = 1,
            NamedCredential__c = 'ToolingAPICredential'
        );
        insert cfg;

        System.schedule(
            'TestJob',
            '0 0 0 1 1 ? 2050',
            new DummySched()
        );
    }

    @SuppressWarnings('PMD.EmptyStatementBlock')
    private class DummySched implements Schedulable {
        public void execute(SchedulableContext sc) {}
    }

    private static DeploySetupWrapper createBaseWrapper() {
        DeploySetupWrapper wrapper = new DeploySetupWrapper();
        wrapper.startTime = System.now().addMinutes(5);
        wrapper.frequencyUnit = 'hours';
        wrapper.frequencyValue = '1';
        wrapper.isEnabled = true;
        wrapper.namedCredential = 'ToolingAPICredential';
        wrapper.retrieveIntermediateStates = true;
        wrapper.retrieveComponents = true;
        wrapper.retrieveTests = true;
        wrapper.batchSize = 10;
        return wrapper;
    }

    @IsTest
    static void testRawConfig() {
        DeployAccessValidator.testAccess = true;
        DeploySetup__c loaded = DeploySetupRepository.getRawConfig();
        Assert.isNotNull(loaded, 'Config should not be null');
        Assert.areEqual('hours', loaded.FrequencyUnit__c, 'Unit mismatch');
    }

    @IsTest
    static void testNamedCredentials() {
        DeployAccessValidator.testAccess = true;
        List<String> creds = DeploySetupRepository.getNamedCredentials();
        Assert.isNotNull(creds, 'Named credentials list should not be null');
    }

    @IsTest
    static void testActiveJobs() {
        DeployAccessValidator.testAccess = true;
        List<CronTrigger> jobs = DeploySetupRepository.getActiveDeployJobs();
        Assert.isNotNull(jobs, 'Jobs list should not be null');
    }

    @IsTest
    static void testInvalidScheduleUpdate() {
        DeployAccessValidator.testAccess = true;
        Boolean exceptionThrown = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.startTime = null;
            wrapper.frequencyUnit = 'minutes';
            wrapper.frequencyValue = '';
            wrapper.isEnabled = true;

            DeploySetupRepository.enqueueScheduleUpdate(wrapper);
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Expected exception for invalid input');
    }

    @IsTest
    static void testAdvancedSettingsValid() {
        DeployAccessValidator.testAccess = true;

        DeploySetupWrapper wrapper = createBaseWrapper();
        wrapper.retrieveTests = false;
        wrapper.batchSize = 10;

        DeploySetupRepository.updateAdvancedSettings(wrapper);

        DeploySetup__c result = DeploySetup__c.getOrgDefaults();

        Assert.isTrue(result.RetrieveComponents__c, 'RetrieveComponents__c should be true');
        Assert.isFalse(result.RetrieveTests__c, 'RetrieveTests__c should be false');
        Assert.isTrue(result.RetrieveIntermediateStates__c, 'RetrieveIntermediateStates__c should be true');
        Assert.areEqual(10, result.BatchSize__c, 'BatchSize should be 10');
    }

    @IsTest
    static void testInvalidBatchSize() {
        DeployAccessValidator.testAccess = true;
        Boolean threw = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.batchSize = 0;

            DeploySetupRepository.updateAdvancedSettings(wrapper);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Assert.isTrue(threw, 'Expected AuraHandledException for invalid batch size');
    }

    @IsTest
    static void testRescheduleEnabled() {
        DeployAccessValidator.testAccess = true;
        DeploySetup__c cfg = DeploySetup__c.getOrgDefaults();
        cfg.IsEnabled__c = true;
        cfg.StartTime__c = System.now().addMinutes(5);
        update cfg;

        Test.startTest();
        DeploySetupRepository.rescheduleJobIfEnabled();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = 'TestJob'
            AND State = 'WAITING'
        ];
        Assert.isTrue(jobs.size() > 0, 'Expected a scheduled job to be created');
    }

    @IsTest
    static void testRescheduleCreatesCron() {
        DeployAccessValidator.testAccess = true;
        DeploySetup__c cfg = DeploySetup__c.getOrgDefaults();
        cfg.IsEnabled__c = true;
        cfg.StartTime__c = System.now().addMinutes(10);
        cfg.FrequencyUnit__c = 'days';
        cfg.FrequencyValue__c = 1;
        update cfg;

        Test.startTest();
        DeploySetupRepository.rescheduleJobIfEnabled();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = 'TestJob'
            AND State = 'WAITING'
        ];
        Assert.isTrue(jobs.size() > 0, 'Expected job to be scheduled');
    }

    @IsTest
    static void testNoCronIfDisabled() {
        DeployAccessValidator.testAccess = true;
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = 'TestJob'
        ]) {
            System.abortJob(ct.Id);
        }

        DeploySetup__c cfg = DeploySetup__c.getOrgDefaults();
        cfg.IsEnabled__c = false;
        cfg.StartTime__c = System.now().addMinutes(10);
        update cfg;

        Test.startTest();
        DeploySetupRepository.rescheduleJobIfEnabled();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = 'TestJob'
            AND State = 'WAITING'
        ];
        Assert.isTrue(jobs.isEmpty(), 'No job should be scheduled when disabled');
    }

    @IsTest
    static void testInsertConfigWhenNoneExists() {
        DeployAccessValidator.testAccess = true;
        delete [SELECT Id FROM DeploySetup__c WHERE SetupOwnerId = :UserInfo.getOrganizationId()];

        DeploySetupWrapper wrapper = createBaseWrapper();
        wrapper.frequencyValue = '2';
        wrapper.frequencyUnit = 'hours';
        wrapper.isEnabled = true;

        Test.startTest();
        DeploySetupRepository.updateScheduleSettings(wrapper);
        Test.stopTest();

        DeploySetup__c result = DeploySetup__c.getOrgDefaults();
        Assert.isNotNull(result, 'Config should have been inserted');
        Assert.areEqual(2, result.FrequencyValue__c.intValue(), 'Frequency value mismatch');
    }
}