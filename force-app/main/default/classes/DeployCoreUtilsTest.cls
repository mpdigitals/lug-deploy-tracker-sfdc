@IsTest
private class DeployCoreUtilsTest {

    static String iso() {
        return System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    @TestSetup
    static void setup() {
        DeploySetup__c cfg = new DeploySetup__c();
        cfg.StartTime__c = System.now().addMinutes(1);
        cfg.IsEnabled__c = false;
        cfg.FrequencyUnit__c = 'days';
        cfg.FrequencyValue__c = 1;
        cfg.NamedCredential__c = 'DummyNC';
        cfg.RetrieveComponents__c = true;
        cfg.RetrieveTests__c = true;
        cfg.RetrieveIntermediateStates__c = false;
        cfg.BatchSize__c = 10;
        insert cfg;
    }

    @IsTest
    static void testGetConfig() {
        DeployAccessValidator.testAccess = true;
        DeploySetupWrapper config = DeployCoreUtils.getDeployConfig();
        Assert.isNotNull(config, 'getDeployConfig should return a valid config');
    }

    @IsTest
    static void testCreds() {
        DeployAccessValidator.testAccess = true;
        List<String> creds = DeployCoreUtils.getNamedCredentials();
        Assert.isNotNull(creds, 'getNamedCredentials should return a list');
    }

    @IsTest
    static void testBatchSize() {
        DeployAccessValidator.testAccess = true;
        Integer v = DeployCoreUtils.getBatchSize();
        Assert.isTrue(v >= DeployConstants.MIN_BATCH_SIZE, 'Batch size should be >= MIN_BATCH_SIZE');
    }

    @IsTest
    static void testUpdateConfigAsync() {
        DeployAccessValidator.testAccess = true;
        DeploySetupWrapper wrapper = new DeploySetupWrapper();
        wrapper.startTime = System.now().addMinutes(2);
        wrapper.isEnabled = true;
        wrapper.frequencyUnit = 'days';
        wrapper.frequencyValue = '1';

        Test.startTest();
        DeployCoreUtils.updateDeployConfig(wrapper);
        Test.stopTest();

        DeploySetup__c cfg = DeploySetup__c.getOrgDefaults();
        Assert.isTrue(cfg.IsEnabled__c, 'IsEnabled should be true');
        Assert.areEqual('days', cfg.FrequencyUnit__c, 'FrequencyUnit should be days');
        Assert.areEqual(1, cfg.FrequencyValue__c, 'FrequencyValue should be 1');
    }

    @IsTest
    static void testUpdateAdvancedAsync() {
        DeployAccessValidator.testAccess = true;
        DeploySetupWrapper wrapper = new DeploySetupWrapper();
        wrapper.retrieveIntermediateStates = true;
        wrapper.retrieveComponents = true;
        wrapper.retrieveTests = true;
        wrapper.batchSize = 10;
        wrapper.namedCredential = 'DummyNC';

        Test.startTest();
        DeployCoreUtils.updateAdvancedSettings(wrapper);
        Test.stopTest();

        DeploySetup__c cfg = DeploySetup__c.getOrgDefaults();
        Assert.areEqual(10, cfg.BatchSize__c, 'Batch size should be updated');
        Assert.isTrue(cfg.RetrieveComponents__c, 'RetrieveComponents should be true');
        Assert.isTrue(cfg.RetrieveTests__c, 'RetrieveTests should be true');
        Assert.isTrue(cfg.NamedCredential__c == 'DummyNC', 'NamedCredential should be DummyNC');
    }

    @IsTest
    static void testHelpers() {
        DeploySetup__c dummy = new DeploySetup__c(
            FrequencyUnit__c = 'days',
            FrequencyValue__c = 1
        );
        Datetime d = DeployCoreUtils.calculateFromTime(dummy, System.now());
        Assert.isNotNull(d, 'calculateFromTime should return a datetime');

        String cron = DeployCoreUtils.buildCron(System.now());
        Assert.isTrue(cron.length() > 0, 'buildCron should return a non-empty string');

        String h = DeployCoreUtils.generateMd5Short('abc');
        Assert.areEqual(18, h.length(), 'MD5 short hash should be 18 characters long');

        String p = DeployCoreUtils.patchJsonKeys('{"a":"b"}', new Map<String, String>{'a' => 'z'});
        Assert.isTrue(p.contains('z'), 'patchJsonKeys should replace keys correctly');
    }

    @IsTest
    static void testSyncDates() {
        DeployAccessValidator.testAccess = true;
        Datetime n = DeployCoreUtils.getNextRun();
        Assert.isTrue(n == null || n >= System.now(), 'Next run should be null or a future datetime');
    }
}