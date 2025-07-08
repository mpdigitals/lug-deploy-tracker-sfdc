@IsTest
private class DeployApiWrapperTest {

    @IsTest
    static void testGetDeployResults() {
        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());

        DeployApiWrapper wrapper = new DeployApiWrapper('Test_NC', false);

        List<Id> ids = new List<Id>{'0A1xx000000Xyz1AAA', '0A1xx000000Xyz2BBB'};
        List<DeployApiWrapper.DeployRequest> results = wrapper.getDeployResults(ids);

        Assert.isNotNull(results, 'Results list should not be null');
        Assert.isTrue(results.size() > 0, 'Expected at least one DeployRequest returned');

        DeployApiWrapper.DeployRequest first = results[0];
        Assert.isNotNull(first, 'First DeployRequest should not be null');
        Assert.isNotNull(first.deployResult, 'DeployResult should not be null');

        DeployApiWrapper.DeployResult dr = first.deployResult;
        Assert.isNotNull(dr.details, 'Details should not be null');
        Assert.isNotNull(dr.details.allComponentMessages, 'Components list should not be null');
        Assert.isTrue(dr.details.allComponentMessages.size() > 0, 'Components list should not be empty');

        Assert.isNotNull(dr.details.runTestResult, 'RunTestResult should not be null');
        Assert.isNotNull(dr.details.runTestResult.successes, 'Successes list should not be null');
        Assert.isNotNull(dr.details.runTestResult.failures, 'Failures list should not be null');

        Assert.isTrue(dr.details.runTestResult.successes.size() > 0, 'Should have test successes');
        Assert.isTrue(dr.details.runTestResult.failures.size() > 0, 'Should have test failures');
    }

    @IsTest
    static void testConstructorFailsOnBlankName() {
        Boolean thrown = false;
        try {
            new DeployApiWrapper('', false);
        } catch (Exception e) {
            thrown = true;
        }
        Assert.isTrue(thrown, 'Expected exception for blank namedCredential');
    }

    @IsTest
    static void testGetResultsEmptyInput() {
        DeployApiWrapper wrapper = new DeployApiWrapper('Test_NC', false);

        List<DeployApiWrapper.DeployRequest> resultsNull = wrapper.getDeployResults(null);
        Assert.isNotNull(resultsNull, 'Should not return null for null input');
        Assert.areEqual(0, resultsNull.size(), 'Should return empty list for null input');

        List<DeployApiWrapper.DeployRequest> resultsEmpty = wrapper.getDeployResults(new List<Id>());
        Assert.isNotNull(resultsEmpty, 'Should not return null for empty list input');
        Assert.areEqual(0, resultsEmpty.size(), 'Should return empty list for empty input');
    }
}