@IsTest
private class DeployAccessValidatorTest {

    @IsTest
    static void testAccessTrue() {
        DeployAccessValidator.testAccess = true;
        DeployAccessValidator.testForceException = false;
        Boolean result = DeployAccessValidator.hasAccess();
        Assert.areEqual(true, result, 'Expected access to be granted when testAccess is true');
    }

    @IsTest
    static void testAccessFalse() {
        DeployAccessValidator.testAccess = false;
        DeployAccessValidator.testForceException = false;
        Boolean result = DeployAccessValidator.hasAccess();
        Assert.areEqual(false, result, 'Expected access to be denied when testAccess is false');
    }

    @IsTest
    static void testForceExceptionInTest() {
        DeployAccessValidator.testAccess = false;
        DeployAccessValidator.testForceException = true;
        Boolean result = DeployAccessValidator.hasAccess();
        Assert.areEqual(false, result, 'Expected access to be denied when forcing exception');
    }

    @IsTest
    static void testEnforceAccessOk() {
        DeployAccessValidator.testAccess = true;
        DeployAccessValidator.testForceException = false;

        Boolean exceptionThrown = false;
        try {
            DeployAccessValidator.enforceAccess();
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Assert.areEqual(false, exceptionThrown, 'Expected no exception when access is granted');
    }

    @IsTest
    static void testEnforceAccessFails() {
        DeployAccessValidator.testAccess = false;
        DeployAccessValidator.testForceException = false;

        Boolean exceptionThrown = false;
        String exceptionMessage = '';

        try {
            DeployAccessValidator.enforceAccess();
        } catch (SecurityException e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }

        Assert.areEqual(true, exceptionThrown, 'Expected SecurityException to be thrown');
        Assert.areEqual('You do not have permission to access this feature.', exceptionMessage, 'Expected correct error message');
    }
}