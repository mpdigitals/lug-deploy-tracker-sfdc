/**
 * @description Contains global constants used throughout the deployment scheduling system,
 * including configuration labels, field limits, error messages, and default values.
 * @author develop@mpdigitals.com
 */
public class DeployConstants {
    public static final String API_VERSION = 'v63.0';
    public static final String JOB_NAME = 'Deploy Schedule';

    public static final String CALLOUT_PREFIX = 'callout:';
    public static final String SERVICES_BASE_PATH = '/services/data/';
    public static final String TOOLING_QUERY_PATH = '/tooling/query/?q=';
    public static final String METADATA_DEPLOY_REQUEST_PATH = '/metadata/deployRequest/';
    public static final String METADATA_DEPLOY_REQUEST_SUFFIX = '?includeDetails=true';

    public static final Integer MIN_BATCH_SIZE = 1;
    public static final Integer MAX_BATCH_SIZE = 100;

    public static final Integer HOURS_MAX = 23;
    public static final Integer DAYS_MAX = 30;
    public static final Integer MONTHS_MAX = 12; //For a future Salesforce update to extend data retention

    public static final Integer MAX_PROGRESS_EVENTS = 10;

    public static final Datetime EPOCH = Datetime.newInstance(2000, 1, 1, 0, 0, 0);

    public static final Map<String, Integer> LIMITS = new Map<String, Integer>{
        'hours' => HOURS_MAX,
        'days' => DAYS_MAX,
        'months' => MONTHS_MAX
    };
    
    public static final String MSG_SYNC_PROGRESS = 'Sync progress';
    public static final String MSG_SYNC_COMPLETE = 'Sync complete';
    public static final String ERR_START_REQUIRED = 'Start Time is required.';
    public static final String ERR_START_AFTER_TODAY = 'Start date cannot be later than today.';
    public static final String ERR_END_AFTER_TODAY = 'End date cannot be later than today.';
    public static final String ERR_END_BEFORE_START = 'End date cannot be earlier than start date.';
    public static final String ERR_END_TOO_FAR = 'End date cannot be more than {0} days from today.';
    public static final String ERR_UNIT_REQUIRED = 'Frequency Unit is required.';
    public static final String ERR_VAL_REQUIRED = 'Frequency Value is required.';
    public static final String ERR_VAL_POSITIVE = 'Frequency Value must be greater than 0.';
    public static final String ERR_UNIT_INVALID = 'Invalid frequency unit: {0}.';
    public static final String ERR_VAL_RANGE = 'For {0}, the maximum allowed value is {1}.';
    public static final String ERR_START_PAST = 'Start Time must be in the future when schedule is enabled.';
    public static final String ERR_SYNC_IN_PROGRESS = 'A sync is already in progress. Please wait until it finishes.';
    public static final String ERR_NC_BLANK = 'Named Credential cannot be blank if sessionId is not used.';
    public static final String ERR_NC_MISSING = 'Named Credential "{0}" does not exist.';
    public static final String ERR_JOB_NONE = 'Cannot disable schedule because no scheduled job exists.';
    public static final String ERR_BATCH_RANGE = 'Batch size must be between {0} and {1}.';
    public static final String ERR_BATCH_ID_REQUIRED = 'No batch ID provided.';
    public static final String ERR_BATCH_NOT_FOUND = 'Batch job not found yet.';
    public static final String ERR_FETCHING_JOB_STATUS = 'Error fetching job status: ';
    public static final String ERR_TEST_COVERAGE = 'CodeCoverageWarnings';
}