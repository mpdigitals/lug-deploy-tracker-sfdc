/**
 * @description Provides access control logic for deployment features based on Custom Permission.
 * Supports testability with forced test flags.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployAccessValidator {

    public static Boolean testAccess = false;
    public static Boolean testForceException = false;

    /**
     * @description Checks whether the current user has access to the Deploy App feature.
     * In test context, respects testAccess and testForceException flags to enable full coverage.
     * In production, checks the DeployAdminAccess custom permission.
     * @return True if access is granted; False if denied or if an exception occurs.
     */
    @AuraEnabled
    public static Boolean hasAccess() {
        try {
            if (Test.isRunningTest() && testForceException) {
                throw new AuraHandledException('Forced test exception');
            }

            if (Test.isRunningTest()) {
                return testAccess;
            }

            return FeatureManagement.checkPermission('DeployAdminAccess');
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * @description Enforces access control by throwing a SecurityException if access is not granted.
     * Used to protect service methods or repository methods requiring admin access.
     * @throws SecurityException if the current user does not have permission.
     */
    public static void enforceAccess() {
        if (!hasAccess()) {
            throw new SecurityException('You do not have permission to access this feature.');
        }
    }
}